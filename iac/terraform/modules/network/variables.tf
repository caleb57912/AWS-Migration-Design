variable "name" {
  description = "Prefix for resource names"
  type        = string
}

variable "cidr_block" {
  description = "VPC address range"
  type        = string
}

variable "azs" {
  description = "Availability Zones, one subnet per tier in each"
  type        = list(string)

  validation {
    condition     = length(var.azs) == 3
    error_message = "The design requires exactly 3 Availability Zones."
  }
}
