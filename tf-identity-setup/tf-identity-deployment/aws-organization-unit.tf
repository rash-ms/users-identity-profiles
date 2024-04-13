module "aws-organization" {
  source     = "../../aws-organization-unit"
  role_tags  = var.role_tags

  providers = {
    aws = aws.aws-us-east-1
  }
}