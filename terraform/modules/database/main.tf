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
    projection_type = "ALL"

    key_schema {
      attribute_name = "status"
      key_type       = "HASH"
    }

    key_schema {
      attribute_name = "generatedAt"
      key_type       = "RANGE"
    }
  }

  point_in_time_recovery {
    enabled = true
  }
}

resource "aws_s3_bucket" "template" {
  bucket        = "${var.name_prefix}-templates"
  force_destroy = false
}

resource "aws_s3_bucket_versioning" "template" {
  bucket = aws_s3_bucket.template.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "template" {
  bucket = aws_s3_bucket.template.id

  rule {
    id     = "expire-noncurrent"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "template" {
  bucket = aws_s3_bucket.template.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "template" {
  bucket = aws_s3_bucket.template.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "html" {
  bucket        = "${var.name_prefix}-rendered-html"
  force_destroy = true
}

resource "aws_s3_bucket_lifecycle_configuration" "html" {
  bucket = aws_s3_bucket.html.id

  rule {
    id     = "expire-old"
    status = "Enabled"

    expiration {
      days = 90
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "html" {
  bucket = aws_s3_bucket.html.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "html" {
  bucket = aws_s3_bucket.html.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
