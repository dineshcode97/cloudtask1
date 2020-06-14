//Creating A S3 Bucket
resource "aws_s3_bucket" "dbucket97" {
  bucket = "dbucket97"
  acl    = "public-read"
  region = "ap-south-1"

  tags = {
    Name = "dbucket97"
    Environment = "Deploy"
  }
}


//Setting Origin Id For S3
locals {
  s3_origin_id = "myS3Origin"
}


//Block - Unblock public access
resource "aws_s3_bucket_public_access_block" "dbucket97_public" {
    bucket = "dbucket97"
    block_public_acls = false
    block_public_policy = false
}


//Creating Origin Access Identity
resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "Some comment"
}


//Creating Cloud Distribution and Connecting It To S3
resource "aws_cloudfront_distribution" "s3tocf" {
	origin {
		domain_name = "dbucket97.s3.ap-south-1.amazonaws.com"
		origin_id = "${local.s3_origin_id}"
	
		s3_origin_config {
		    origin_access_identity = "${aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path}"
		    }
	}
   	    
	enabled = true
	is_ipv6_enabled = true	

	default_cache_behavior {
        allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
        cached_methods = ["GET", "HEAD"]
        target_origin_id = "${local.s3_origin_id}"

        forwarded_values {
            query_string = false
        
            cookies {
               forward = "none"
            }
        }
        viewer_protocol_policy = "allow-all"
        min_ttl = 0
        default_ttl = 3600
        max_ttl = 86400
    }
 
    restrictions {
        geo_restriction {
	     restriction_type = "none"
	    //  locations = ["IN"]
        }
    }

    viewer_certificate {
        cloudfront_default_certificate = true

    }
}


//Creatring An IAM Policy Document
data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.dbucket97.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn}"]
    }
  }
}

resource "aws_s3_bucket_policy" "example" {
// depends_on =[aws_cloudfront_distribution.s3tocf] 

	bucket = aws_s3_bucket.dbucket97.id
	policy = data.aws_iam_policy_document.s3_policy.json
}