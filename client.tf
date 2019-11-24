resource "google_compute_instance" "client" {
  name = "sql-client-${random_id.unique.hex}"

  machine_type     = "n2-highcpu-16"
  min_cpu_platform = "Intel Cascade Lake"
  zone             = data.google_compute_zones.available.names[0]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }

  network_interface {
    network = google_compute_network.primary.self_link
    access_config {
    }
  }

  metadata_startup_script = "apt-get update; apt-get install -y postgresql-contrib"

  service_account {
    scopes = ["cloud-platform"]
  }
}
