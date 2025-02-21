resource "aws_cloudwatch_log_group" "waf_log_group" {
  provider = aws.virginia
  retention_in_days = 1
  name = "aws-waf-logs-cloudfront"
}
