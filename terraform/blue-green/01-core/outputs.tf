output "vpc_id" {
  value = data.aws_vpc.default.id
}

output "subnet_ids" {
  value = data.aws_subnets.default.ids
}

output "alb_sg_id" {
  value = aws_security_group.alb_sg.id
}

output "ec2_sg_id" {
  value = aws_security_group.ec2_sg.id
}

output "ec2_profile_name" {
  value = aws_iam_instance_profile.ec2_profile.name
}

output "codedeploy_service_role_arn" {
  value = aws_iam_role.codedeploy_role.arn
}

output "codebuild_service_role_arn" {
  value = aws_iam_role.codebuild_role.arn
}

output "codepipeline_service_role_arn" {
  value = aws_iam_role.codepipeline_role.arn
}
