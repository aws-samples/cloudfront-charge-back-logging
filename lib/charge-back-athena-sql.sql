WITH record_count AS (
    SELECT
        cs_uri_stem,
        region,
        date,
        COUNT(*) AS total_records
    FROM
        (
            SELECT
                cs_uri_stem,
                date,
                CASE SUBSTRING(x_edge_location, 1, 3)
                    -- United States, Mexico and Canada
                    WHEN 'IAD' THEN 'United States'
                    WHEN 'CMH' THEN 'United States'
                    WHEN 'SFO' THEN 'United States'
                    WHEN 'PDX' THEN 'United States'
                    WHEN 'SEA' THEN 'United States'
                    WHEN 'DEN' THEN 'United States'
                    WHEN 'PHX' THEN 'United States'
                    WHEN 'DFW' THEN 'United States'
                    WHEN 'ORD' THEN 'United States'
                    WHEN 'ATL' THEN 'United States'
                    WHEN 'MIA' THEN 'United States'
                    WHEN 'EWR' THEN 'United States'
                    WHEN 'BOS' THEN 'United States'
                    WHEN 'MDW' THEN 'United States'
                    WHEN 'LAS' THEN 'United States'
                    WHEN 'LAX' THEN 'United States'
                    WHEN 'MEX' THEN 'Mexico'
                    WHEN 'YUL' THEN 'Canada'
                    WHEN 'YYZ' THEN 'Canada'
                    WHEN 'YVR' THEN 'Canada'
                    WHEN 'YXU' THEN 'Canada'
                
                    -- Europe, Israel and Türkiye
                    WHEN 'FRA' THEN 'Europe'
                    WHEN 'STO' THEN 'Europe'
                    WHEN 'MIL' THEN 'Europe'
                    WHEN 'DUB' THEN 'Europe'
                    WHEN 'LON' THEN 'Europe'
                    WHEN 'PAR' THEN 'Europe'
                    WHEN 'VIE' THEN 'Europe'
                    WHEN 'ZRH' THEN 'Europe'
                    WHEN 'LHR' THEN 'Europe'
                    WHEN 'CDG' THEN 'Europe'
                    WHEN 'AMS' THEN 'Europe'
                    WHEN 'ARN' THEN 'Europe'
                    WHEN 'CPH' THEN 'Europe'
                    WHEN 'LIS' THEN 'Europe'
                    WHEN 'MAD' THEN 'Europe'
                    WHEN 'MXP' THEN 'Europe'
                    -- Add specific entries for Israel and Türkiye if available
                
                    -- South Africa, Kenya, Nigeria, Egypt and Middle East
                    WHEN 'DXB' THEN 'Middle East'
                    WHEN 'BAH' THEN 'Middle East'
                    WHEN 'CPT' THEN 'South Africa'
                    WHEN 'JNB' THEN 'South Africa'
                    WHEN 'RUH' THEN 'Middle East'
                    WHEN 'KWI' THEN 'Middle East'
                
                    -- South America
                    WHEN 'GRU' THEN 'South America'
                    WHEN 'BOG' THEN 'South America'
                    WHEN 'LIM' THEN 'South America'
                    WHEN 'SCL' THEN 'South America'
                
                    -- Japan
                    WHEN 'NRT' THEN 'Japan'
                    WHEN 'OSA' THEN 'Japan'
                    WHEN 'HND' THEN 'Japan'
                
                    -- Australia and New Zealand
                    WHEN 'SYD' THEN 'Australia'
                
                    -- Hong Kong, Indonesia, Philippines, Singapore, South Korea, Taiwan, Thailand, Malaysia and Vietnam
                    WHEN 'SIN' THEN 'Singapore'
                    WHEN 'JKT' THEN 'Indonesia'
                    WHEN 'HKG' THEN 'Hong Kong'
                    WHEN 'SEL' THEN 'South Korea'
                    WHEN 'TPE' THEN 'Taiwan'
                    WHEN 'KUL' THEN 'Malaysia'
                    WHEN 'BKK' THEN 'Thailand'
                    WHEN 'ICN' THEN 'South Korea'
                    WHEN 'PNQ' THEN 'Philippines'
                    WHEN 'HIO' THEN 'Vietnam'
                
                    -- India
                    WHEN 'MUM' THEN 'India'
                    WHEN 'BOM' THEN 'India'
                    WHEN 'DEL' THEN 'India'
                    WHEN 'MAA' THEN 'India'
                    WHEN 'BLR' THEN 'India'
                    WHEN 'HYD' THEN 'India'
                
                    ELSE 'Unknown'
                END AS region
            FROM
                "chargeback_database"."cf-logs-table"
        ) subquery
    GROUP BY
        cs_uri_stem, region, date
)
SELECT
    rc.cs_uri_stem,
    rc.region,
    rc.total_records,
    rc.date,
    sum(sc_bytes) / power(2, 30) as total_gb,
    CASE
        WHEN rc.region IN ('United States', 'Mexico', 'Canada') THEN cast(sum(sc_bytes) / power(2, 30) * 0.085 as decimal(10,8))
        WHEN rc.region IN ('Europe', 'Israel', 'Türkiye') THEN cast(sum(sc_bytes) / power(2, 30) * 0.085 as decimal(10,8))
        WHEN rc.region IN ('South Africa', 'Kenya', 'Nigeria', 'Middle East') THEN cast(sum(sc_bytes) / power(2, 30) * 0.110 as decimal(10,8))
        WHEN rc.region = 'South America' THEN cast(sum(sc_bytes) / power(2, 30) * 0.110 as decimal(10,8))
        WHEN rc.region = 'Japan' THEN cast(sum(sc_bytes) / power(2, 30) * 0.114 as decimal(10,8))
        WHEN rc.region = 'Australia and New Zealand' THEN cast(sum(sc_bytes) / power(2, 30) * 0.114 as decimal(10,8))
        WHEN rc.region IN ('Hong Kong', 'Indonesia', 'Philippines', 'Singapore', 'South Korea', 'Taiwan', 'Thailand', 'Malaysia', 'Vietnam') THEN cast(sum(sc_bytes) / power(2, 30) * 0.120 as decimal(10,8))
        WHEN rc.region = 'India' THEN cast(sum(sc_bytes) / power(2, 30) * 0.109 as decimal(10,8))
        ELSE cast(sum(sc_bytes) / power(2, 30) * 0.110 as decimal(10,8))
    END AS cost,
    CASE
        WHEN rc.region IN ('United States', 'Mexico', 'Canada') THEN (rc.total_records / 10000) * 0.01
        WHEN rc.region IN ('Europe', 'Israel', 'Türkiye') THEN (rc.total_records / 10000) * 0.012
        WHEN rc.region IN ('South Africa', 'Kenya', 'Nigeria', 'Middle East') THEN (rc.total_records / 10000) * 0.012
        WHEN rc.region = 'South America' THEN (rc.total_records / 10000) * 0.022
        WHEN rc.region = 'Japan' THEN (rc.total_records / 10000) * 0.012
        WHEN rc.region = 'Australia and New Zealand' THEN (rc.total_records / 10000) * 0.0125
        WHEN rc.region IN ('Hong Kong', 'Indonesia', 'Philippines', 'Singapore', 'South Korea', 'Taiwan', 'Thailand', 'Malaysia', 'Vietnam') THEN (rc.total_records / 10000) * 0.012
        WHEN rc.region = 'India' THEN (rc.total_records / 10000) * 0.012
        ELSE (rc.total_records / 10000) * 0.012
    END AS request_cost,
    SUM(CASE
        WHEN cs_method IN ('DELETE', 'OPTIONS', 'PATCH', 'POST', 'PUT') THEN 1
        ELSE 0
    END) AS proxy_requests,
    SUM(CASE
        WHEN cs_method IN ('DELETE', 'OPTIONS', 'PATCH', 'POST', 'PUT') THEN cs_bytes
        ELSE 0
    END) AS proxy_bytes,
    CASE
        WHEN rc.region IN ('United States', 'Mexico', 'Canada') THEN cast(SUM(CASE WHEN cs_method IN ('DELETE', 'OPTIONS', 'PATCH', 'POST', 'PUT') THEN cs_bytes END) / power(2, 30) * 0.085 as decimal(10,8))
        WHEN rc.region IN ('Europe', 'Israel', 'Türkiye') THEN cast(SUM(CASE WHEN cs_method IN ('DELETE', 'OPTIONS', 'PATCH', 'POST', 'PUT') THEN cs_bytes END) / power(2, 30) * 0.085 as decimal(10,8))
        WHEN rc.region IN ('South Africa', 'Kenya', 'Nigeria', 'Middle East') THEN cast(SUM(CASE WHEN cs_method IN ('DELETE', 'OPTIONS', 'PATCH', 'POST', 'PUT') THEN cs_bytes END) / power(2, 30) * 0.110 as decimal(10,8))
        WHEN rc.region = 'South America' THEN cast(SUM(CASE WHEN cs_method IN ('DELETE', 'OPTIONS', 'PATCH', 'POST', 'PUT') THEN cs_bytes END) / power(2, 30) * 0.110 as decimal(10,8))
        WHEN rc.region = 'Japan' THEN cast(SUM(CASE WHEN cs_method IN ('DELETE', 'OPTIONS', 'PATCH', 'POST', 'PUT') THEN cs_bytes END) / power(2, 30) * 0.114 as decimal(10,8))
        WHEN rc.region = 'Australia and New Zealand' THEN cast(SUM(CASE WHEN cs_method IN ('DELETE', 'OPTIONS', 'PATCH', 'POST', 'PUT') THEN cs_bytes END) / power(2, 30) * 0.114 as decimal(10,8))
        WHEN rc.region IN ('Hong Kong', 'Indonesia', 'Philippines', 'Singapore', 'South Korea', 'Taiwan', 'Thailand', 'Malaysia', 'Vietnam') THEN cast(SUM(CASE WHEN cs_method IN ('DELETE', 'OPTIONS', 'PATCH', 'POST', 'PUT') THEN cs_bytes END) / power(2, 30) * 0.120 as decimal(10,8))
        WHEN rc.region = 'India' THEN cast(SUM(CASE WHEN cs_method IN ('DELETE', 'OPTIONS', 'PATCH', 'POST', 'PUT') THEN cs_bytes END) / power(2, 30) * 0.109 as decimal(10,8))
        ELSE cast(SUM(CASE WHEN cs_method IN ('DELETE', 'OPTIONS', 'PATCH', 'POST', 'PUT') THEN cs_bytes END) / power(2, 30) * 0.110 as decimal(10,8))
    END AS proxy_cost,
    SUM(CASE
        WHEN x_edge_result_type IN ('FunctionGeneratedResponse', 'FunctionExecutionError', 'FunctionThrottledError') THEN 1
        ELSE 0
    END) AS function_requests,
    SUM(CASE
        WHEN x_edge_result_type IN ('FunctionGeneratedResponse', 'FunctionExecutionError', 'FunctionThrottledError') THEN 1
        ELSE 0
    END) * 0.0000001 AS function_cost
FROM
    record_count rc
    JOIN "chargeback_database"."cf-logs-table" logs ON rc.cs_uri_stem = logs.cs_uri_stem AND rc.region = CASE SUBSTRING(logs.x_edge_location, 1, 3)
        -- United States, Mexico and Canada
        WHEN 'IAD' THEN 'United States'
        WHEN 'CMH' THEN 'United States'
        WHEN 'SFO' THEN 'United States'
        WHEN 'PDX' THEN 'United States'
        WHEN 'SEA' THEN 'United States'
        WHEN 'DEN' THEN 'United States'
        WHEN 'PHX' THEN 'United States'
        WHEN 'DFW' THEN 'United States'
        WHEN 'ORD' THEN 'United States'
        WHEN 'ATL' THEN 'United States'
        WHEN 'MIA' THEN 'United States'
        WHEN 'EWR' THEN 'United States'
        WHEN 'BOS' THEN 'United States'
        WHEN 'MDW' THEN 'United States'
        WHEN 'LAS' THEN 'United States'
        WHEN 'LAX' THEN 'United States'
        WHEN 'MEX' THEN 'Mexico'
        WHEN 'YUL' THEN 'Canada'
        WHEN 'YYZ' THEN 'Canada'
        WHEN 'YVR' THEN 'Canada'
        WHEN 'YXU' THEN 'Canada'

        -- Europe, Israel and Türkiye
        WHEN 'FRA' THEN 'Europe'
        WHEN 'STO' THEN 'Europe'
        WHEN 'MIL' THEN 'Europe'
        WHEN 'DUB' THEN 'Europe'
        WHEN 'LON' THEN 'Europe'
        WHEN 'PAR' THEN 'Europe'
        WHEN 'VIE' THEN 'Europe'
        WHEN 'ZRH' THEN 'Europe'
        WHEN 'LHR' THEN 'Europe'
        WHEN 'CDG' THEN 'Europe'
        WHEN 'AMS' THEN 'Europe'
        WHEN 'ARN' THEN 'Europe'
        WHEN 'CPH' THEN 'Europe'
        WHEN 'LIS' THEN 'Europe'
        WHEN 'MAD' THEN 'Europe'
        WHEN 'MXP' THEN 'Europe'
        -- Add specific entries for Israel and Türkiye if available

        -- South Africa, Kenya, Nigeria, Egypt and Middle East
        WHEN 'DXB' THEN 'Middle East'
        WHEN 'BAH' THEN 'Middle East'
        WHEN 'CPT' THEN 'South Africa'
        WHEN 'JNB' THEN 'South Africa'
        WHEN 'RUH' THEN 'Middle East'
        WHEN 'KWI' THEN 'Middle East'

        -- South America
        WHEN 'GRU' THEN 'South America'
        WHEN 'BOG' THEN 'South America'
        WHEN 'LIM' THEN 'South America'
        WHEN 'SCL' THEN 'South America'

        -- Japan
        WHEN 'NRT' THEN 'Japan'
        WHEN 'OSA' THEN 'Japan'
        WHEN 'HND' THEN 'Japan'

        -- Australia and New Zealand
        WHEN 'SYD' THEN 'Australia'

        -- Hong Kong, Indonesia, Philippines, Singapore, South Korea, Taiwan, Thailand, Malaysia and Vietnam
        WHEN 'SIN' THEN 'Singapore'
        WHEN 'JKT' THEN 'Indonesia'
        WHEN 'HKG' THEN 'Hong Kong'
        WHEN 'SEL' THEN 'South Korea'
        WHEN 'TPE' THEN 'Taiwan'
        WHEN 'KUL' THEN 'Malaysia'
        WHEN 'BKK' THEN 'Thailand'
        WHEN 'ICN' THEN 'South Korea'
        WHEN 'PNQ' THEN 'Philippines'
        WHEN 'HIO' THEN 'Vietnam'

        -- India
        WHEN 'MUM' THEN 'India'
        WHEN 'BOM' THEN 'India'
        WHEN 'DEL' THEN 'India'
        WHEN 'MAA' THEN 'India'
        WHEN 'BLR' THEN 'India'
        WHEN 'HYD' THEN 'India'
 
        ELSE 'Unknown'
    END
GROUP BY
    rc.cs_uri_stem, rc.region, rc.total_records, rc.date;


WITH record_count AS (
    SELECT
        cs_uri_stem,
        region,
        date,
        COUNT(*) AS total_records
    FROM
        (
            SELECT
                cs_uri_stem,
                date,
                CASE SUBSTRING(x_edge_location, 1, 3)
                    WHEN 'IAD' THEN 'United States'
                    WHEN 'CMH' THEN 'United States'
                    WHEN 'SFO' THEN 'United States'
                    WHEN 'PDX' THEN 'United States'
                    WHEN 'SEA' THEN 'United States'
                    WHEN 'DEN' THEN 'United States'
                    WHEN 'PHX' THEN 'United States'
                    WHEN 'DFW' THEN 'United States'
                    WHEN 'ORD' THEN 'United States'
                    WHEN 'ATL' THEN 'United States'
                    WHEN 'MIA' THEN 'United States'
                    WHEN 'EWR' THEN 'United States'
                    WHEN 'BOS' THEN 'United States'
                    WHEN 'MDW' THEN 'United States'
                    WHEN 'LAS' THEN 'United States'
                    WHEN 'LAX' THEN 'United States'
                    WHEN 'HIO' THEN 'United States'
                    WHEN 'MEX' THEN 'Mexico'
                    WHEN 'YUL' THEN 'Canada'
                    WHEN 'YYZ' THEN 'Canada'
                    WHEN 'YVR' THEN 'Canada'
                    WHEN 'YXU' THEN 'Canada'
                    WHEN 'FRA' THEN 'Europe'
                    WHEN 'STO' THEN 'Europe'
                    WHEN 'MIL' THEN 'Europe'
                    WHEN 'DUB' THEN 'Europe'
                    WHEN 'LON' THEN 'Europe'
                    WHEN 'PAR' THEN 'Europe'
                    WHEN 'VIE' THEN 'Europe'
                    WHEN 'ZRH' THEN 'Europe'
                    WHEN 'LHR' THEN 'Europe'
                    WHEN 'CDG' THEN 'Europe'
                    WHEN 'AMS' THEN 'Europe'
                    WHEN 'ARN' THEN 'Europe'
                    WHEN 'CPH' THEN 'Europe'
                    WHEN 'LIS' THEN 'Europe'
                    WHEN 'MAD' THEN 'Europe'
                    WHEN 'MXP' THEN 'Europe'
                    WHEN 'DXB' THEN 'Middle East'
                    WHEN 'BAH' THEN 'Middle East'
                    WHEN 'CPT' THEN 'South Africa'
                    WHEN 'JNB' THEN 'South Africa'
                    WHEN 'RUH' THEN 'Middle East'
                    WHEN 'KWI' THEN 'Middle East'
                    WHEN 'GRU' THEN 'South America'
                    WHEN 'BOG' THEN 'South America'
                    WHEN 'LIM' THEN 'South America'
                    WHEN 'SCL' THEN 'South America'
                    WHEN 'NRT' THEN 'Japan'
                    WHEN 'OSA' THEN 'Japan'
                    WHEN 'HND' THEN 'Japan'
                    WHEN 'SYD' THEN 'Australia and New Zealand'
                    WHEN 'SIN' THEN 'Singapore'
                    WHEN 'JKT' THEN 'Indonesia'
                    WHEN 'HKG' THEN 'Hong Kong'
                    WHEN 'SEL' THEN 'South Korea'
                    WHEN 'TPE' THEN 'Taiwan'
                    WHEN 'KUL' THEN 'Malaysia'
                    WHEN 'BKK' THEN 'Thailand'
                    WHEN 'ICN' THEN 'South Korea'
                    WHEN 'PNQ' THEN 'Philippines'
                    WHEN 'SGN' THEN 'Vietnam'
                    WHEN 'MUM' THEN 'India'
                    WHEN 'BOM' THEN 'India'
                    WHEN 'DEL' THEN 'India'
                    WHEN 'MAA' THEN 'India'
                    WHEN 'BLR' THEN 'India'
                    WHEN 'HYD' THEN 'India'
                    ELSE 'Unknown'
                END AS region
            FROM
                "chargeback_database"."cf-logs-table"
        ) subquery
    GROUP BY
        cs_uri_stem, region, date
)
SELECT
    rc.cs_uri_stem,
    rc.region,
    rc.total_records,
    rc.date,
    sum(sc_bytes) / power(2, 30) as total_gb,
    CASE
        WHEN rc.region IN ('United States', 'Mexico', 'Canada') THEN cast(sum(sc_bytes) / power(2, 30) * 0.085 as decimal(10,8))
        WHEN rc.region IN ('Europe') THEN cast(sum(sc_bytes) / power(2, 30) * 0.085 as decimal(10,8))
        WHEN rc.region IN ('South Africa', 'Kenya', 'Nigeria', 'Middle East') THEN cast(sum(sc_bytes) / power(2, 30) * 0.110 as decimal(10,8))
        WHEN rc.region = 'South America' THEN cast(sum(sc_bytes) / power(2, 30) * 0.110 as decimal(10,8))
        WHEN rc.region = 'Japan' THEN cast(sum(sc_bytes) / power(2, 30) * 0.114 as decimal(10,8))
        WHEN rc.region = 'Australia and New Zealand' THEN cast(sum(sc_bytes) / power(2, 30) * 0.114 as decimal(10,8))
        WHEN rc.region IN ('Hong Kong', 'Indonesia', 'Philippines', 'Singapore', 'South Korea', 'Taiwan', 'Thailand', 'Malaysia', 'Vietnam') THEN cast(sum(sc_bytes) / power(2, 30) * 0.120 as decimal(10,8))
        WHEN rc.region = 'India' THEN cast(sum(sc_bytes) / power(2, 30) * 0.109 as decimal(10,8))
        ELSE cast(sum(sc_bytes) / power(2, 30) * 0.110 as decimal(10,8))
    END AS cost,
    CASE
        WHEN rc.region IN ('United States', 'Mexico', 'Canada') THEN (rc.total_records / 10000) * 0.01
        WHEN rc.region IN ('Europe') THEN (rc.total_records / 10000) * 0.012
        WHEN rc.region IN ('South Africa', 'Kenya', 'Nigeria', 'Middle East') THEN (rc.total_records / 10000) * 0.012
        WHEN rc.region = 'South America' THEN (rc.total_records / 10000) * 0.022
        WHEN rc.region = 'Japan' THEN (rc.total_records / 10000) * 0.012
        WHEN rc.region = 'Australia and New Zealand' THEN (rc.total_records / 10000) * 0.0125
        WHEN rc.region IN ('Hong Kong', 'Indonesia', 'Philippines', 'Singapore', 'South Korea', 'Taiwan', 'Thailand', 'Malaysia', 'Vietnam') THEN (rc.total_records / 10000) * 0.012
        WHEN rc.region = 'India' THEN (rc.total_records / 10000) * 0.012
        ELSE (rc.total_records / 10000) * 0.012
    END AS request_cost,
    SUM(CASE
        WHEN cs_method IN ('DELETE', 'OPTIONS', 'PATCH', 'POST', 'PUT') THEN 1
        ELSE 0
    END) AS proxy_requests,
    SUM(CASE
        WHEN cs_method IN ('DELETE', 'OPTIONS', 'PATCH', 'POST', 'PUT') THEN cs_bytes
        ELSE 0
    END) AS proxy_bytes,
    CASE
        WHEN rc.region IN ('United States', 'Mexico', 'Canada') THEN cast(SUM(CASE WHEN cs_method IN ('DELETE', 'OPTIONS', 'PATCH', 'POST', 'PUT') THEN cs_bytes END) / power(2, 30) * 0.085 as decimal(10,8))
        WHEN rc.region IN ('Europe') THEN cast(SUM(CASE WHEN cs_method IN ('DELETE', 'OPTIONS', 'PATCH', 'POST', 'PUT') THEN cs_bytes END) / power(2, 30) * 0.085 as decimal(10,8))
        WHEN rc.region IN ('South Africa', 'Kenya', 'Nigeria', 'Middle East') THEN cast(SUM(CASE WHEN cs_method IN ('DELETE', 'OPTIONS', 'PATCH', 'POST', 'PUT') THEN cs_bytes END) / power(2, 30) * 0.110 as decimal(10,8))
        WHEN rc.region = 'South America' THEN cast(SUM(CASE WHEN cs_method IN ('DELETE', 'OPTIONS', 'PATCH', 'POST', 'PUT') THEN cs_bytes END) / power(2, 30) * 0.110 as decimal(10,8))
        WHEN rc.region = 'Japan' THEN cast(SUM(CASE WHEN cs_method IN ('DELETE', 'OPTIONS', 'PATCH', 'POST', 'PUT') THEN cs_bytes END) / power(2, 30) * 0.114 as decimal(10,8))
        WHEN rc.region = 'Australia and New Zealand' THEN cast(SUM(CASE WHEN cs_method IN ('DELETE', 'OPTIONS', 'PATCH', 'POST', 'PUT') THEN cs_bytes END) / power(2, 30) * 0.114 as decimal(10,8))
        WHEN rc.region IN ('Hong Kong', 'Indonesia', 'Philippines', 'Singapore', 'South Korea', 'Taiwan', 'Thailand', 'Malaysia', 'Vietnam') THEN cast(SUM(CASE WHEN cs_method IN ('DELETE', 'OPTIONS', 'PATCH', 'POST', 'PUT') THEN cs_bytes END) / power(2, 30) * 0.120 as decimal(10,8))
        WHEN rc.region = 'India' THEN cast(SUM(CASE WHEN cs_method IN ('DELETE', 'OPTIONS', 'PATCH', 'POST', 'PUT') THEN cs_bytes END) / power(2, 30) * 0.109 as decimal(10,8))
        ELSE cast(SUM(CASE WHEN cs_method IN ('DELETE', 'OPTIONS', 'PATCH', 'POST', 'PUT') THEN cs_bytes END) / power(2, 30) * 0.110 as decimal(10,8))
    END AS proxy_cost,
    SUM(CASE
        WHEN x_edge_result_type IN ('FunctionGeneratedResponse', 'FunctionExecutionError', 'FunctionThrottledError') THEN 1
        ELSE 0
    END) AS function_requests,
    SUM(CASE
        WHEN x_edge_result_type IN ('FunctionGeneratedResponse', 'FunctionExecutionError', 'FunctionThrottledError') THEN 1
        ELSE 0
    END) * 0.0000001 AS function_cost
FROM
    record_count rc
    JOIN "chargeback_database"."cf-logs-table" logs ON rc.cs_uri_stem = logs.cs_uri_stem AND rc.region = CASE SUBSTRING(logs.x_edge_location, 1, 3)
        WHEN 'IAD' THEN 'United States'
        WHEN 'CMH' THEN 'United States'
        WHEN 'SFO' THEN 'United States'
        WHEN 'PDX' THEN 'United States'
        WHEN 'SEA' THEN 'United States'
        WHEN 'DEN' THEN 'United States'
        WHEN 'PHX' THEN 'United States'
        WHEN 'DFW' THEN 'United States'
        WHEN 'ORD' THEN 'United States'
        WHEN 'ATL' THEN 'United States'
        WHEN 'MIA' THEN 'United States'
        WHEN 'EWR' THEN 'United States'
        WHEN 'BOS' THEN 'United States'
        WHEN 'MDW' THEN 'United States'
        WHEN 'LAS' THEN 'United States'
        WHEN 'LAX' THEN 'United States'
        WHEN 'HIO' THEN 'United States'
        WHEN 'MEX' THEN 'Mexico'
        WHEN 'YUL' THEN 'Canada'
        WHEN 'YYZ' THEN 'Canada'
        WHEN 'YVR' THEN 'Canada'
        WHEN 'YXU' THEN 'Canada'
        WHEN 'FRA' THEN 'Europe'
        WHEN 'STO' THEN 'Europe'
        WHEN 'MIL' THEN 'Europe'
        WHEN 'DUB' THEN 'Europe'
        WHEN 'LON' THEN 'Europe'
        WHEN 'PAR' THEN 'Europe'
        WHEN 'VIE' THEN 'Europe'
        WHEN 'ZRH' THEN 'Europe'
        WHEN 'LHR' THEN 'Europe'
        WHEN 'CDG' THEN 'Europe'
        WHEN 'AMS' THEN 'Europe'
        WHEN 'ARN' THEN 'Europe'
        WHEN 'CPH' THEN 'Europe'
        WHEN 'LIS' THEN 'Europe'
        WHEN 'MAD' THEN 'Europe'
        WHEN 'MXP' THEN 'Europe'
        WHEN 'DXB' THEN 'Middle East'
        WHEN 'BAH' THEN 'Middle East'
        WHEN 'CPT' THEN 'South Africa'
        WHEN 'JNB' THEN 'South Africa'
        WHEN 'RUH' THEN 'Middle East'
        WHEN 'KWI' THEN 'Middle East'
        WHEN 'GRU' THEN 'South America'
        WHEN 'BOG' THEN 'South America'
        WHEN 'LIM' THEN 'South America'
        WHEN 'SCL' THEN 'South America'
        WHEN 'NRT' THEN 'Japan'
        WHEN 'OSA' THEN 'Japan'
        WHEN 'HND' THEN 'Japan'
        WHEN 'SYD' THEN 'Australia and New Zealand'
        WHEN 'SIN' THEN 'Singapore'
        WHEN 'JKT' THEN 'Indonesia'
        WHEN 'HKG' THEN 'Hong Kong'
        WHEN 'SEL' THEN 'South Korea'
        WHEN 'TPE' THEN 'Taiwan'
        WHEN 'KUL' THEN 'Malaysia'
        WHEN 'BKK' THEN 'Thailand'
        WHEN 'ICN' THEN 'South Korea'
        WHEN 'PNQ' THEN 'Philippines'
        WHEN 'SGN' THEN 'Vietnam' -- Corrected mapping for SGN (Ho Chi Minh City)
        WHEN 'MUM' THEN 'India'
        WHEN 'BOM' THEN 'India'
        WHEN 'DEL' THEN 'India'
        WHEN 'MAA' THEN 'India'
        WHEN 'BLR' THEN 'India'
        WHEN 'HYD' THEN 'India'
        ELSE 'Unknown'
    END
GROUP BY
    rc.cs_uri_stem, rc.region, rc.total_records, rc.date;



-- Cache hit ratio and count by day and behavior
SELECT
    cs_uri_stem,
    date AS log_date,
    SUM(CASE WHEN x_edge_response_result_type IN ('Hit', 'PartialHit') THEN 1 ELSE 0 END) AS cache_hits,
    SUM(CASE WHEN x_edge_response_result_type NOT IN ('Hit', 'PartialHit') THEN 1 ELSE 0 END) AS cache_misses,
    ROUND(SUM(CASE WHEN x_edge_response_result_type IN ('Hit', 'PartialHit') THEN 1 ELSE 0 END) * 100.0 /
          (SUM(CASE WHEN x_edge_response_result_type IN ('Hit', 'PartialHit') THEN 1 ELSE 0 END) +
           SUM(CASE WHEN x_edge_response_result_type NOT IN ('Hit', 'PartialHit') THEN 1 ELSE 0 END)), 2) AS cache_hit_ratio
FROM
    "chargeback_database"."cf-logs-table"
GROUP BY
    cs_uri_stem,
    date
ORDER BY
    cs_uri_stem,
    log_date;


-- URI stem error count by behavior
SELECT
    cs_uri_stem,
    sc_status,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY cs_uri_stem), 2) AS percentage
FROM
    "chargeback_database"."cf-logs-table"
GROUP BY
    cs_uri_stem,
    sc_status
ORDER BY
    cs_uri_stem,
    count DESC;