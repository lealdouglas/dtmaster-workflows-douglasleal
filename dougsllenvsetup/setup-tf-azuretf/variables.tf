variable "subscription_id" {
  description = "Azure subscription id"
}

variable "project_code" {
  type    = string
  default = "dtmstrdougsll"
}

variable "location" {
  type    = string
  default = "Brazil South"
}

variable "location_code" {
  type    = string
  default = "br"
}

variable "envv" {
  type    = string
  default = "dev"
}

variable "tags" {
  type = map(any)
  default = {
    projectCode = "dtmstrdougsll"
    application = "dtmstrdougsll"
    costCenter  = "dougsll"
  }
}

variable "aad_groups" {
  description = "List of AAD groups that you want to add to Databricks account"
  type        = list(string)
  default     = ["data_engineer"]
}
