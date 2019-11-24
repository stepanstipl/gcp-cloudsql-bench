resource "google_sql_database_instance" "primary" {
  provider = "google-beta"

  name = "sql-${random_id.unique.hex}"

  depends_on = [google_service_networking_connection.sql]

  database_version = "POSTGRES_11"
  settings {
    availability_type = "REGIONAL"
    disk_size         = 4096
    tier              = "db-custom-${var.cpus}-${var.cpus * 4 * 1024}"
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.primary.self_link
    }
    backup_configuration {
      enabled = false
    }
    location_preference {
      zone = data.google_compute_zones.available.names[0]
    }
  }
}

resource "google_sql_database" "database" {
  name     = "test"
  instance = google_sql_database_instance.primary.name
}

resource "random_password" "sql-test" {
  length  = 16
  special = false
}

resource "google_sql_user" "test" {
  name     = "test"
  instance = google_sql_database_instance.primary.name
  password = random_password.sql-test.result
}
