resource "aws_wafv2_web_acl" "this" {
  provider    = aws.virginia
  name        = "test-waf-acls"
  description = "test waf acls custom rules"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule_json = file("${path.module}/waf_rule.json")

  visibility_config {
    cloudwatch_metrics_enabled = false
    metric_name                = "test-waf-acls-metric"
    sampled_requests_enabled   = false
  }
}

resource "aws_wafv2_web_acl_logging_configuration" "this" {
  provider = aws.virginia
  log_destination_configs = [aws_cloudwatch_log_group.waf_log_group.arn]
  resource_arn = aws_wafv2_web_acl.this.arn

  redacted_fields {
    single_header {
      name = "authorization"
    }
  }

  redacted_fields {
    single_header {
      name = "cookie"
    }
  }

  logging_filter {
    default_behavior = "DROP"

    filter {
      behavior = "KEEP"

      condition {
        action_condition {
          action = "COUNT"
        }
      }
      condition {
        action_condition {
          action = "BLOCK"
        }
      }

      requirement = "MEETS_ANY"
    }
  }
}
