resource "random_id" "unique" {
  byte_length = 2
}

data "google_compute_zones" "available" {
  region = var.region
}
