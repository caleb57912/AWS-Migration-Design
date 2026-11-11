variable "alert_email" {
  description = "Email that receives budget alerts"
  type        = string
}

variable "monthly_budget_usd" {
  description = "Monthly spend cap for alerts"
  type        = number
  default     = 20
}