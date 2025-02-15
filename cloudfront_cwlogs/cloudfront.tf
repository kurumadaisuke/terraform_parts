resource "aws_s3_bucket" "cloudfront_origin_bucket" {
  bucket = "cloudfront-origin-bucket-cloudwatchlogs-test"
}

resource "aws_s3_bucket_public_access_block" "cloudfront_origin_bucket" {
  bucket = aws_s3_bucket.cloudfront_origin_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_control" "default" {
  name                              = "s3-oac"
  description                       = "OAC for S3"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.cloudfront_origin_bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.default.id
    origin_id                = "s3-origin"
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3-origin"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_cloudwatch_log_group" "cloudfront_logs" {
  provider          = aws.virginia
  name              = "/aws/cloudfront/logs-content-cdn"
  retention_in_days = 90
}

data "aws_iam_policy_document" "cloudfront_logs_policy" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
    resources = [
      aws_cloudwatch_log_group.cloudfront_logs.arn,
    ]
  }
}

resource "aws_cloudwatch_log_delivery_source" "cloudfront_logs" {
  name         = "cloudfront-logs"
  log_type     = "ACCESS_LOGS"
  resource_arn = aws_cloudfront_distribution.s3_distribution.arn
}

resource "aws_cloudwatch_log_delivery_destination" "cloudwatch_logs" {
  provider      = aws.virginia
  name          = "cloudwatch-logs"
  output_format = "json"

  delivery_destination_configuration {
    destination_resource_arn = aws_cloudwatch_log_group.cloudfront_logs.arn
  }
}

resource "aws_cloudwatch_log_delivery" "cloudfront_logs" {
  provider                 = aws.virginia
  delivery_source_name     = aws_cloudwatch_log_delivery_source.cloudfront_logs.name
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.cloudwatch_logs.arn
}

resource "aws_cloudwatch_log_delivery_destination_policy" "cloudfront_logs" {
  provider                    = aws.virginia
  delivery_destination_name   = aws_cloudwatch_log_delivery_destination.cloudwatch_logs.name
  delivery_destination_policy = data.aws_iam_policy_document.cloudfront_logs_policy.json
}
