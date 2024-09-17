import * as cdk from 'aws-cdk-lib';
import { Template } from 'aws-cdk-lib/assertions';
import { CloudfrontChargeBackLoggingStack } from '../lib/cloudfront-charge-back-logging-stack';

test('S3 Created', () => {
  const app = new cdk.App();
    // WHEN
  const stack = new CloudfrontChargeBackLoggingStack(app, 'MyTestStack', {
    env: {
      region: 'us-east-1'
    }
  });
  
    // THEN
  const template = Template.fromStack(stack);
  template.resourceCountIs('AWS::S3::Bucket', 3);
  template.resourceCountIs('AWS::CloudFront::Distribution', 1);
});
