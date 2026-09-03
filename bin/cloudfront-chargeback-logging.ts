#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { Aspects } from 'aws-cdk-lib';
import { AwsSolutionsChecks } from 'cdk-nag';
import { CloudfrontChargeBackLoggingStack } from '../lib/cloudfront-chargeback-logging-stack';

const app = new cdk.App();

const cloudfrontChargeBackLoggingStack = new CloudfrontChargeBackLoggingStack(app,
  'CloudfrontChargeBackLoggingStack', {
    env: { region: 'us-east-1' },
});

// cdk-nag: security violations FAIL synth (shift-left, mandatory default).
Aspects.of(app).add(new AwsSolutionsChecks());
