# Temporal Cloud Account Audit Log Sink Terraform module

[![CI](https://github.com/terraform-temporalcloud-modules/terraform-temporalcloud-account-audit-log-sink/actions/workflows/pre-commit.yml/badge.svg?branch=main)](https://github.com/terraform-temporalcloud-modules/terraform-temporalcloud-account-audit-log-sink/actions/workflows/pre-commit.yml?query=branch%3Amain)
[![Apply Tests](https://github.com/terraform-temporalcloud-modules/terraform-temporalcloud-account-audit-log-sink/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/terraform-temporalcloud-modules/terraform-temporalcloud-account-audit-log-sink/actions/workflows/test.yml?query=branch%3Amain)

Terraform module which configures a [Temporal Cloud](https://temporal.io/cloud) account audit log sink,
streaming control-plane audit events to Amazon Kinesis or Google Cloud Pub/Sub.

Both badges report the state of `main`. **CI** covers formatting, linting, documentation and
`terraform validate`, and runs on every pull request and again after merge. **Apply Tests** exercises
this module against a live Temporal Cloud account, weekly and on demand — for this module it creates
nothing, for the reasons in [tests/README.md](tests/README.md).

## The sink is account-wide

Read this before anything else. It is the property that makes this module different from the rest of
the family.

- **An account has one Audit Log Integration.** Temporal Cloud's UI exposes exactly one, and every
  operation on it — set up, edit, delete — acts on that one. Two Terraform configurations pointed at
  the same Temporal Cloud account will therefore fight over it, each apply overwriting the other.
  Own it in exactly one place.
- **`terraform destroy` stops audit logging for the entire account.** Not for a namespace, not for
  this configuration — the account. For most organisations running audit logs, that is a compliance
  control rather than a convenience, and removing it is a reportable event. Terraform's own
  [`prevent_destroy`](https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle) on
  the module call is worth considering.
- **To stop delivery reversibly, set `enabled = false`** rather than destroying the sink. The sink and
  its destination configuration stay in place and delivery resumes when you set it back.
- **Renaming replaces the sink.** `sink_name` cannot be changed in place, so editing it destroys the
  sink and creates a new one, with an interruption in delivery in between.

## What audit logs contain

Audit logs are **control-plane** events: namespace, user, group, service account, API key,
connectivity rule, Nexus endpoint and account operations. Temporal's documentation is explicit about
what they are not:

> Audit Logs do NOT capture data plane events, like Workflow Start, Workflow Terminate, Schedule
> Create, etc. Instead, explore the Export feature, which does let you send closed Workflow Histories
> to external storage.
>
> — [Audit Logging](https://docs.temporal.io/cloud/audit-logs)

If you want workflow histories rather than control-plane events, you want a namespace export sink, not
this module.

## Requirements

The `temporalcloud` provider authenticates with an API key, read from the `TEMPORAL_CLOUD_API_KEY`
environment variable:

```bash
export TEMPORAL_CLOUD_API_KEY="<your-api-key>"
```

The provider authenticates when it initialises, so a key is needed even for a `terraform plan` that
would create nothing. Keep the key out of version control — an untracked `.env` file rather than a
committed `.tfvars`.

The key must belong to a principal with **Account Owner** or **Global Administrator** on the Temporal
Cloud account. Lesser roles cannot configure an Audit Log Integration.

The destination infrastructure is yours and must exist first. See
[Prerequisites](#prerequisites-the-part-that-fails-first) below — this is where a first apply usually
fails.

## Usage

### Amazon Kinesis

```hcl
module "audit_log_sink" {
  source  = "terraform-temporalcloud-modules/account-audit-log-sink/temporalcloud"
  version = "~> 1.0"

  sink_name = "audit-logs"
  enabled   = true

  kinesis = {
    # The stream's ARN, not its bare name.
    destination_uri = "arn:aws:kinesis:us-east-1:111122223333:stream/temporal-audit-logs"
    region          = "us-east-1"

    # The role's full ARN, despite the attribute being called role_name.
    role_name = "arn:aws:iam::111122223333:role/Temporal-Cloud-Log-Writer"
  }
}
```

### Google Cloud Pub/Sub

```hcl
module "audit_log_sink" {
  source  = "terraform-temporalcloud-modules/account-audit-log-sink/temporalcloud"
  version = "~> 1.0"

  sink_name = "audit-logs"
  enabled   = true

  pubsub = {
    # The bare topic name, not projects/<project>/topics/<topic>.
    topic_name = "temporal-audit-logs"

    # Either this, or service_account_id together with gcp_project_id.
    service_account_email = "temporal-audit@example-project.iam.gserviceaccount.com"
  }
}
```

### Pausing delivery without destroying the sink

```hcl
module "audit_log_sink" {
  source  = "terraform-temporalcloud-modules/account-audit-log-sink/temporalcloud"
  version = "~> 1.0"

  sink_name = "audit-logs"

  # Delivery stops; the sink and its destination configuration survive.
  enabled = false

  kinesis = {
    destination_uri = "arn:aws:kinesis:us-east-1:111122223333:stream/temporal-audit-logs"
    region          = "us-east-1"
    role_name       = "arn:aws:iam::111122223333:role/Temporal-Cloud-Log-Writer"
  }
}
```

## Prerequisites: the part that fails first

The module configures Temporal Cloud. The stream or topic, and the identity Temporal Cloud uses to
write to it, are yours to create. Skipping this is the most common reason a first apply fails, and it
fails on permissions rather than on anything Terraform can catch.

### Amazon Kinesis

1. A **Kinesis data stream**. `destination_uri` takes its ARN.
2. An **IAM role Temporal Cloud can assume**, carrying:
   - a **trust policy** whose principals are Temporal Cloud's audit log delivery roles — there are
     several, one per Temporal-owned AWS account, because Temporal selects among them when writing —
     with an `sts:ExternalId` condition set to the external ID Temporal gives you.
   - a **permissions policy** on the stream allowing `kinesis:PutRecord`, `kinesis:PutRecords`,
     `kinesis:DescribeStreamSummary` and `kinesis:UpdateShardCount`.

   Temporal publishes a CloudFormation template that creates this role, and it is the authoritative
   source for the current principal list:
   [`iam-role-for-temporal-audit-logs.yaml`](https://temporal-auditlogs-config.s3.us-west-2.amazonaws.com/cloudformation/iam-role-for-temporal-audit-logs.yaml),
   linked from [Set up Audit Logging with AWS Kinesis](https://docs.temporal.io/cloud/audit-logs-aws).
   Prefer it to a hand-written trust policy: the principal list belongs to Temporal, and the Temporal
   Cloud UI hands you a copy prefilled with your external ID. The external ID's value is not
   published — Temporal provides it.

   `kinesis:UpdateShardCount` is in Temporal's own template and usually draws a question in security
   review: Temporal scales the stream to match audit log volume.

Kinesis rate limits apply to the stream, so size it for the account's control-plane event volume.

### Google Cloud Pub/Sub

1. A **Pub/Sub topic**. `topic_name` takes its bare name.
2. A **service account in the same project**, which Temporal Cloud impersonates — it does not publish
   as itself. Two bindings:
   - `roles/pubsub.publisher` **on the topic**, granted to your service account.
   - `roles/iam.serviceAccountTokenCreator` **on your service account**, granted to Temporal Cloud's
     service accounts. Their addresses are not published; the Temporal Cloud UI shows the ones for
     your account.

   Temporal maintains a module that creates all of this:
   [`temporalio/terraform-modules//modules/auditlog-sa`](https://github.com/temporalio/terraform-modules/tree/main/modules/auditlog-sa).

[The Pub/Sub setup page](https://docs.temporal.io/cloud/audit-logs-gcp) says the prerequisites can be
skipped "if you use Terraform for your deployment". That refers to the UI's "Deploy with Terraform"
button, which emits the module above. A configuration calling `temporalcloud_account_audit_log_sink`
directly still needs the topic, the service account and both bindings.

## Notes

Behaviours worth knowing before you plan:

- **Exactly one of `kinesis` or `pubsub`.** A sink has a single destination. The module rejects zero or
  two at plan time, naming the variables; the provider enforces the same rule independently.
- **`role_name` wants an ARN.** The attribute is named for the API field, but a Kinesis destination
  carries no separate AWS account ID, so the account has to travel inside this value. A bare role name
  gives Temporal Cloud nothing to assume.
- **`destination_uri` wants the stream ARN**, not a bare stream name and not a `kinesis://` URI.
- **`topic_name` wants the bare topic name**, not `projects/<project>/topics/<topic>`.
- **The Pub/Sub service account attributes are an either/or.** `service_account_email`,
  `service_account_id` and `gcp_project_id` are individually optional, which reads as "omit them all".
  Doing so fails with `Missing Service Account Configuration`. Supply the email, or supply the ID and
  the project. This module catches it at plan time.
- **Logs are not instant.** Expect the first records within about ten minutes of a successful apply.
  An empty stream immediately after apply is not evidence of a misconfiguration.
- **Temporal retains audit log data for up to 30 days**, and retrieving history within that window is
  a support request rather than an API call. The sink is how you keep it yourself.

## Examples

- [kinesis](examples/kinesis) — delivery to an Amazon Kinesis data stream, with the AWS-side
  prerequisites written out
- [pubsub](examples/pubsub) — delivery to a Google Cloud Pub/Sub topic, with the GCP-side IAM bindings
  written out

Neither example creates the destination infrastructure. Temporal's delivery principals are Temporal's
to rotate, so pinning them into a published example would hand consumers a trust policy that breaks
silently; both READMEs link Temporal's own templates instead.

## Managing several sinks

The [`wrappers`](wrappers) submodule creates several sinks from one call, for use with Terragrunt or
anywhere a `for_each` on the module block is awkward. Because a Temporal Cloud account holds one audit
log sink, this is only meaningful when each item targets a **different account** through its own
provider configuration:

```hcl
module "audit_log_sinks" {
  source  = "terraform-temporalcloud-modules/account-audit-log-sink/temporalcloud//wrappers"
  version = "~> 1.0"

  defaults = {
    enabled = true
  }

  items = {
    kinesis = {
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

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.7 |
| <a name="requirement_temporalcloud"></a> [temporalcloud](#requirement\_temporalcloud) | >= 1.6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_temporalcloud"></a> [temporalcloud](#provider\_temporalcloud) | >= 1.6.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [temporalcloud_account_audit_log_sink.this](https://registry.terraform.io/providers/temporalio/temporalcloud/latest/docs/resources/account_audit_log_sink) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_create_account_audit_log_sink"></a> [create\_account\_audit\_log\_sink](#input\_create\_account\_audit\_log\_sink) | Controls if the account audit log sink should be created. Set to `false` to disable the module without removing the call | `bool` | `true` | no |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Controls whether the sink delivers audit logs. Setting this to `false` keeps the sink and its destination configuration in place but stops delivery; it does not remove the sink. Distinct from `create_account_audit_log_sink`, which controls whether the sink exists at all. Defaults to whatever Temporal Cloud applies when omitted | `bool` | `null` | no |
| <a name="input_kinesis"></a> [kinesis](#input\_kinesis) | Amazon Kinesis destination. `destination_uri` is the ARN of the Kinesis data stream Temporal Cloud writes to, `region` is the AWS region that stream is in, and `role_name` is the IAM role Temporal Cloud assumes in order to write to it — supply the role's full ARN, because the Kinesis destination carries no separate field for your AWS account ID. The stream and the role must already exist and the role must trust Temporal Cloud's delivery principals; see the README prerequisites. Mutually exclusive with `pubsub` | <pre>object({<br/>    destination_uri = string<br/>    region          = string<br/>    role_name       = string<br/>  })</pre> | `null` | no |
| <a name="input_pubsub"></a> [pubsub](#input\_pubsub) | Google Cloud Pub/Sub destination. `topic_name` is the bare Pub/Sub topic name — not a `projects/<project>/topics/<topic>` path. The remaining attributes identify the service account in your project that Temporal Cloud impersonates to publish: supply `service_account_email`, or both `service_account_id` and `gcp_project_id`. Supplying the email alone is enough, because the other two are derived from it. The topic and the service account must already exist, with the IAM bindings described in the README prerequisites. Mutually exclusive with `kinesis` | <pre>object({<br/>    topic_name            = string<br/>    gcp_project_id        = optional(string)<br/>    service_account_email = optional(string)<br/>    service_account_id    = optional(string)<br/>  })</pre> | `null` | no |
| <a name="input_sink_name"></a> [sink\_name](#input\_sink\_name) | Name of the audit log sink. Cannot be changed in place: editing it destroys the sink and creates a replacement, which interrupts audit log delivery for the whole account while that happens. Required unless `create_account_audit_log_sink` is `false` | `string` | `""` | no |
| <a name="input_timeouts"></a> [timeouts](#input\_timeouts) | Create and delete timeouts, as duration strings such as `30s` or `2h45m` | <pre>object({<br/>    create = optional(string)<br/>    delete = optional(string)<br/>  })</pre> | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_account_audit_log_sink_enabled"></a> [account\_audit\_log\_sink\_enabled](#output\_account\_audit\_log\_sink\_enabled) | Whether the sink is delivering audit logs. `false` means the sink exists but delivery is paused |
| <a name="output_account_audit_log_sink_id"></a> [account\_audit\_log\_sink\_id](#output\_account\_audit\_log\_sink\_id) | The unique identifier of the account audit log sink |
| <a name="output_account_audit_log_sink_kinesis"></a> [account\_audit\_log\_sink\_kinesis](#output\_account\_audit\_log\_sink\_kinesis) | The resolved Amazon Kinesis destination configuration. `null` when the sink delivers to Pub/Sub or does not exist |
| <a name="output_account_audit_log_sink_name"></a> [account\_audit\_log\_sink\_name](#output\_account\_audit\_log\_sink\_name) | The name of the account audit log sink |
| <a name="output_account_audit_log_sink_pubsub"></a> [account\_audit\_log\_sink\_pubsub](#output\_account\_audit\_log\_sink\_pubsub) | The resolved Google Cloud Pub/Sub destination configuration, including the project, service account email and service account ID Temporal Cloud selected when they were not supplied. `null` when the sink delivers to Kinesis or does not exist |
<!-- END_TF_DOCS -->

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the development workflow, how the test layers are arranged,
and why this module has no applying test.

## License

Apache-2.0 licensed. See [LICENSE](LICENSE).
