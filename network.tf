resource "google_compute_network" "primary" {
  provider = google-beta

  name = "test-${random_id.unique.hex}"

  depends_on = [google_project_service.all]
}

resource "google_compute_global_address" "sql" {
  provider = google-beta

  name          = "sql-${random_id.unique.hex}"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.primary.self_link
}

resource "google_service_networking_connection" "sql" {
  provider = google-beta

  network                 = google_compute_network.primary.self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.sql.name]
}

resource "google_compute_firewall" "allow-ssh" {
  name    = "test-${random_id.unique.hex}-allow-ssh"
  network = google_compute_network.primary.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
}

resource "google_compute_firewall" "allow-internal" {
  name    = "test-${random_id.unique.hex}-allow-internal"
  network = google_compute_network.primary.name

  allow {
    protocol = "tcp"
  }

  source_ranges = ["10.128.0.0/9"]
}
