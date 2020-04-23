provider "aws" {
  region = var.region
}

module "base" {
  source           = "app.terraform.io/MadeiraMadeira/base/aws"
  version          = "2.0.0"
  environment_name = var.environment_name
}

data "aws_route53_zone" "hosted" {
  zone_id = module.base.madeiramadeira_hosted_zone_id
}

resource "aws_s3_bucket" "bucket" {
  bucket = replace("${"" != var.commercial_name ? var.commercial_name : var.app_name}.${data.aws_route53_zone.hosted.name}", "/\\.$/", "")
  acl = "public-read"
//  hosted_zone_id = data.aws_route53_zone.hosted.id

  website {
    index_document = "index.html"
    error_document = "index.html"
  }
}

data "template_file" "s3_policy_template" {
  template = file("${path.module}/assets/bucket_policy.json")
  vars = {
    bucket_arn = aws_s3_bucket.bucket.arn
  }
}

resource "aws_s3_bucket_policy" "policy_attachment" {
  bucket = aws_s3_bucket.bucket.id
  policy = data.template_file.s3_policy_template.rendered
}

resource "aws_route53_record" "dns_record" {
  name = "" != var.commercial_name ? var.commercial_name : var.app_name
  type = "A"
  zone_id = data.aws_route53_zone.hosted.id
  alias {
    evaluate_target_health = true
    name = aws_s3_bucket.bucket.website_endpoint
    zone_id = aws_s3_bucket.bucket.hosted_zone_id
  }
}