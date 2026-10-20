# ---------- Synthetic ticket storage ----------

resource "aws_s3_bucket" "tickets" {
  bucket_prefix = "ticket-demo-"

  # Allows teardown to delete the bucket and its synthetic tickets.
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "tickets" {
  bucket = aws_s3_bucket.tickets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tickets" {
  bucket = aws_s3_bucket.tickets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "tickets" {
  bucket = aws_s3_bucket.tickets.id

  rule {
    id     = "expire-demo-tickets"
    status = "Enabled"

    filter {
      prefix = "tickets/"
    }

    expiration {
      days = var.ticket_ttl_days
    }
  }
}

# ---------- Docker image registry ----------

resource "aws_ecr_repository" "api" {
  name                 = "ticket-demo-api"
  image_tag_mutability = "IMMUTABLE"

  # Allows teardown to delete the repository and its images.
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "api" {
  repository = aws_ecr_repository.api.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the last 5 images"

      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }

      action = {
        type = "expire"
      }
    }]
  })
}