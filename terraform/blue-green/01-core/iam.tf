# --- IAM Role for EC2 Instances ---
# This role allows EC2 instances to call other AWS services
resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# Assign SSM permissions for debugging (Session Manager) - No need to open port 22
resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Assign CodeDeploy permissions to EC2 so the agent can operate
resource "aws_iam_role_policy_attachment" "ec2_codedeploy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforAWSCodeDeploy"
}

# Allow EC2 to access S3 (to download artifacts)
resource "aws_iam_role_policy" "ec2_s3_access" {
  name = "${var.project_name}-s3-access"
  role = aws_iam_role.ec2_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:Get*",
        "s3:List*"
      ]
      Resource = "*"
    }]
  })
}

# Instance Profile is a wrapper to attach the Role to EC2
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}


# --- IAM Role for CodeDeploy Service ---
# This role allows CodeDeploy service to perform actions on your behalf (create new ASG, terminate old instances, etc.)
resource "aws_iam_role" "codedeploy_role" {
  name = "${var.project_name}-codedeploy-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "codedeploy.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codedeploy_service" {
  role       = aws_iam_role.codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

# FIX: Grant additional AutoScalingFullAccess permission to CodeDeploy
# Because when using "Copy Auto Scaling Group" feature, CodeDeploy needs permission to create new ASG on your behalf.
resource "aws_iam_role_policy_attachment" "codedeploy_autoscaling" {
  role       = aws_iam_role.codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/AutoScalingFullAccess"
}

# FIX: Grant additional ElasticLoadBalancingFullAccess permission to CodeDeploy
# CodeDeploy needs this permission to manipulate Load Balancer (Register/Deregister Targets)
resource "aws_iam_role_policy_attachment" "codedeploy_elb" {
  role       = aws_iam_role.codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
}

# FIX CRITICAL: Grant EC2 permissions to CodeDeploy to copy ASG with Launch Template
# When CodeDeploy copies ASG, it needs to create a new Launch Template for the Green fleet
# AutoScalingFullAccess does NOT include these EC2 permissions!
resource "aws_iam_role_policy" "codedeploy_ec2_launch_template" {
  name = "${var.project_name}-codedeploy-ec2-lt"
  role = aws_iam_role.codedeploy_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:RunInstances",
        "ec2:CreateLaunchTemplate",
        "ec2:CreateLaunchTemplateVersion",
        "ec2:ModifyLaunchTemplate",
        "ec2:DeleteLaunchTemplate",
        "ec2:DescribeLaunchTemplates",
        "ec2:DescribeLaunchTemplateVersions",
        "ec2:DescribeInstances",
        "ec2:DescribeInstanceStatus",
        "ec2:DescribeImages",
        "ec2:DescribeSnapshots",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSubnets",
        "ec2:DescribeVpcs",
        "ec2:DescribeKeyPairs",
        "ec2:DescribeAvailabilityZones",
        "ec2:CreateTags",
        "ec2:TerminateInstances"
      ]
      Resource = "*"
    }]
  })
}

# FIX: Grant iam:PassRole permission (Critical for Blue/Green)
# When CodeDeploy copies ASG to create new instances, it needs "PassRole" permission to assign IAM Role (ec2_profile) to those new instances.
# If this permission is missing, the ASG creation process will fail.
resource "aws_iam_role_policy" "codedeploy_pass_role" {
  name = "${var.project_name}-codedeploy-pass-role"
  role = aws_iam_role.codedeploy_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "iam:PassRole"
      Resource = "*" # Allowed * for simplicity in Lab env, in reality should limit to ec2_role ARN
      Condition = {
        StringLike = {
          "iam:PassedToService" = ["ec2.amazonaws.com", "autoscaling.amazonaws.com"]
        }
      }
    }]
  })
}


# --- IAM Role for CodeBuild ---
# This role allows CodeBuild to fetch code, write logs, and upload artifacts to S3
resource "aws_iam_role" "codebuild_role" {
  name = "${var.project_name}-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "codebuild.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "codebuild_base" {
  name = "${var.project_name}-codebuild-policy"
  role = aws_iam_role.codebuild_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "codecommit:GitPull"
        ]
        Resource = "*"
      }
    ]
  })
}


# --- IAM Role for CodePipeline ---
# The "conductor" role, allows Pipeline to coordinate CodeCommit, CodeBuild, and CodeDeploy
resource "aws_iam_role" "codepipeline_role" {
  name = "${var.project_name}-codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "codepipeline.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "${var.project_name}-codepipeline-policy"
  role = aws_iam_role.codepipeline_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutObjectAcl",
          "s3:PutObject"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "codecommit:GetBranch",
          "codecommit:GetCommit",
          "codecommit:UploadArchive",
          "codecommit:GetUploadArchiveStatus",
          "codecommit:CancelUploadArchive"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "codedeploy:CreateDeployment",
          "codedeploy:GetApplication",
          "codedeploy:GetApplicationRevision",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:RegisterApplicationRevision"
        ]
        Resource = "*"
      }
    ]
  })
}
