resource "aws_lambda_function" "prod-elastic-monitoring-fetching-status-79b" {
  architectures = ["x86_64"]
  environment {
    variables = {
      ELASTIC_ENDPOINT = "vpc-prod-firefly-elasticsearch-xjxuxldct3z574ispvnxani76q.us-east-1.es.amazonaws.com"
      LOGZIO_TOKEN     = "REDACTED-BY-FIREFLY:fcff9c9283b383cf7682fe40f11d78af8621fcfe35ac802c99a388b24c5fd516:sha256"
      MONGODB_URI      = "mongodb+srv://readwrite:REDACTED-BY-FIREFLY:e7d22774cbd1547a842ccaf86b15d8dc013c31869a05354191fca0eb86fa6ece:sha256@prod.ie572.mongodb.net/infralight?retryWrites=true&w=majority"
      SLACK_WEBHOOK    = "https://hooks.slack.com/services/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"
    }
  }
  function_name    = "prod-elastic-monitoring-fetching-status"
  handler          = "elastic_monitoring/lambda.lambda_handler"
  role             = "arn:aws:iam::094724549126:role/prod-slack-notifier-role"
  runtime          = "python3.8"
  source_code_hash = "z2OJrF/fwdcQ7xg3vptHiDZU1d2gl60MOqL2W0bSEmE="
  timeout          = 30
  tracing_config {
    mode = "PassThrough"
  }
  vpc_config {
    security_group_ids = ["sg-00a112267a1ae4e2f"]
    subnet_ids         = ["subnet-0b2af0250937214fd", "subnet-0b3a2adba9cd5f6f3"]
  }
}

