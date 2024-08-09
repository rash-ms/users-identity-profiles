variable "users_yaml_path" {
  description = "Path to the users YAML configuration file"
  type        = string
}

variable "groups_yaml_path" {
  description = "Path to the groups YAML configuration file"
  type        = string
}

variable "group_ids" {
  type        = map(string)
  description = "Map of group names to their respective group IDs."
}

variable "identity_store_id" {
  type        = string
  description = "The Identity Store ID for the AWS SSO instance."
}
