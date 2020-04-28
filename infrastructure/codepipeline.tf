data "aws_caller_identity" "current" {}

data "aws_s3_bucket" "artifact_bucket" {
  bucket = module.base.codepipeline_bucket
}

// CODEPIPELINE

resource "aws_iam_role" "codepipeline_role" {
  name = "AWSCodePipelineServiceRole-${var.region}-${var.app_name}"
  assume_role_policy = file("${path.module}/assets/codepipeline_role.json")
}

data "template_file" "codepipeline_policy_template" {
  template = file("${path.module}/assets/codepipeline_policy.json")
  vars = {
    artifact_bucket_arn = data.aws_s3_bucket.artifact_bucket.arn
    target_bucket_arn = aws_s3_bucket.bucket.arn
  }
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "${var.app_name}_codepipeline_policy"
  policy = data.template_file.codepipeline_policy_template.rendered
  role = aws_iam_role.codepipeline_role.id
}

// CODEDEPLOY

//resource "aws_iam_role" "codedeploy_role" {
//  assume_role_policy = file("${path.module}/assets/codedeploy_role.json")
//}
//
//data "template_file" "codedeploy_policy_template" {
//  template = file("${path.module}/assets/codedeploy_policy.json")
//  vars = {
//    target_bucket_arn = aws_s3_bucket.bucket.arn
//  }
//}
//
//resource "aws_iam_role_policy" "codedeploy_policy" {
//  nome = "${var.app_name}_codedeploy_policy"
//  policy = data.template_file.codedeploy_policy_template.rendered
//  role = aws_iam_role.codedeploy_role.id
//}

resource "aws_codepipeline" "pipeline" {
  name = var.app_name
  role_arn = aws_iam_role.codepipeline_role.arn
  artifact_store {
    location = module.base.codepipeline_bucket
    type = "S3"
  }
  stage {
    name = "Source"
    action {
      category = "Source"
      name = "Source"
      owner = "ThirdParty"
      provider = "GitHub"
      version = "1"
      output_artifacts = ["source_artifact"]
      configuration = {
        Owner = "kiqdestro"
        OAuthToken = var.github_token
        Repo = var.app_name
        Branch = "master"
      }
    }
  }
  stage {
    name = "Deploy"
    action {
      name = "Deploy"
      category = "Deploy"
      owner = "AWS"
      provider = "S3"
      version = "1"
      input_artifacts = ["source_artifact"]
      configuration = {
        BucketName = aws_s3_bucket.bucket.id
        Extract = "true"
      }

    }
  }
}