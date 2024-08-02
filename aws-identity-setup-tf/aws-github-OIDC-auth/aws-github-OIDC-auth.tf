# resource "aws_iam_openid_connect_provider" "github_oidc" {
#     client_id_list  =   ["sts.amazonaws.com"]
#     thumbprint_list =   ["1b511abead59c6ce207077c0bf0e0043b1382612"]
#     url             =   "https://token.actions.githubusercontent.com"
# }

# resource "aws_iam_role" "github_actions" {
#   name               = var.github-action-name
#   assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
#   tags               = var.github-action-role-tags
# }

# resource "aws_iam_role_policy_attachment" "github_actions_admin_access_attach" {
#   role       = aws_iam_role.github_actions.name
#   policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
# }

# data "aws_iam_policy_document" "assume_role_policy" {
#     statement {
#       actions = ["sts:AssumeRoleWithWebIdentity"]
#       effect  = "Allow"
#       principals {
#         type        =  "Federated"
#         identifiers = [aws_iam_openid_connect_provider.github_oidc.arn]
#       }
#       condition {
#         test     = "StringEquals"
#         variable = "token.actions.githubusercontent.com:aud"
#         values   = ["sts.amazonaws.com"]
#       }
#       condition {
#         test     = "StringLike"
#         variable = "token.actions.githubusercontent.com:sub"
#         values   = ["repo:rash-ms/*"]

#       }
#     }
# }


#######################################################

# provider "aws" {
#   alias  = "dev_account"
#   region = "us-east-1"
#   profile = "BDT-data-org-DEV" 
# }

# provider "aws" {
#   alias  = "prod_account"
#   region = "us-east-1"
#   profile = "BDT-data-org-PROD" 
# }

locals {

  policies_data = jsondecode(file("${path.module}/../aws-orgz-team-unit/policies.json"))
  policies      = local.policies_data.policies
  groups        = local.policies_data.groups

  account_ids = {
    "data-eng-DEV"  = "021891586814"  
    "data-eng-PROD" = "021891586728"  
  }
}

resource "aws_iam_openid_connect_provider" "github_oidc" {
  for_each = local.account_ids
  # provider = each.key == "BDT-data-org-DEV" ? aws.dev_account : aws.prod_account

  client_id_list = ["sts.amazonaws.com"]
  url = "https://token.actions.githubusercontent.com"
  thumbprint_list = ["1b511abead59c6ce207077c0bf0e0043b1382612"]
  
}

resource "aws_iam_role" "roles" {
  for_each = local.groups
  # provider = each.key == "BDT-data-org-DEV" ? aws.dev_account : aws.prod_account

  name = "${each.key}_role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = aws_iam_openid_connect_provider.github_oidc.arn
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub" = "repo:rash-ms/*" 
        }
      }
    }]
  })
}

resource "aws_iam_policy" "policies" {
  for_each = local.policies

  # provider = each.key == "BDT-data-org-DEV" ? aws.dev_account : aws.prod_account

  name        = each.value.name
  description = each.value.description
  policy      = jsonencode(each.value.policy)
}

resource "aws_iam_role_policy_attachment" "policy_attachment" {
  for_each = local.groups

  # provider = each.key == "BDT-data-org-DEV" ? aws.dev_account : aws.prod_account

  role       = aws_iam_role.roles[each.key].name
  policy_arn = local.policies[each.key]
}

