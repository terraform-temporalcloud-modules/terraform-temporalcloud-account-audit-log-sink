// Verifies create_account_audit_log_sink = false against a real provider.
//
// This is the only run block in the suite that applies, and it applies nothing:
// zero resources, so no Kinesis stream, no Pub/Sub topic and — critically — no
// change to account-wide audit logging. It still configures the provider, which
// is why it needs TEMPORAL_CLOUD_API_KEY.
//
// There is deliberately no test that CREATES a sink. ./README.md sets out why and
// what a maintainer would have to provision to add one.

provider "temporalcloud" {}

run "creates_nothing" {
  variables {
    create_account_audit_log_sink = false
  }

  // Every output is count-gated behind try(); these assertions prove the
  // fallbacks evaluate rather than erroring when the module is switched off.
  assert {
    condition     = output.account_audit_log_sink_id == ""
    error_message = "account_audit_log_sink_id should fall back to empty when create_account_audit_log_sink = false"
  }

  assert {
    condition     = output.account_audit_log_sink_name == ""
    error_message = "account_audit_log_sink_name should fall back to empty when create_account_audit_log_sink = false"
  }

  assert {
    condition     = output.account_audit_log_sink_enabled == null
    error_message = "account_audit_log_sink_enabled should fall back to null"
  }

  assert {
    condition     = output.account_audit_log_sink_kinesis == null
    error_message = "account_audit_log_sink_kinesis should fall back to null"
  }

  assert {
    condition     = output.account_audit_log_sink_pubsub == null
    error_message = "account_audit_log_sink_pubsub should fall back to null"
  }
}
