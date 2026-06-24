import * as cdk from 'aws-cdk-lib';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as sqs from 'aws-cdk-lib/aws-sqs';

const app = new cdk.App();

// VPC
const vpc = new ec2.Vpc(app, 'MyVpc', {
  cidr: '10.0.0.0/16',
  maxAzs: 2,
  subnetConfiguration: [
    {
      cidrMask: 24,
      name: 'Public',
      subnetType: ec2.SubnetType.PUBLIC,
    },
    {
      cidrMask: 24,
      name: 'Private',
      subnetType: ec2.SubnetType.PRIVATE,
    },
  ],
});

// Security Group
const securityGroup = new ec2.SecurityGroup(app, 'MySecurityGroup', {
  vpc,
  allowAllOutbound: true,
});

// IAM Role
const role = new iam.Role(app, 'MyRole', {
  assumedBy: new iam.ServicePrincipal('lambda.amazonaws.com'),
});

// S3 Bucket
const bucket = new s3.Bucket(app, 'MyBucket', {
  bucketName: 'my-bucket',
});

// SQS Queue
const queue = new sqs.Queue(app, 'MyQueue', {
  queueName: 'my-queue',
});

// Lambda Function
const lambdaFunction = new lambda.Function(app, 'MyLambdaFunction', {
  runtime: lambda.Runtime.NODEJS_14_X,
  code: lambda.Code.fromAsset('./lambda'),
  handler: 'index.handler',
  role,
  vpc,
  securityGroups: [securityGroup],
  environment: {
    BUCKET_NAME: bucket.bucketName,
    QUEUE_URL: queue.queueUrl,
  },
});