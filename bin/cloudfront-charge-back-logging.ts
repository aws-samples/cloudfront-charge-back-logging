#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { CloudfrontChargeBackLoggingStack } from '../lib/cloudfront-charge-back-logging-stack';

const app = new cdk.App();

const cloudfrontChargeBackLoggingStack = new CloudfrontChargeBackLoggingStack(app, 
  'CloudfrontChargeBackLoggingStack', {
    env: { region: 'us-east-1' },
});
