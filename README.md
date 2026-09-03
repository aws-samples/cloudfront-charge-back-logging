# Amazon CloudFront behavior-based cost chargeback logging

The solution uses Amazon CloudFront to “chargeback” or allocate/identify CDN costs at a more granular level to better track spend by origin or behavior. The following cost aspects are tracked, on a per behavior basis, for the distribution based on CloudFront standard logs: data transfer out (DTO), requests, CloudFront function invocations, Lambda@Edge invocations, and data transfer out to origin.

For background and a walkthrough of the approach, see the AWS blog post [Implementing granular cost analysis for multi-tenant CloudFront distributions](https://aws.amazon.com/blogs/networking-and-content-delivery/implementing-granular-cost-analysis-for-multi-tenant-cloudfront-distributions/).

This solution ESTIMATES Lambda@Edge total cost by taking the average GB/second cost from the observed behavior of the solution and should be adjusted in the SQL code to reflect your costs more accuractely. For more accuracy you will need to aggregate CloudWatch logs in different Regional Edge Caches (RECs) to determine duration charges. More information on how this can be accomplished can be found [here](https://aws.amazon.com/blogs/networking-and-content-delivery/aggregating-lambdaedge-logs/).

Data visualizations may vary for each customer usecase, but some sample visualization are provided here to extract tenant cost information into Amazon QuickSight.

![Amazon QuickSight Visualizations](images/sample-quicksight-dashboard.png)

## Solution Architecture

This solution only focuses on the chargeback of Amazon CloudFront chargeback, seperated by the dotted line, but can easily be extended to include WAF and Lambda@Edge logs.

![CloudFront ChargeBack Logging Architecture](images/cloudfront-chargeback-logging-architecture-diagram.png)

## Data-driven regional pricing

Regional matching and per-region prices are **not** embedded in the chargeback SQL. Instead, the
deploy creates two small, version-able Glue tables in `chargeback_database` that the query JOINs
against:

| Table | Columns | Purpose |
|-------|---------|---------|
| `cf_edge_location_region` | `iata_prefix`, `region_key` | Maps a CloudFront edge IATA prefix (`SUBSTRING(x_edge_location, 1, 3)`) to a pricing region. |
| `cf_region_pricing` | `region_key`, `region_name`, `dto_price_per_gb`, `request_price_per_10k`, `tier` | Per-region data-transfer-out $/GB and request $/10,000, plus a human-readable region name. |

Both tables are backed by CSVs under [`pricing-data/`](pricing-data/) and deployed to
`s3://<logsBucket>/pricing/` by the CDK stack. `lib/chargeback-athena-sql.sql` JOINs these tables
instead of hardcoding a `CASE` wall of IATA prefixes and prices.

**To re-price a region or add an edge location, edit the CSVs in `pricing-data/` and run
`cdk deploy` — no SQL change is required.** Edge locations with no mapping row fall back to the
`default` row's prices (and the `Unknown` region label). The `tier` column is `first` for every
row today and leaves room for future tiered/volume pricing as a data change rather than a schema
change.

> The prices shipped in `pricing-data/region-pricing/region-pricing.csv` are example list prices.
> Update them to reflect your actual CloudFront pricing (including any private-pricing discounts)
> before relying on the output.

## Requirements

- Node.js 20.x or later
- AWS CDK 2.142.x or later
- Configured AWS credentials


## Deploy on AWS

1. Clone git repository and navigate to CDK project

```bash
git clone https://github.com/aws-samples/cloudfront-chargeback-logging.git
cd cloudfront-chargeback-logging
```

2. Install CDK

```bash
npm install
```

3. Run CDK commands to bootstrap, synthesize, and deploy the CDK stack

```bash
cdk bootstrap
cdk synth
cdk deploy
```

## How to use

CloudFront standard logs will begin to populate as soon as traffic starts flowing through the
distribution. You can visit each of the domain URLs manually in your browser or adjust the shell
script below, inserting the distribution URL output from the CDK.

```bash
base_url="<your template output domain>"
get_urls=("$base_url" "$base_url/EdgeLambda.html" "$base_url/EdgeFunc.html")
post_url="$base_url/api/"

# Function to perform random GET or POST request
perform_request() {
    # Generate a random number between 0 and 4
    random_number=$((RANDOM % 5))

    # If the random number is 4, perform a POST request
    if [ $random_number -eq 4 ]; then
        echo "Performing POST request to $post_url"
        curl -X POST "$post_url"
    else
        # Get a random URL from the get_urls array
        random_url=${get_urls[$random_number]}
        echo "Performing GET request to $random_url"
        curl "$random_url"
    fi
}

for i in {1..10000}
do
    echo "Iteration $i"
    perform_request
    echo ""  # Add an empty line for better readability
done
```

An alternative method for distributed testing would be using the [Distributed Load Testing Solution from the AWS Solutions library](https://aws.amazon.com/solutions/implementations/distributed-load-testing-on-aws/).

4. If this is the first-time using Athena in your AWS account, then you must setup 
an Amazon S3 output bucket for query results. There is a banner to walk you through 
the setup, but more information can be found on the [Getting Started](https://docs.aws.amazon.com/athena/latest/ug/getting-started.html) page.

5. Once you're able to query the `cf-logs-table` in the `chargeback_database`, the [`chargeback-athena-sql.sql`](lib/chargeback-athena-sql.sql) can be used to create your aggregation table. Additional exploratory queries (cache hit ratio, error counts) are in [`lib/additional-athena-queries.sql`](lib/additional-athena-queries.sql).

[Athena Query Example](images/athena-query-example-output.png)

6. Configure QuickSight bucket permissions by navigating to "Manage Permissions" in the top right of the console > Security & permissions > QuickSight access to AWS services > Manage. Here you can select the S3 buckets QuickSight has access to by selecting the CloudFront logging bucket created by the CDK.

## Testing CDK constructs
```
npm test
```

## Destroy CDK app resources

To clean up your CDK app run the below command:
```bash
cdk destroy --all
```

Please be aware that some resources aren't automatically deleted and either 
need a retention policy that allows deletes or you need to delete them manually 
in you AWS account. Deleting Lambda@Edge might fail because the function can 
only be deleted after replicas of the function have been deleted by CloudFront.

## Useful commands

* `npm run build`   compile typescript to js
* `npm run watch`   watch for changes and compile
* `npm run test`    perform the jest unit tests
* `cdk deploy`      deploy this stack to your default AWS account/region
* `cdk diff`        compare deployed stack with current state
* `cdk synth`       emits the synthesized CloudFormation template

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This sample code is licensed under the MIT-0 License. See the LICENSE file.

## Generative AI disclosure

Generative AI (Anthropic Claude, via Claude Code) was used to help build, test, and document
this solution. All AI-assisted output was reviewed and validated by a human before inclusion —
including `cdk synth`/`cdk-nag` and unit-test runs, and verification of deployment in a test
account.