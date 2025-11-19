locals {
  bucket_force_destroy = false
  final_bucket_name = lower(join("-", compact([
    var.project_name,
    replace(var.region, "_", "-"),
    "terraform-state"
  ])))
  final_dynamodb_table = lower(join("-", compact([
    var.project_name,
    replace(var.region, "_", "-"),
    var.dynamodb_table_name
  ])))
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "tf_state" {
  bucket        = local.final_bucket_name
  force_destroy = local.bucket_force_destroy
}

# Enable ACLs for CloudFront logging
resource "aws_s3_bucket_ownership_controls" "tf_state_ownership" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "tf_state_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.tf_state_ownership]
  bucket     = aws_s3_bucket.tf_state.id
  acl        = "private"
}

resource "aws_s3_bucket_versioning" "tf_state_versioning" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state_sse" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Allow CloudFront to write logs to this bucket
resource "aws_s3_bucket_policy" "tf_state_cloudfront_logs" {
  bucket = aws_s3_bucket.tf_state.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid    = "AllowCloudFrontServicePrincipalReadWrite"
          Effect = "Allow"
          Principal = {
            Service = "cloudfront.amazonaws.com"
          }
          Action = [
            "s3:GetBucketAcl",
            "s3:PutBucketAcl",
            "s3:PutObject",
            "s3:PutObjectAcl"
          ]
          Resource = [
            aws_s3_bucket.tf_state.arn,
            "${aws_s3_bucket.tf_state.arn}/*"
          ]
        }
      ],
      var.cloudfront_distribution_arn != null ? [
        {
          Sid    = "AllowCloudFrontAccess"
          Effect = "Allow"
          Principal = {
            Service = "cloudfront.amazonaws.com"
          }
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:ListBucket"
          ]
          Resource = [
            aws_s3_bucket.tf_state.arn,
            "${aws_s3_bucket.tf_state.arn}/*"
          ]
          Condition = {
            StringEquals = {
              "AWS:SourceArn" = var.cloudfront_distribution_arn
            }
          }
        }
      ] : []
    )
  })
}

resource "aws_dynamodb_table" "tf_locks" {
  name         = local.final_dynamodb_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

output "backend_bucket" { value = aws_s3_bucket.tf_state.bucket }
output "backend_dynamodb_table" { value = aws_dynamodb_table.tf_locks.name }


