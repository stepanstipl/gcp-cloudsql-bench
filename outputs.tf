output "client_instance_name" {
  value = google_compute_instance.client.name
}

output "client_instance_zone" {
  value = google_compute_instance.client.zone
}

output "sql_ip" {
  value = google_sql_database_instance.primary.private_ip_address
}

output "sql_user" {
  value = google_sql_user.test.name
}

output "sql_password" {
  value     = google_sql_user.test.password
  sensitive = true
}

output "sql_db" {
  value = google_sql_database.database.name
}

