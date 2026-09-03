-- CloudFront chargeback cost query — pricing via fact-table JOIN (not embedded CASE walls).
-- Region mapping + prices live in two version-able Glue tables the query JOINs against:
--   cf_edge_location_region(iata_prefix, region_key)  — edge IATA prefix -> region
--   cf_region_pricing(region_key, region_name, dto_price_per_gb, request_price_per_10k, tier)
-- Re-price/add an edge = edit pricing-data/ CSVs + `cdk deploy`, no SQL change. Unmapped edges
-- COALESCE to the 'default' row (same fallback prices/label as the old ELSE branch).
-- INVARIANT: every region_key (incl. 'default') MUST have a cf_region_pricing row — the final
-- JOIN is inner, so a missing price row silently drops those log records.
-- Behavior-preserving: still groups per edge IATA prefix; DTO and proxy-byte cost share the same
-- dto_price_per_gb (as the original did), so output shape and values are unchanged.

WITH priced_logs AS (
    SELECT
        l.cs_uri_stem,
        l.date,
        l.sc_bytes,
        l.cs_bytes,
        l.cs_method,
        l.x_edge_result_type,
        SUBSTRING(l.x_edge_location, 1, 3) AS iata_prefix,
        COALESCE(m.region_key, 'default') AS region_key
    FROM "chargeback_database"."cf-logs-table" l
    LEFT JOIN "chargeback_database"."cf_edge_location_region" m
        ON SUBSTRING(l.x_edge_location, 1, 3) = m.iata_prefix
),
record_count AS (
    SELECT
        pl.cs_uri_stem,
        -- region_name is constant per iata_prefix (prefix -> one region_key -> one name),
        -- so MAX() just carries the single label through the per-prefix GROUP BY.
        MAX(rp.region_name) AS region,
        pl.date,
        COUNT(*) AS total_requests,
        SUM(CASE WHEN pl.cs_method IN ('DELETE', 'OPTIONS', 'PATCH', 'POST', 'PUT') THEN 1 ELSE 0 END) AS proxy_requests,
        SUM(CASE WHEN pl.x_edge_result_type IN ('FunctionGeneratedResponse', 'FunctionExecutionError', 'FunctionThrottledError') THEN 1 ELSE 0 END) AS cloudfront_function_requests,
        SUM(CASE WHEN pl.x_edge_result_type IN ('LambdaGeneratedResponse', 'LambdaExecutionError', 'LambdaThrottledError') THEN 1 ELSE 0 END) AS lambda_edge_requests,
        SUM(pl.sc_bytes) AS total_bytes,
        SUM(CASE WHEN pl.cs_method IN ('DELETE', 'OPTIONS', 'PATCH', 'POST', 'PUT') THEN pl.cs_bytes ELSE 0 END) AS proxy_bytes,
        -- Prices are constant per region_key, so MAX() carries the single value through GROUP BY.
        MAX(rp.dto_price_per_gb) AS dto_price_per_gb,
        MAX(rp.request_price_per_10k) AS request_price_per_10k
    FROM priced_logs pl
    JOIN "chargeback_database"."cf_region_pricing" rp
        ON pl.region_key = rp.region_key
    GROUP BY
        pl.cs_uri_stem,
        pl.iata_prefix,
        pl.date
)
SELECT
    cs_uri_stem AS "URI Stem",
    region AS "Region",
    total_requests AS "Total Requests",
    date AS "Date",
    total_bytes / power(2, 30) AS "Data Transfer Out in GB",

    -- Data Transfer Out Cost (region price from cf_region_pricing)
    cast(total_bytes / power(2, 30) * dto_price_per_gb as decimal(10,8)) AS "Data Transfer Out Cost",

    -- Request Cost (region price from cf_region_pricing)
    (total_requests / 10000) * request_price_per_10k AS "Request Cost",

    proxy_requests AS "Proxy Requests",
    proxy_bytes AS "Proxy Bytes",

    -- Total Proxy Byte Cost (same per-region DTO price as data transfer out)
    cast(proxy_bytes / power(2, 30) * dto_price_per_gb as decimal(10,8)) AS "Total Proxy Byte Cost",

    cloudfront_function_requests AS "CloudFront Function Requests",
    cloudfront_function_requests * 0.0000001 AS "CloudFront Function Cost",

    lambda_edge_requests AS "Lambda@Edge Requests",
    lambda_edge_requests * 0.0000006 AS "Lambda@Edge Request Cost",
    lambda_edge_requests * 0.005 AS "Lambda@Edge GB/sec",
    lambda_edge_requests * 0.005 * 0.00005001 AS "Lambda@Edge GB/sec cost",
    lambda_edge_requests * (0.0000006 + 0.005 * 0.00005001) AS "Total Lambda@Edge Cost",

    -- Total Cost
    (
        cast(total_bytes / power(2, 30) * dto_price_per_gb as decimal(10,8))
        + (total_requests / 10000) * request_price_per_10k
        + cast(proxy_bytes / power(2, 30) * dto_price_per_gb as decimal(10,8))
        + cloudfront_function_requests * 0.0000001
        + lambda_edge_requests * (0.0000006 + 0.005 * 0.00005001)
    ) AS "Total Cost"
FROM record_count
