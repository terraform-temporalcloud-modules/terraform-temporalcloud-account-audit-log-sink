output "sink_name" {
  description = "Unique audit log sink name for this test run, prefixed `tftest-` so a leftover from an interrupted run is identifiable in the Temporal Cloud account"
  value       = "tftest-${random_pet.this.id}"
}
