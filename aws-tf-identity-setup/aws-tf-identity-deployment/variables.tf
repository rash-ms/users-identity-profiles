# variable "teams" {
#   description = "List of team name"
#   type    = list(string)
#   default = ["data-eng-solution", "infra-team", "marketing-team"]
# }

# variable "workspace" {
#   description = "List of workspace for each team."
#   type        = list(string)
#   default     = ["Prod", "Non-prod"]
# }

variable "teams" {
  description = "List of teams"
  type        = list(string)
  default     = ["data-eng", "marketing_team"]
}

variable "workspace" {
  description = "List of environments"
  type        = list(string)
  default     = ["Prod", "NonProd"]
}