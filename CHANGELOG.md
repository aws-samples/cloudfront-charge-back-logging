# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),


##  2026-09-03

### Changed
- Replaced the embedded regional-matching + hardcoded pricing (`CASE` walls) in
  `lib/chargeback-athena-sql.sql` with a JOIN against two version-able Glue fact tables:
  `cf_edge_location_region` (IATA edge prefix → region) and `cf_region_pricing` (per-region
  DTO $/GB, request $/10k, tier), backed by CSVs in `pricing-data/`. Re-pricing a region or
  adding an edge location is now a CSV edit + `cdk deploy` — no SQL change. Query output is
  unchanged (still grouped per edge IATA prefix).

### Added
- cdk-nag `AwsSolutionsChecks` at synth time — security violations fail synth. Suppressions go
  through a justification-enforcing helper (`lib/nag-suppressions.ts`); every waiver is
  resource-scoped with a reason.

##  2025-04-07
 
### Updated
- Athena SQL to have updated fields for readability and Lambda@Edge estimates
- Project renamed from `cloudfront-charge-back-logging` to `cloudfront-chargeback-logging`
- Architecture diagram and screenshots updated
- README.md updated

##  2025-04-23
 
### Updated
- Git history sensitive data cleanup
- Update allowedmethod on distribution to show proxy byte (DTOO) data
- Seperate directory for api-gateway and L@E for clarity
- Seperate athena queries for chargeback and other use cases
- Evaluate time-taken field for L@E estimation. Finding: Lambda coldstart and overhead creates too much ambiguity and difference between the "time taken" and bill duration