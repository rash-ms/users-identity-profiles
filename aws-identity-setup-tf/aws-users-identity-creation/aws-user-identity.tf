# locals {
#   config = yamldecode(file(var.yaml_path))

#   # Flatten the user_groups into a list of maps
#   flattened_user_groups = flatten([
#     for group_name, users in local.config : [
#       for user in users : {
#         group = group_name
#         user  = user
#       }
#     ]
#   ])
# }

provider "aws" {
  region = "us-east-1"  # Replace with your desired region
}

locals {
  config = yamldecode(file(var.yaml_path))

  # Flatten the user_groups into a list of maps, ensuring we handle null values
  flattened_user_groups = flatten([
    for group_name, users in local.config : [
      for user in coalesce(users, []) : {
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
      set -e

      echo "Processing user: ${each.value.user}"
      echo "Processing group: ${each.value.group}"

      # Check if the user exists
      user_id=$(aws identitystore list-users --identity-store-id ${data.aws_ssoadmin_instances.main.identity_store_ids[0]} --query "Users[?UserName=='${each.value.user}'].UserId" --output text)
      if [ -z "$user_id" ]; then
        echo "Creating user: ${each.value.user}"
        # Create the user if it doesn't exist
        user_id=$(aws identitystore create-user --identity-store-id ${data.aws_ssoadmin_instances.main.identity_store_ids[0]} --user-name "${each.value.user}" --display-name "${each.value.user}" --name '{"FamilyName": "default", "GivenName": "${split("@", each.value.user)[0]}"}' --emails '[{"Primary": true, "Type": "work", "Value": "${each.value.user}"}]' --query "User.UserId" --output text)
      fi

      # Debugging output for user_id
      echo "User ID for ${each.value.user} is $user_id"

      # Check and get group ID
      group_id=$(aws identitystore list-groups --identity-store-id ${data.aws_ssoadmin_instances.main.identity_store_ids[0]} --query "Groups[?DisplayName=='${each.value.group}'].GroupId" --output text)
      
      # Debugging output for group_id
      echo "Group ID for ${each.value.group} is $group_id"

      # Ensure both IDs are correctly retrieved
      if [ -z "$user_id" ] || [ -z "$group_id" ]; then
        echo "Error: Missing user ID or group ID."
        exit 1
      fi

      echo "Checking membership for user ID: $user_id in group ID: $group_id"

      # Check if the user is already a member of the group
      membership_exists=$(aws identitystore list-group-memberships --identity-store-id ${data.aws_ssoadmin_instances.main.identity_store_ids[0]} --query "GroupMemberships[?GroupId=='$group_id' && MemberId.UserId=='$user_id'].GroupMembershipId" --output text)
      if [ -z "$membership_exists" ]; then
        echo "Adding user ${each.value.user} to group ${each.value.group}"
        # Add user to group if not already a member
        aws identitystore create-group-membership --identity-store-id ${data.aws_ssoadmin_instances.main.identity_store_ids[0]} --group-id "GroupId=$group_id" --member-id "UserId=$user_id"
      else
        echo "User ${each.value.user} is already a member of group ${each.value.group}"
      fi
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
