provider "aws" {
  access_key                  = "test"
  secret_key                  = "test"
  region                      = "us-east-1"
  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    s3             = "http://127.0.0.1:4566"
    lambda         = "http://127.0.0.1:4566"
    iam            = "http://127.0.0.1:4566"
    cloudwatchlogs = "http://127.0.0.1:4566"
  }
}

resource "aws_s3_bucket" "s3_start" {
  bucket = "s3-start-bucket"
}

resource "aws_s3_bucket" "s3_finish" {
  bucket = "s3-finish-bucket"
}

resource "aws_s3_bucket_lifecycle_configuration" "finish_bucket_lifecycle" {
  bucket = aws_s3_bucket.s3_finish.id

  rule {
    id     = "delete-old-files"
    status = "Enabled"

    expiration {
      days = 7
    }
  }
}


data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "lambda_function.py"
  output_path = "lambda_function.zip"
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda-s3-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda-s3-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Effect   = "Allow"
        Resource = [
          "${aws_s3_bucket.s3_start.arn}/*",
          "${aws_s3_bucket.s3_finish.arn}/*"
        ]
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_lambda_function" "copy_file_lambda" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "copy-s3-file"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.9"

  environment {
    variables = {
      TARGET_BUCKET = aws_s3_bucket.s3_finish.bucket
    }
  }
}


resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.copy_file_lambda.function_name}"
  retention_in_days = 7
}


resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.copy_file_lambda.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.s3_start.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.s3_start.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.copy_file_lambda.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3]
}