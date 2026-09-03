import {
  Aws,
  CfnOutput,
  RemovalPolicy,
  Stack,
  StackProps,
  Duration,
} from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as path from 'path';

import * as glue_alpha from '@aws-cdk/aws-glue-alpha';
import * as glue from 'aws-cdk-lib/aws-glue';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as logs from 'aws-cdk-lib/aws-logs';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as cloudfront from 'aws-cdk-lib/aws-cloudfront';
import * as origins from 'aws-cdk-lib/aws-cloudfront-origins';
import * as waf from 'aws-cdk-lib/aws-wafv2';
import * as s3deploy from 'aws-cdk-lib/aws-s3-deployment';

import { suppress, suppressByPath } from './nag-suppressions';

export class CloudfrontChargeBackLoggingStack extends Stack {
  public readonly logLandingBucket: s3.Bucket;

  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    // CloudFront standard logs bucket
    const logLandingBucket = new s3.Bucket(this, 'log-landing-bucket', {
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      encryption: s3.BucketEncryption.S3_MANAGED,
      versioned: true,
      enforceSSL: true,
      accessControl: s3.BucketAccessControl.LOG_DELIVERY_WRITE,
      autoDeleteObjects: true,
      removalPolicy: RemovalPolicy.DESTROY
    });

    // Enable logging for WAF logs to Amazon S3
    const waflogLandingBucket = new s3.Bucket(this, 'waf-log-landing-bucket', {
      bucketName: `aws-waf-logs-chargeback-${Aws.ACCOUNT_ID}-${Aws.REGION}`,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      encryption: s3.BucketEncryption.S3_MANAGED,
      versioned: true,
      enforceSSL: true,
      accessControl: s3.BucketAccessControl.LOG_DELIVERY_WRITE,
      removalPolicy: RemovalPolicy.DESTROY
    });
    waflogLandingBucket.addToResourcePolicy(
      new iam.PolicyStatement({
        principals: [ new iam.ServicePrincipal('delivery.logs.amazonaws.com')],
        actions: ['s3:PutObject', 's3:GetBucketAcl'],
        resources: [`${waflogLandingBucket.bucketArn}`, `${waflogLandingBucket.bucketArn}/*` ],
      })
    );

    // Bucket for hosting SPA
    const spaBucket = new s3.Bucket(this, 'spa-bucket', {
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      encryption: s3.BucketEncryption.S3_MANAGED,
      versioned: true,
      enforceSSL: true,
      autoDeleteObjects: true,
      removalPolicy: RemovalPolicy.DESTROY,
    });

    // Create access identity, and grant read access only, to use w/ CloudFront
    // Create an origin for the CloudFront distribution to reference
    const s3AccessIdentity = new cloudfront.OriginAccessIdentity(this, 'origin-access-identity', {
        comment: "Setup access from CloudFront to the bucket ( read )",
    });
    spaBucket.grantRead(s3AccessIdentity);

    // LogGroup for aggregating logs from the Lambda@Edge function
    const lambdaEdgeLogGroup = new logs.LogGroup(this, 'lambda-edge-log-group', {
      logGroupName: `/aws/lambda/us-east-1.chargeBackLambdaEdge`,
      removalPolicy: RemovalPolicy.DESTROY,
    });
    const spaOrigin = new origins.S3Origin(spaBucket, {originAccessIdentity: s3AccessIdentity})

    // Creating L@E function
    const lambdaEdgeFunction = new cloudfront.experimental.EdgeFunction(this, 'lambda-edge-function', {
      runtime: lambda.Runtime.NODEJS_LATEST,
      handler: 'index.handler',
      functionName: 'chargeBackLambdaEdge',
      code: lambda.Code.fromAsset(path.join('src/', 'lambda')),
      logGroup: lambdaEdgeLogGroup,
    });

    // WAF for the CF distribution and logging configuration to WACL
    const chargeBackWACL = new waf.CfnWebACL(this, 'chargeback-wacl', {
      defaultAction: {
        allow: {}
      },
      scope: 'CLOUDFRONT',
      visibilityConfig: {
        cloudWatchMetricsEnabled: true,
        metricName:'MetricForWebACLCDK',
        sampledRequestsEnabled: true,
      },
      name: 'ChargeBackWACL',
      rules: [{
        name: 'CRSRule',
        priority: 0,
        statement: {
          managedRuleGroupStatement: {
            name:'AWSManagedRulesCommonRuleSet',
            vendorName:'AWS'
          }
        },
        visibilityConfig: {
          cloudWatchMetricsEnabled: true,
          metricName:'MetricForWebACLCDK-CRS',
          sampledRequestsEnabled: true,
        },
        overrideAction: {
          none: {}
        },
      },
      {
        name: 'IPReputationRule',
        priority: 1,
        statement: {
          managedRuleGroupStatement: {
            name:'AWSManagedRulesAmazonIpReputationList',
            vendorName:'AWS'
          }
        },
        visibilityConfig: {
          cloudWatchMetricsEnabled: true,
          metricName:'MetricForWebACLCDK-IPReputation',
          sampledRequestsEnabled: true,
        },
        overrideAction: {
          none: {}
        },
      },
      {
        name: 'BadInputs',
        priority: 2,
        statement: {
          managedRuleGroupStatement: {
            name:'AWSManagedRulesKnownBadInputsRuleSet',
            vendorName:'AWS'
          }
        },
        visibilityConfig: {
          cloudWatchMetricsEnabled: true,
          metricName:'MetricForWebACLCDK-BadInputs',
          sampledRequestsEnabled: true,
        },
        overrideAction: {
          none: {}
        },
      },
    ],
    });

    const waclLoggingConfiguration = new waf.CfnLoggingConfiguration(this, 'wacl-logging-configuration', {
      logDestinationConfigs: [`${waflogLandingBucket.bucketArn}`],
      resourceArn: chargeBackWACL.attrArn,
    });
    waclLoggingConfiguration.node.addDependency(chargeBackWACL);

    // Cloudfront distribution with multiple origins
    const chargeBackdistribution = new cloudfront.Distribution(this, 'chargeback-distribution', {
        comment: 'Chargeback CloudFront distribution',
        defaultRootObject: 'index.html',
        webAclId: chargeBackWACL.attrArn,
        defaultBehavior: {
          origin: spaOrigin,
          allowedMethods: cloudfront.AllowedMethods.ALLOW_ALL,
          viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
        },
        additionalBehaviors: {
          '/EdgeLambda.html': {
            origin: spaOrigin,
            allowedMethods: cloudfront.AllowedMethods.ALLOW_ALL,
            viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
            edgeLambdas: [
              {
                functionVersion: lambdaEdgeFunction.currentVersion,
                eventType: cloudfront.LambdaEdgeEventType.VIEWER_REQUEST,
              },
              {
                functionVersion: lambdaEdgeFunction.currentVersion,
                eventType: cloudfront.LambdaEdgeEventType.ORIGIN_RESPONSE,
              },
            ]
          },
        },
        logBucket: logLandingBucket,
        logFilePrefix: 'cloudfront-access-logs',
      }
    );
    
    // Lambda for serving dynamic API content
    const chargeBackLambda = new lambda.Function(this, 'chargeback-regional-lambda', {
      functionName: 'chargeBackLambda',
      code: lambda.Code.fromAsset(path.join('src/', 'api-gateway')),
      handler: 'businessone.handler',
      runtime: lambda.Runtime.NODEJS_LATEST,
      timeout: Duration.seconds(10),
    });

    // API Gateway for dynamic content endpoint 
    const chargeBackAPI = new apigateway.LambdaRestApi(this, 'chargeback-rest-api', {
      restApiName: 'ChargeBackAPI',
      handler: chargeBackLambda,
      deployOptions: {
        stageName: 'stage',
      },
      endpointTypes: [apigateway.EndpointType.REGIONAL],
    });

    // Adding API Gateway endpoint to the CloudFront behaviors and only allowing
    // traffic from the distribution
    chargeBackdistribution.addBehavior('/api/*', new origins.RestApiOrigin(chargeBackAPI), {
      cachePolicy: cloudfront.CachePolicy.CACHING_DISABLED,
      allowedMethods: cloudfront.AllowedMethods.ALLOW_ALL,
      viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
    });
    
    // Deploying SPAs
    new s3deploy.BucketDeployment(this, 'deploy-webpage', {
      sources: [s3deploy.Source.asset('./webpages')],
      destinationBucket: spaBucket,
      distribution: chargeBackdistribution,
      distributionPaths: ['/*'],
    });

    // Adding CloudFront Function and behavior to the distribution
    const chargeBackCloudFrontFunction = new cloudfront.Function(this, 'chargeback-cloudfront-function', {
      runtime: cloudfront.FunctionRuntime.JS_2_0,
      code: cloudfront.FunctionCode.fromInline(" \
      function handler(event) { \
        const request = event.request; \
        const headers = request.headers; \
        const host = request.headers.host.value; \
        return { \
            statusCode: 302, \
            statusDescription: 'Found', \
            headers: { \
                'cloudfront-functions': { value: 'generated-by-CloudFront-Functions' }, \
                'location': { value: '/secondBusiness.html' } \
            } \
        }; \
    }" 
    )});

    chargeBackdistribution.addBehavior('/EdgeFunc.html', spaOrigin, {
      allowedMethods: cloudfront.AllowedMethods.ALLOW_ALL,
      viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
      functionAssociations: [{
        function: chargeBackCloudFrontFunction,
        eventType: cloudfront.FunctionEventType.VIEWER_REQUEST,
      }]
    });

    // Creating Glue Database
    const glueDatabase = new glue_alpha.Database(this, 'chargeback-glue-database', {
      databaseName: 'chargeback_database',
    });

    // Create an IAM policy statement to allow Athena to access the S3 bucket
    const athenaAccessPolicy = new iam.PolicyStatement({
      effect: iam.Effect.ALLOW,
      actions: ['s3:GetObject', 's3:ListBucket'],
      resources: [
        logLandingBucket.bucketArn,
        `${logLandingBucket.bucketArn}/*`,
      ],
      principals: [new iam.ServicePrincipal('athena.amazonaws.com')],
    });
    logLandingBucket.addToResourcePolicy(athenaAccessPolicy);

    // CF Standard Log table
    // https://docs.aws.amazon.com/athena/latest/ug/cloudfront-logs.html#create-cloudfront-table-standard-logs
    const cloudfrontLogsGlueTable = new glue.CfnTable(this, 'cloudfront-logs-glue-table', {
      catalogId: Stack.of(this).account, // Replace with your AWS Account ID if necessary
      databaseName: glueDatabase.databaseName,
      tableInput: {
        name: 'cf-logs-table',
        description: 'CloudFront Log Table',
        tableType: 'EXTERNAL_TABLE',
        parameters: {
          'skip.header.line.count': '2',
          // 'separatorChar': '\t',
        },
        storageDescriptor: {
          columns: [
            { name: 'date', type: 'date' },
            { name: 'time', type: 'string' },
            { name: 'x_edge_location', type: 'string' },
            { name: 'sc_bytes', type: 'bigint' },
            { name: 'c_ip', type: 'string' },
            { name: 'cs_method', type: 'string' },
            { name: 'cs_host', type: 'string' },
            { name: 'cs_uri_stem', type: 'string' },
            { name: 'sc_status', type: 'int' },
            { name: 'cs_referrer', type: 'string' },
            { name: 'cs_user_agent', type: 'string' },    
            { name: 'cs_uri_query', type: 'string' },    
            { name: 'cs_cookie', type: 'string' },    
            { name: 'x_edge_result_type', type: 'string' },    
            { name: 'x_edge_request_id', type: 'string' },    
            { name: 'x_host_header', type: 'string' },    
            { name: 'cs_protocol', type: 'string' },    
            { name: 'cs_bytes', type: 'bigint' },    
            { name: 'time_taken', type: 'float' },    
            { name: 'x_forwarded_for', type: 'string' },    
            { name: 'ssl_protocol', type: 'string' },    
            { name: 'ssl_cipher', type: 'string' },    
            { name: 'x_edge_response_result_type', type: 'string' },    
            { name: 'cs_protocol_version', type: 'string' },    
            { name: 'fle_status', type: 'string' },    
            { name: 'fle_encrypted_fields', type: 'int' },    
            { name: 'c_port', type: 'int' },    
            { name: 'time_to_first_byte', type: 'float' },    
            { name: 'x_edge_detailed_result_type', type: 'string' },    
            { name: 'sc_content_type', type: 'string' },    
            { name: 'sc_content_len', type: 'bigint' },    
            { name: 'sc_range_start', type: 'bigint' },    
            { name: 'sc_range_end', type: 'bigint' },    
          ],
          location: `s3://${logLandingBucket.bucketName}/cloudfront-access-logs`,      
          inputFormat: 'org.apache.hadoop.mapred.TextInputFormat',
          outputFormat: 'org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat',
          serdeInfo: {
            serializationLibrary: 'org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe',
            parameters: {
              'serialization.format' : '\t',
              'field.delim': '\t'
            }
          },
        },
      },
    });

    // WAF Log table
    // https://docs.aws.amazon.com/athena/latest/ug/waf-logs.html
    // Cost optimization and Query optimization calls for better partitioning
    const wafLogsGlueTable = new glue.CfnTable(this, 'waf-logs-glue-table', {
      catalogId: Stack.of(this).account, // Replace with your AWS Account ID if necessary    
      databaseName: glueDatabase.databaseName,    
      tableInput: {    
        name: 'waf-log-table',    
        description: 'WAF Log Table',    
        tableType: 'EXTERNAL_TABLE',    
        parameters: {},    
        storageDescriptor: {    
          columns: [    
            { name: 'timestamp', type: 'bigint' },    
            { name: 'formatversion', type: 'int' },    
            { name: 'webaclid', type: 'string' },    
            { name: 'terminatingruleid', type: 'string' },    
            { name: 'terminatingruletype', type: 'string' },    
            { name: 'action', type: 'string' },    
            {    
              name: 'terminatingrulematchdetails',    
              type: 'array<struct<conditiontype:string,sensitivitylevel:string,location:string,matcheddata:array<string>>>',    
            },    
            { name: 'httpsourcename', type: 'string' },    
            { name: 'httpsourceid', type: 'string' },    
            {    
              name: 'rulegrouplist',    
              type: 'array<struct<rulegroupid:string,terminatingrule:struct<ruleid:string,action:string,rulematchdetails:array<struct<conditiontype:string,sensitivitylevel:string,location:string,matcheddata:array<string>>>>,nonterminatingmatchingrules:array<struct<ruleid:string,action:string,overriddenaction:string,rulematchdetails:array<struct<conditiontype:string,sensitivitylevel:string,location:string,matcheddata:array<string>>>,challengeresponse:struct<responsecode:string,solvetimestamp:string>,captcharesponse:struct<responsecode:string,solvetimestamp:string>>>,excludedrules:string>>',    
            },    
            {    
              name: 'ratebasedrulelist',    
              type: 'array<struct<ratebasedruleid:string,limitkey:string,maxrateallowed:int>>',    
            },    
            {    
              name: 'nonterminatingmatchingrules',    
              type: 'array<struct<ruleid:string,action:string,rulematchdetails:array<struct<conditiontype:string,sensitivitylevel:string,location:string,matcheddata:array<string>>>,challengeresponse:struct<responsecode:string,solvetimestamp:string>,captcharesponse:struct<responsecode:string,solvetimestamp:string>>>',    
            },    
            {    
              name: 'requestheadersinserted',    
              type: 'array<struct<name:string,value:string>>',    
            },    
            { name: 'responsecodesent', type: 'string' },    
            {    
              name: 'httprequest',    
              type: 'struct<clientip:string,country:string,headers:array<struct<name:string,value:string>>,uri:string,args:string,httpversion:string,httpmethod:string,requestid:string>',    
            },    
            { name: 'labels', type: 'array<struct<name:string>>' },    
            {    
              name: 'captcharesponse',    
              type: 'struct<responsecode:string,solvetimestamp:string,failureReason:string>',    
            },    
            {    
              name: 'challengeresponse',    
              type: 'struct<responsecode:string,solvetimestamp:string,failureReason:string>',    
            },    
            { name: 'ja3Fingerprint', type: 'string' },    
          ],    
          location: `s3://${waflogLandingBucket.bucketName}/AWSLogs/`,    
          inputFormat: 'org.apache.hadoop.mapred.TextInputFormat',    
          outputFormat: 'org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat',    
          serdeInfo: {    
            serializationLibrary: 'org.openx.data.jsonserde.JsonSerDe',
            parameters: {
              'serialization.format' : '1'
            }   
          },    
        },    
      },    
    });

    // Pricing fact tables — replace the chargeback query's inline CASE/hardcoded pricing with two
    // version-able Glue EXTERNAL tables it JOINs against (edge-prefix->region, and per-region
    // prices). Re-price/add an edge = CSV edit + `cdk deploy`, no query rewrite. Backing CSVs ship
    // from pricing-data/ to s3://<logLandingBucket>/pricing/ (see deploy-pricing-data below); read
    // with LazySimpleSerDe (field.delim ',') + skip.header.line.count '1'.

    const pricingPrefix = 'pricing';

    // IATA edge-location prefix -> region_key mapping. One row per prefix in the old CASE map.
    const edgeLocationRegionTable = new glue.CfnTable(this, 'edge-location-region-glue-table', {
      catalogId: Stack.of(this).account,
      databaseName: glueDatabase.databaseName,
      tableInput: {
        name: 'cf_edge_location_region',
        description: 'Maps CloudFront edge IATA prefix (SUBSTRING(x_edge_location,1,3)) to a pricing region_key',
        tableType: 'EXTERNAL_TABLE',
        parameters: {
          'EXTERNAL': 'TRUE',
          'skip.header.line.count': '1',
        },
        storageDescriptor: {
          columns: [
            { name: 'iata_prefix', type: 'string' },
            { name: 'region_key', type: 'string' },
          ],
          location: `s3://${logLandingBucket.bucketName}/${pricingPrefix}/edge-location-region/`,
          inputFormat: 'org.apache.hadoop.mapred.TextInputFormat',
          outputFormat: 'org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat',
          serdeInfo: {
            serializationLibrary: 'org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe',
            parameters: {
              'field.delim': ',',
              'serialization.format': ',',
              'skip.header.line.count': '1',
            },
          },
        },
      },
    });

    // Per-region price facts. One row per pricing region plus a 'default' fallback row.
    const regionPricingTable = new glue.CfnTable(this, 'region-pricing-glue-table', {
      catalogId: Stack.of(this).account,
      databaseName: glueDatabase.databaseName,
      tableInput: {
        name: 'cf_region_pricing',
        description: 'Per-region CloudFront price facts (DTO $/GB, request $/10k) — version-able pricing data',
        tableType: 'EXTERNAL_TABLE',
        parameters: {
          'EXTERNAL': 'TRUE',
          'skip.header.line.count': '1',
        },
        storageDescriptor: {
          columns: [
            { name: 'region_key', type: 'string' },
            { name: 'region_name', type: 'string' },
            { name: 'dto_price_per_gb', type: 'double' },
            { name: 'request_price_per_10k', type: 'double' },
            { name: 'tier', type: 'string' }, // 'first' today; future tiered pricing is a data add
          ],
          location: `s3://${logLandingBucket.bucketName}/${pricingPrefix}/region-pricing/`,
          inputFormat: 'org.apache.hadoop.mapred.TextInputFormat',
          outputFormat: 'org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat',
          serdeInfo: {
            serializationLibrary: 'org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe',
            parameters: {
              'field.delim': ',',
              'serialization.format': ',',
              'skip.header.line.count': '1',
            },
          },
        },
      },
    });

    // Deploy the pricing CSVs to s3://<logLandingBucket>/pricing/. The repo dir `pricing-data/`
    // mirrors the S3 layout — each CSV under its own per-table subdir — and BucketDeployment
    // preserves that tree, so each Glue table's `location` points at a dir holding exactly one
    // CSV. prune:false so the CloudFront logs already in this bucket are never deleted.
    new s3deploy.BucketDeployment(this, 'deploy-pricing-data', {
      sources: [s3deploy.Source.asset(path.join(__dirname, '../pricing-data'))],
      destinationBucket: logLandingBucket,
      destinationKeyPrefix: pricingPrefix,
      prune: false,
    });

    // cdk-nag suppressions — demo/sample stack. Findings are pre-existing sample characteristics
    // or framework-generated (BucketDeployment handler); each waiver is resource-scoped with a
    // justification below.
    const s1 = {
      id: 'AwsSolutions-S1',
      reason: 'Demo/sample stack; the CloudFront-logs and WAF-logs buckets are themselves log sinks and the SPA bucket serves static demo content — S3 server-access logging is out of scope for the sample and would add a recursive log bucket.',
    };
    suppress(logLandingBucket, [s1]);
    suppress(waflogLandingBucket, [s1]);
    suppress(spaBucket, [s1]);

    suppress(chargeBackdistribution, [
      {
        id: 'AwsSolutions-CFR7',
        reason: 'Demo stack intentionally uses the legacy S3 OriginAccessIdentity pattern; migration to Origin Access Control is out of scope for this change and does not affect chargeback logging.',
      },
      {
        id: 'AwsSolutions-CFR4',
        reason: 'Distribution uses the default *.cloudfront.net certificate, which forces the TLSv1 security policy and ignores minimumProtocolVersion; enforcing TLS 1.2 requires a custom domain + ACM certificate, which is out of scope for this demo stack.',
      },
      {
        id: 'AwsSolutions-CFR1',
        reason: 'Demo chargeback distribution is intentionally globally reachable to exercise multi-region edge traffic; geo restrictions would defeat the purpose of the sample and are a per-deployment policy choice for the adopter.',
      },
    ]);

    const iam4BasicExec = {
      id: 'AwsSolutions-IAM4',
      reason: 'AWS-managed AWSLambdaBasicExecutionRole grants only CloudWatch Logs write, which is the least privilege needed for the function to log; it is the CDK default for Lambda execution roles.',
      appliesTo: ['Policy::arn:<AWS::Partition>:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole'],
    };
    suppress(chargeBackLambda, [iam4BasicExec], true);
    suppress(lambdaEdgeFunction, [iam4BasicExec], true);

    suppress(
      chargeBackAPI,
      [
        { id: 'AwsSolutions-APIG1', reason: 'Demo REST API serving sample dynamic content behind CloudFront; stage access logging is out of scope for this sample stack.' },
        { id: 'AwsSolutions-APIG2', reason: 'Demo REST API with a proxy integration to a sample Lambda; request validation is out of scope for this sample stack.' },
        { id: 'AwsSolutions-APIG4', reason: 'Demo REST API endpoint intentionally left unauthenticated to serve public sample content behind CloudFront; auth is out of scope for this sample.' },
        { id: 'AwsSolutions-APIG6', reason: 'Demo REST API serving sample content; per-method CloudWatch execution logging is out of scope for this sample stack.' },
        { id: 'AwsSolutions-COG4', reason: 'Demo REST API endpoint intentionally has no Cognito user pool authorizer; it serves public sample content behind CloudFront.' },
        { id: 'AwsSolutions-APIG3', reason: 'The demo distribution is protected by an AWS WAF WebACL at the CloudFront edge; a separate WAFv2 association on the regional API Gateway stage is redundant for this sample and out of scope.' },
      ],
      true, // findings land on stage + method child resources
    );

    // Framework-generated BucketDeployment copy handler. Path uses this.node.id (not a hardcoded
    // stack name) so it resolves under any stack id, e.g. the jest test's 'MyTestStack'.
    const bucketDeploymentPath =
      `/${this.node.id}/Custom::CDKBucketDeployment8693BB64968944B69AAFB0CC9EB8756C`;
    suppressByPath(this, `${bucketDeploymentPath}/Resource`, [
      {
        id: 'AwsSolutions-L1',
        reason: 'CDK-synthesized BucketDeployment asset-copy Lambda; its runtime is pinned by the aws-cdk-lib version and is not selectable by this application, so the latest-runtime rule is not actionable here.',
      },
    ]);
    suppressByPath(this, `${bucketDeploymentPath}/ServiceRole/Resource`, [
      {
        id: 'AwsSolutions-IAM4',
        reason: 'CDK-synthesized BucketDeployment copy handler role; the AWS-managed AWSLambdaBasicExecutionRole is attached by the framework and grants only CloudWatch Logs write — not under application control.',
        appliesTo: ['Policy::arn:<AWS::Partition>:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole'],
      },
    ]);
    suppressByPath(this, `${bucketDeploymentPath}/ServiceRole/DefaultPolicy/Resource`, [
      {
        id: 'AwsSolutions-IAM5',
        reason: 'CDK-synthesized BucketDeployment copy handler; its wildcard S3 read/list/write actions, the CDK asset bucket + destination bucket resource wildcards, and the CloudFront invalidation permission are generated by the framework to sync assets and invalidate the distribution — not under application control.',
      },
    ]);

    new CfnOutput(this, 'cloudFrontUrl', {
      value: chargeBackdistribution.distributionDomainName
    });

}};


