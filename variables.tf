variable "region" {
  type        = string
  description = "GCP Region"
}

variable "project" {
  type        = string
  description = "GCP Project ID"
}

variable "cpus" {
  type        = number
  description = "SQL instance number of vCPUs"
  default     = 1
}
