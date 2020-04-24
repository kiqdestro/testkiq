data "aws_caller_identity" "current" {}

// CODEPIPELINE

resource "aws_iam_role" "codepipeline_role" {
  name = "AWSCodePipelineServiceRole-${var.region}-${var.app_name}"
  assume_role_policy = file("${path.module}/assets/codepipeline_role.json")
}

data "template_file" "codepipeline_policy_template" {
  template = file("${path.module}/assets/codepipeline_policy.json")
  vars = {
    bucket_arn = aws_s3_bucket.bucket.arn
  }
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "${var.app_name}_codepípeline_policy"
  policy = data.template_file.codepipeline_policy_template.rendered
  role = aws_iam_role.codepipeline_role.id
}

// CODEBUILD

resource "aws_iam_role" "codebuild_role" {
  name = "AWSBuildServiceRole-${var.region}-${var.app_name}"
  assume_role_policy = file("${path.module}/assets/codebuild_role.json")
}

data "template_file" "codebuild_policy_template" {
  template = file("${path.module}/assets/codebuild_policy.json")
  vars = {
    bucket_arn = aws_s3_bucket.bucket.arn
  }
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name = "${var.app_name}_codebuild_policy"
  policy = data.template_file.codebuild_policy_template.rendered
  role = aws_iam_role.codebuild_role.id
}

resource "aws_codebuild_project" "codebuild" {
  name = var.app_name
  service_role = aws_iam_role.codebuild_role.arn
  artifacts {
    type = "CODEPIPELINE"
  }
  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image = "aws/codebuild/amazonlinux2-x86_64-standard:2.0"
    type = "LINUX_CONTAINER"
    privileged_mode = false
    environment_variable {
      name = "ENVIRONMENT"
      value = var.environment_name
    }
  }
  source {
    type = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }
}

// CODEDEPLOY

//resource "aws_iam_role" "codedeploy_role" {
//  assume_role_policy = file("${path.module}/assets/codedeploy_policy.json")
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
      configuration {
        Owner = "kiqkelevra"
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
      configuration {
        BucketName = aws_s3_bucket.bucket.id
        Extract = "true"
      }

    }
  }
}