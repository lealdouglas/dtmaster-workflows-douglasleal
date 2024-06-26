
variable "subscription_id" {
  description = "Azure subscription id"
}


variable "account_id" {
  description = "Azure databricks account id"
}

variable "aad_groups" {
  description = "List of AAD groups that you want to add to Databricks account"
  type        = list(string)
  default     = ["data_engineer"]
}


variable "project_code" {
  type    = string
  default = "dtmstrdougsll"
}

variable "tags" {
  type = map(any)
  default = {
    projectCode = "dtmstrdougsll"
    application = "dtmstrdougsll"
    costCenter  = "dougsll"
  }
}

variable "envv" {
  type    = string
  default = "dev"
}

