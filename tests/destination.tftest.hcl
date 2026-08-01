// Proves the destination rules are enforced at plan time.
//
// `command = plan` throughout, so nothing is created and no account state
// changes. The provider is still configured, hence TEMPORAL_CLOUD_API_KEY.
//
// The exactly-one rule lives in a resource precondition rather than a variable
// validation: a validation cannot reference a second variable below Terraform
// 1.9, and the resource is count-gated so the check is correctly skipped when
// the module is switched off. disabled.tftest.hcl covers that half — it must NOT
// trip this precondition.

provider "temporalcloud" {}

run "rejects_two_destinations" {
  command = plan

  variables {
    sink_name = "tftest-two-destinations"

    kinesis = {
      destination_uri = "arn:aws:kinesis:us-east-1:111122223333:stream/temporal-audit-logs"
      region          = "us-east-1"
      role_name       = "arn:aws:iam::111122223333:role/Temporal-Cloud-Log-Writer"
    }

    pubsub = {
      topic_name            = "temporal-audit-logs"
      service_account_email = "temporal-audit@example-project.iam.gserviceaccount.com"
    }
  }

  expect_failures = [
    temporalcloud_account_audit_log_sink.this,
  ]
}

run "rejects_no_destination" {
  command = plan

  variables {
    sink_name = "tftest-no-destination"
  }

  expect_failures = [
    temporalcloud_account_audit_log_sink.this,
  ]
}

// The per-destination rules are variable-scoped, so they are reported against
// the variable rather than the resource.

run "rejects_bare_kinesis_stream_name" {
  command = plan

  variables {
    sink_name = "tftest-bare-kinesis-uri"

    kinesis = {
      destination_uri = "temporal-audit-logs"
      region          = "us-east-1"
      role_name       = "arn:aws:iam::111122223333:role/Temporal-Cloud-Log-Writer"
    }
  }

  expect_failures = [
    var.kinesis,
  ]
}

// destination_uri is left valid on purpose. An empty URI also fails the `arn:`
// rule above, so emptying it would leave this block green even if the
// non-empty rule were deleted. region and role_name are reachable only by this
// rule.
run "rejects_empty_kinesis_fields" {
  command = plan

  variables {
    sink_name = "tftest-empty-kinesis"

    kinesis = {
      destination_uri = "arn:aws:kinesis:us-east-1:111122223333:stream/temporal-audit-logs"
      region          = ""
      role_name       = ""
    }
  }

  expect_failures = [
    var.kinesis,
  ]
}

run "rejects_empty_pubsub_topic" {
  command = plan

  variables {
    sink_name = "tftest-empty-pubsub"

    pubsub = {
      topic_name            = ""
      service_account_email = "temporal-audit@example-project.iam.gserviceaccount.com"
    }
  }

  expect_failures = [
    var.pubsub,
  ]
}

// A fully-qualified topic path is the natural thing to reach for and is wrong.
run "rejects_qualified_pubsub_topic_path" {
  command = plan

  variables {
    sink_name = "tftest-qualified-pubsub"

    pubsub = {
      topic_name            = "projects/example-project/topics/temporal-audit-logs"
      service_account_email = "temporal-audit@example-project.iam.gserviceaccount.com"
    }
  }

  expect_failures = [
    var.pubsub,
  ]
}

// Every service account attribute is individually optional, so omitting all
// three looks valid. The provider rejects it with "Missing Service Account
// Configuration"; this catches it first.
run "rejects_pubsub_without_service_account" {
  command = plan

  variables {
    sink_name = "tftest-pubsub-no-sa"

    pubsub = {
      topic_name = "temporal-audit-logs"
    }
  }

  expect_failures = [
    var.pubsub,
  ]
}
