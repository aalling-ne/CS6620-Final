terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
  }
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "dummy"
  secret_key                  = "dummy"
  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  endpoints {
    s3       = "http://localhost:4566"
    iam      = "http://localhost:4566"
    lambda   = "http://localhost:4566"
    logs     = "http://localhost:4566"
    events   = "http://localhost:4566"
  }
}


# -------------- IAM ROLES AND POLICIES --------------------------------------------
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy_attachment

# IAM role
resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for the role
resource "aws_iam_policy" "lambda_policy" {
  name = "lambda_s3_logs_policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          aws_s3_bucket.website.arn,
          "${aws_s3_bucket.website.arn}/*"
        ]
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}


# ------------ AWS RESOURCES - S3 ---------------------------------------

# S3
resource "aws_s3_bucket" "website" {
  bucket = "vacant-properties-web"
}

# direct website bucket for static file hosting
resource "aws_s3_bucket_website_configuration" "website_cfg" {
  bucket = aws_s3_bucket.website.id
  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "index.html"
  }
}

# make the s3 bucket public so it works as a web host
resource "aws_s3_bucket_policy" "public_read" {
  bucket = aws_s3_bucket.website.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.website.arn}/*"
      }
    ]
  })
}

# --UPLOAD Files to S3 Bucket
locals {
  web_dir   = "${path.module}/../web"
  site_files = fileset(local.web_dir, "**")

  mime_types = {
    html = "text/html"
    css  = "text/css"
    js   = "application/javascript"
    json = "application/json"
    png  = "image/png"
    jpg  = "image/jpeg"
    jpeg = "image/jpeg"
    svg  = "image/svg+xml"
    txt  = "text/plain"
    ico  = "image/x-icon"
    map  = "application/json"
  }
}

# --UPLOAD Files to S3 Bucket
resource "aws_s3_object" "site_files" {
  for_each = { for f in local.site_files : f => f }

  bucket       = aws_s3_bucket.website.bucket
  key          = each.value
  source       = "${local.web_dir}/${each.value}"
  etag         = filemd5("${local.web_dir}/${each.value}")
  acl          = "public-read"

  content_type = lookup(
    local.mime_types,
    lower(element(reverse(split(".", each.value)), 0)),
    "application/octet-stream"
  )
}


# Set up Lambda
resource "aws_lambda_function" "etl_lambda" {
  function_name = "etl-function"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "etl_script.lambda_handler"
  runtime       = "python3.9"
  filename      = "${path.module}/etl_package.zip"
  source_code_hash = filebase64sha256("${path.module}/etl_package.zip")

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.website.bucket
    }
  }

  depends_on = [aws_iam_role_policy_attachment.lambda_policy_attach]

}

# Cloudwatch Event (1/day)
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule

resource "aws_cloudwatch_event_rule" "daily" {
  name                = "daily-etl"
  schedule_expression = "rate(1 day)"
}

resource "aws_lambda_permission" "allow_event" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.etl_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily.arn
}

resource "aws_cloudwatch_event_target" "invoke_etl_lambda" {
  rule      = aws_cloudwatch_event_rule.daily.name
  target_id = "etlLambdaTarget"
  arn       = aws_lambda_function.etl_lambda.arn
}

# Localstack Website URL
#http://vacant-properties-web.s3-website.localhost.localstack.cloud:4566