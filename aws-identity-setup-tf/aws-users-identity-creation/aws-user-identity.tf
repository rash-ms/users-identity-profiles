provider "aws" {
  region = "us-east-1"  # Replace with your desired region
}

locals {
  config = yamldecode(file(var.yaml_path))

  # Flatten the user_groups into a list of maps
  flattened_user_groups = flatten([
    for group_name, users in local.config : [
      for user in users : {
        group = group_name
        user  = user
      }
    ]
  ])
}

data "aws_ssoadmin_instances" "main" {}

resource "null_resource" "manage_users" {
  for_each = { for user_map in local.flattened_user_groups : user_map.user => user_map }

  provisioner "local-exec" {
    command = <<EOT
      user_id=$(aws identitystore list-users --identity-store-id ${data.aws_ssoadmin_instances.main.identity_store_ids[0]} --query "Users[?UserName=='${each.value.user}'].UserId" --output text)
      if [ -z "$user_id" ]; then
        user_id=$(aws identitystore create-user --identity-store-id ${data.aws_ssoadmin_instances.main.identity_store_ids[0]} --user-name "${each.value.user}" --display-name "${each.value.user}" --name '{"FamilyName": "default", "GivenName": "${split("@", each.value.user)[0]}"}' --emails '[{"Primary": true, "Type": "work", "Value": "${each.value.user}"}]' --query "User.UserId" --output text)
      fi
      echo "User ID for ${each.value.user} is $user_id"
      group_id=$(aws identitystore list-groups --identity-store-id ${data.aws_ssoadmin_instances.main.identity_store_ids[0]} --query "Groups[?DisplayName=='${each.value.group}'].GroupId" --output text)
      echo "Group ID for ${each.value.group} is $group_id"
      aws identitystore create-group-membership --identity-store-id ${data.aws_ssoadmin_instances.main.identity_store_ids[0]} --group-id $group_id --member-id $user_id
    EOT

    environment = {
      AWS_REGION = "us-east-1"  # Ensure the correct region is set
    }

    interpreter = ["sh", "-c"]
  }

  triggers = {
    always_run = timestamp()
  }
}

output "debug_mappings" {
  value = local.flattened_user_groups
}
