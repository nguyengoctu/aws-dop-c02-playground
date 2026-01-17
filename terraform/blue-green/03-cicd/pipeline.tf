# --- S3 Bucket chứa Artifacts ---
resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket_prefix = "${var.project_name}-pipeline-artifacts-"
  force_destroy = true # Cho phép xóa bucket khi destroy terraform (chỉ dùng cho lab)
}

# --- CodeCommit Repository (Chứa Source Code) ---
resource "aws_codecommit_repository" "repo" {
  repository_name = "${var.project_name}-repo"
  description     = "Repository cho Blue/Green Lab"
}

# --- CodeBuild Project (Đóng gói ứng dụng) ---
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
    buildspec = "buildspec.yml" # Tìm file buildspec.yml ở thư mục gốc
  }

  logs_config {
    cloudwatch_logs {
      status = "ENABLED"
    }
  }
}

# --- CodePipeline (Quy trình CI/CD) ---
resource "aws_codepipeline" "pipeline" {
  name     = "${var.project_name}-pipeline"
  role_arn = data.terraform_remote_state.core.outputs.codepipeline_service_role_arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"
  }

  # Giai đoạn 1: Source (Lấy code từ CodeCommit)
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
        PollForSourceChanges = "false" # Dùng EventBridge để trigger
      }
    }
  }

  # Giai đoạn 2: Build (Dùng CodeBuild)
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

  # Giai đoạn 3: Deploy (Dùng CodeDeploy)
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
