# Wrapper for the Temporal Cloud account audit log sink module

The configuration in `wrappers/` implements the single module wrapper pattern, which allows managing
several copies of this module from one call in places where the native `for_each` on a module block is
not available — most commonly Terragrunt.

This wrapper adds no functionality of its own. Every key under `items` accepts any input the root
module accepts, and `defaults` supplies values shared by all items.

Contributors: see [CONTRIBUTING.md](../CONTRIBUTING.md) for how these files are maintained.

## Read this before using it

A Temporal Cloud account holds **one** audit log sink. Several items pointed at the same account do
not give you several sinks — they contend for the same one, and each apply overwrites the last.

This wrapper is therefore only useful when each item targets a **different Temporal Cloud account**,
through a provider configuration passed per item. If you manage one account, call the root module
directly.

## Usage with Terraform

```hcl
module "audit_log_sinks" {
  source = "terraform-temporalcloud-modules/account-audit-log-sink/temporalcloud//wrappers"

  # Shared by every item unless the item overrides it.
  defaults = {
    enabled = true

    timeouts = {
      create = "10m"
      delete = "10m"
    }
  }

  items = {
    aws = {
      sink_name = "audit-logs"

      kinesis = {
        destination_uri = "arn:aws:kinesis:us-east-1:111122223333:stream/temporal-audit-logs"
        region          = "us-east-1"
        role_name       = "arn:aws:iam::111122223333:role/Temporal-Cloud-Log-Writer"
      }
    }

    gcp = {
      sink_name = "audit-logs"

      pubsub = {
        topic_name            = "temporal-audit-logs"
        service_account_email = "temporal-audit@example-project.iam.gserviceaccount.com"
      }
    }
  }
}
```

An item that overrides a destination supplied in `defaults` must also clear the other one, because
exactly one may be set:

```hcl
defaults = {
  kinesis = { destination_uri = "...", region = "us-east-1", role_name = "..." }
}

items = {
  gcp = {
    sink_name = "audit-logs"
    kinesis   = null # without this, both destinations are set and the plan fails
    pubsub    = { topic_name = "temporal-audit-logs", service_account_email = "..." }
  }
}
```

Outputs are keyed by the same map keys:

```hcl
output "aws_sink_id" {
  value = module.audit_log_sinks.wrapper["aws"].account_audit_log_sink_id
}
```

## Usage with Terragrunt

`terragrunt.hcl`:

```hcl
terraform {
  source = "tfr:///terraform-temporalcloud-modules/account-audit-log-sink/temporalcloud//wrappers?version=1.0.0"
  # Alternative source:
  # source = "git::git@github.com:terraform-temporalcloud-modules/terraform-temporalcloud-account-audit-log-sink.git//wrappers?ref=v1.0.0"
}

inputs = {
  defaults = {
    enabled = true
  }

  items = {
    aws = {
      sink_name = "audit-logs"

      kinesis = {
        destination_uri = "arn:aws:kinesis:us-east-1:111122223333:stream/temporal-audit-logs"
        region          = "us-east-1"
        role_name       = "arn:aws:iam::111122223333:role/Temporal-Cloud-Log-Writer"
      }
    }
  }
}
```

Pin `?version=` / `?ref=` to a released tag rather than a branch, so a wrapper upgrade is a deliberate
change.

## Inputs

| Name | Description | Type | Default |
| ---- | ----------- | ---- | ------- |
| `defaults` | Default values applied to every item in `items`, unless that item overrides them | `any` | `{}` |
| `items` | Map of audit log sinks to manage; each key becomes an instance of the module | `any` | `{}` |

## Outputs

| Name | Description |
| ---- | ----------- |
| `wrapper` | Map of module outputs, keyed by the same keys as `items` |
