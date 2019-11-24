resource "google_project_service" "all" {
  for_each = toset(["compute.googleapis.com", "sql-component.googleapis.com", "servicenetworking.googleapis.com"])

  service = each.key

  disable_on_destroy = false
}
