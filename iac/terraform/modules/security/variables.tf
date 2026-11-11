variable "name" {
  description = "Prefix for resource names"
  type        = string
}

variable "enable_guardduty" {
  description = "Turns on GuardDuty; the 30-day free trial starts when enabled"
  type        = bool
  default     = false
}
