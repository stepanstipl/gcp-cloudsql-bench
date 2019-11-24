provider "google" {
  version = "3.0.0-beta.1"
  project = var.project
  region  = var.region
}

provider "google-beta" {
  version = "3.0.0-beta.1"
  project = var.project
  region  = var.region
}

provider "random" {
  version = "2.2.1"
}
