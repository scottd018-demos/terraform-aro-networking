variable "private" {
  type    = bool
  default = false
}

variable "resource_group" {
  type = string
}

variable "name_prefix" {
  type = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/22"
}

variable "tags" {
  description = "Tags applied to all objects"
  type        = map(string)
  default = {
    "owner" = "dscott"
  }

  validation {
    condition     = (var.tags["owner"] != null && var.tags["owner"] != "")
    error_message = "Please specify the 'owner' tag as part of 'var.tags'."
  }
}
