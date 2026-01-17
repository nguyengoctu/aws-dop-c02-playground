# --- S3 Bucket for Artifacts ---
resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket_prefix = "${var.project_name}-pipeline-artifacts-"
  force_destroy = true # Allow bucket deletion on terraform destroy (for lab only)
}

# --- CodeCommit Repository (Contains Source Code) ---
resource "aws_codecommit_repository" "repo" {
  repository_name = "${var.project_name}-repo"
  description     = "Repository for Blue/Green Lab"
}

# --- CodeBuild Project (Package Application) ---
resource "aws_codebuild_project" "build_project" {
  name          = "${var.project_name}-build"
  description   = "Builds the application artifacts"
  build_timeout = "5"
  service_role  = data.terraform_remote_state.core.outputs.codebuild_service_role_arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml" # Find buildspec.yml in root directory
  }

  logs_config {
    cloudwatch_logs {
      status = "ENABLED"
    }
  }
}

# --- CodePipeline (CI/CD Process) ---
resource "aws_codepipeline" "pipeline" {
  name     = "${var.project_name}-pipeline"
  role_arn = data.terraform_remote_state.core.outputs.codepipeline_service_role_arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"
  }

  # Stage 1: Source (Fetch code from CodeCommit)
  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        RepositoryName       = aws_codecommit_repository.repo.repository_name
        BranchName           = "master"
        PollForSourceChanges = "false" # Use EventBridge to trigger
      }
    }
  }

  # Stage 2: Build (Use CodeBuild)
  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.build_project.name
      }
    }
  }

  # Stage 3: Deploy (Use CodeDeploy)
  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        ApplicationName     = aws_codedeploy_app.app.name
        DeploymentGroupName = aws_codedeploy_deployment_group.bg_group.deployment_group_name
      }
    }
  }
}
