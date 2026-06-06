resource "aws_dynamodb_table" "subscribers" {
  name         = "${var.name_prefix}-subscribers"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "email"

  attribute {
    name = "email"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }
}

resource "aws_dynamodb_table" "newsletters" {
  name         = "${var.name_prefix}-newsletters"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  attribute {
    name = "generatedAt"
    type = "S"
  }

  global_secondary_index {
    name            = "byStatus"
    hash_key        = "status"
    range_key       = "generatedAt"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }
}

resource "aws_s3_bucket" "template" {
  bucket        = "${var.name_prefix}-templates"
  force_destroy = false

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  lifecycle_rule {
    enabled = true
    noncurrent_version_expiration {
      days = 30
    }
  }
}

resource "aws_s3_bucket" "html" {
  bucket        = "${var.name_prefix}-rendered-html"
  force_destroy = true

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  lifecycle_rule {
    enabled = true
    expiration {
      days = 90
    }
  }
}
