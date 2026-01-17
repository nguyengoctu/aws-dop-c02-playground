# --- IAM Role cho EC2 Instances ---
# Role này cho phép EC2 instance gọi các dịch vụ AWS khác
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

# Gán quyền SSM để debug (Session Manager) - Không cần mở port 22
resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Gán quyền CodeDeploy cho EC2 để agent có thể hoạt động
resource "aws_iam_role_policy_attachment" "ec2_codedeploy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforAWSCodeDeploy"
}

# Cho phép EC2 truy cập S3 (để tải artifacts về)
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

# Instance Profile là vỏ bọc để gắn Role vào EC2
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}


# --- IAM Role cho CodeDeploy Service ---
# Role này cho phép service CodeDeploy thực hiện các hành động thay bạn (tạo ASG mới, terminat instance cũ, v.v.)
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

# FIX: Cấp thêm quyền AutoScalingFullAccess cho CodeDeploy
# Vì khi dùng tính năng "Copy Auto Scaling Group", CodeDeploy cần quyền tạo ASG mới thay cho bạn.
resource "aws_iam_role_policy_attachment" "codedeploy_autoscaling" {
  role       = aws_iam_role.codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/AutoScalingFullAccess"
}

# FIX: Cấp thêm quyền ElasticLoadBalancingFullAccess cho CodeDeploy
# CodeDeploy cần quyền này để thao tác với Load Balancer (Register/Deregister Targets)
resource "aws_iam_role_policy_attachment" "codedeploy_elb" {
  role       = aws_iam_role.codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
}

# FIX CRITICAL: Cấp quyền EC2 cho CodeDeploy để copy ASG với Launch Template
# Khi CodeDeploy copy ASG, nó cần tạo Launch Template mới cho Green fleet
# AutoScalingFullAccess KHÔNG bao gồm các quyền EC2 này!
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

# FIX: Cấp quyền iam:PassRole (Rất quan trọng cho Blue/Green)
# Khi CodeDeploy copy ASG để tạo máy mới, nó cần quyền "PassRole" để gán IAM Role (ec2_profile) cho các máy mới đó.
# Nếu thiếu quyền này, quá trình tạo ASG sẽ thất bại.
resource "aws_iam_role_policy" "codedeploy_pass_role" {
  name = "${var.project_name}-codedeploy-pass-role"
  role = aws_iam_role.codedeploy_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "iam:PassRole"
      Resource = "*" # Trong môi trường Lab cho phép * để đơn giản, thực tế nên giới hạn ARN của ec2_role
      Condition = {
        StringLike = {
          "iam:PassedToService" = ["ec2.amazonaws.com", "autoscaling.amazonaws.com"]
        }
      }
    }]
  })
}


# --- IAM Role cho CodeBuild ---
# Role này cho phép CodeBuild lấy code, ghi log, và upload thành phẩm lên S3
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


# --- IAM Role cho CodePipeline ---
# Role "nhạc trưởng", cho phép Pipeline điều phối CodeCommit, CodeBuild và CodeDeploy
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
