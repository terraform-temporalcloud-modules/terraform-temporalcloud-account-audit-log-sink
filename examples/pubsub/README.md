# Google Cloud Pub/Sub audit log sink example

Configuration in this directory points a Temporal Cloud account's audit log at a Pub/Sub topic in your
Google Cloud project.

**This changes account-wide state.** Temporal Cloud's UI exposes a single Audit Log Integration per
account, so applying this replaces whatever that account was pointed at, and `terraform destroy` stops
audit logging for the whole account rather than just for this configuration. Read
[the module README](../../README.md#the-sink-is-account-wide) before running it against an account
anyone depends on.

## Prerequisites

Everything below lives in **your** Google Cloud project and must exist before you apply. Only the
Temporal Cloud side is managed here.

1. **A Pub/Sub topic.** Note its bare name — `pubsub_topic_name` takes `temporal-audit-logs`, not
   `projects/example-project/topics/temporal-audit-logs`.
2. **A service account in the same project.** Temporal Cloud does not publish as itself; it
   impersonates this account. Two IAM bindings are needed:
   - `roles/pubsub.publisher` **on the topic**, granted to your service account.
   - `roles/iam.serviceAccountTokenCreator` **on your service account**, granted to Temporal Cloud's
     service accounts. There are several, and their addresses are not published — the Temporal Cloud
     UI shows the ones for your account.

   Temporal maintains a Terraform module that creates all three pieces:
   [`temporalio/terraform-modules//modules/auditlog-sa`](https://github.com/temporalio/terraform-modules/tree/main/modules/auditlog-sa).
   It takes the Temporal service account addresses as a required input, so you still need them from
   the UI.
3. **Account Owner or Global Administrator** on the Temporal Cloud account. Lesser roles cannot
   configure an Audit Log Integration.

Note that [the Pub/Sub setup page](https://docs.temporal.io/cloud/audit-logs-gcp) says the
prerequisites can be skipped "if you use Terraform for your deployment". That refers to the UI's
"Deploy with Terraform" button, which emits the module linked above. A configuration that calls
`temporalcloud_account_audit_log_sink` directly — including this one — still needs the topic, the
service account and both bindings.

## The service account attributes are an either/or

`service_account_email`, `service_account_id` and `gcp_project_id` are each optional in the provider
schema, which reads as "omit them and Temporal Cloud works it out". It does not. Supply either the
email on its own, or both the ID and the project. Omitting all three fails with:

```text
Error: Missing Service Account Configuration
Either provide both service_account_id and gcp_project_id, or provide a valid
service_account_email
```

This module checks for that at plan time so the failure names the variable rather than arriving from
the API.

## Usage

```bash
export TEMPORAL_CLOUD_API_KEY="<your-api-key>"

terraform init
terraform plan \
  -var 'pubsub_topic_name=temporal-audit-logs' \
  -var 'pubsub_service_account_email=temporal-audit@example-project.iam.gserviceaccount.com'
terraform apply
```

Messages begin arriving within about ten minutes of a successful apply.

Run `terraform destroy` when you no longer need it, remembering that doing so stops audit logging for
the entire Temporal Cloud account. To pause delivery reversibly instead, set `enabled = false` and
apply.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.7 |
| <a name="requirement_temporalcloud"></a> [temporalcloud](#requirement\_temporalcloud) | >= 1.6.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_audit_log_sink"></a> [audit\_log\_sink](#module\_audit\_log\_sink) | terraform-temporalcloud-modules/account-audit-log-sink/temporalcloud | ~> 1.0 |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_pubsub_service_account_email"></a> [pubsub\_service\_account\_email](#input\_pubsub\_service\_account\_email) | Email of the service account in your project that Temporal Cloud impersonates to publish, for example `temporal-audit@example-project.iam.gserviceaccount.com` | `string` | n/a | yes |
| <a name="input_pubsub_topic_name"></a> [pubsub\_topic\_name](#input\_pubsub\_topic\_name) | Bare name of the Pub/Sub topic Temporal Cloud publishes audit logs to, for example `temporal-audit-logs`. Not a `projects/<project>/topics/<topic>` path | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_account_audit_log_sink_enabled"></a> [account\_audit\_log\_sink\_enabled](#output\_account\_audit\_log\_sink\_enabled) | Whether the sink is delivering audit logs |
| <a name="output_account_audit_log_sink_id"></a> [account\_audit\_log\_sink\_id](#output\_account\_audit\_log\_sink\_id) | The unique identifier of the account audit log sink |
| <a name="output_account_audit_log_sink_name"></a> [account\_audit\_log\_sink\_name](#output\_account\_audit\_log\_sink\_name) | The name of the account audit log sink |
| <a name="output_account_audit_log_sink_pubsub"></a> [account\_audit\_log\_sink\_pubsub](#output\_account\_audit\_log\_sink\_pubsub) | The Pub/Sub destination Temporal Cloud recorded for the sink, including the service account ID and project it derived from the email |
<!-- END_TF_DOCS -->

## License

Apache-2.0 licensed. See [LICENSE](../../LICENSE).
