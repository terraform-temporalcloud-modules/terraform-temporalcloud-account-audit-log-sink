# Amazon Kinesis audit log sink example

Configuration in this directory points a Temporal Cloud account's audit log at a Kinesis data stream
in your AWS account.

**This changes account-wide state.** Temporal Cloud's UI exposes a single Audit Log Integration per
account, so applying this replaces whatever that account was pointed at, and `terraform destroy` stops
audit logging for the whole account rather than just for this configuration. Read
[the module README](../../README.md#the-sink-is-account-wide) before running it against an account
anyone depends on.

## Prerequisites

Everything below lives in **your** AWS account and must exist before you apply. Only the Temporal Cloud
side is managed here.

1. **A Kinesis data stream.** Note its ARN — that is what `kinesis_stream_arn` takes, not the bare
   stream name.
2. **An IAM role Temporal Cloud can assume**, with:
   - a **trust policy** whose principals are Temporal Cloud's audit log delivery roles — there are
     several, one per Temporal-owned AWS account, and Temporal selects among them — and an
     `sts:ExternalId` condition set to the external ID Temporal gives you.
   - a **permissions policy** on the stream allowing `kinesis:PutRecord`, `kinesis:PutRecords`,
     `kinesis:DescribeStreamSummary` and `kinesis:UpdateShardCount`.

   Temporal publishes a CloudFormation template that creates exactly this role, and it is the
   authoritative source for the current principal list:
   [`iam-role-for-temporal-audit-logs.yaml`](https://temporal-auditlogs-config.s3.us-west-2.amazonaws.com/cloudformation/iam-role-for-temporal-audit-logs.yaml),
   linked from [Set up Audit Logging with AWS Kinesis](https://docs.temporal.io/cloud/audit-logs-aws).
   Use it rather than hand-writing the trust policy: the principal list is Temporal's to change, and
   the Temporal Cloud UI generates a copy of the template prefilled with your external ID.

   `kinesis:UpdateShardCount` usually draws a question in security review. It is in Temporal's own
   template: Temporal scales the stream to match audit log volume.
3. **Account Owner or Global Administrator** on the Temporal Cloud account. Lesser roles cannot
   configure an Audit Log Integration.

The prerequisites are not created here on purpose. Baking Temporal's delivery-role ARNs into a
published example would leave consumers with a stale trust policy the day Temporal rotates them, and
the external ID has no default that could be guessed.

## Usage

```bash
export TEMPORAL_CLOUD_API_KEY="<your-api-key>"

terraform init
terraform plan \
  -var 'kinesis_stream_arn=arn:aws:kinesis:us-east-1:111122223333:stream/temporal-audit-logs' \
  -var 'kinesis_region=us-east-1' \
  -var 'kinesis_role_arn=arn:aws:iam::111122223333:role/Temporal-Cloud-Log-Writer'
terraform apply
```

Records begin arriving within about ten minutes of a successful apply. Kinesis rate limits apply — the
stream has to keep up with the account's control-plane event volume.

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
| <a name="input_kinesis_region"></a> [kinesis\_region](#input\_kinesis\_region) | AWS region the Kinesis stream is in, for example `us-east-1` | `string` | n/a | yes |
| <a name="input_kinesis_role_arn"></a> [kinesis\_role\_arn](#input\_kinesis\_role\_arn) | ARN of the IAM role Temporal Cloud assumes to write to the stream, for example `arn:aws:iam::111122223333:role/Temporal-Cloud-Log-Writer` | `string` | n/a | yes |
| <a name="input_kinesis_stream_arn"></a> [kinesis\_stream\_arn](#input\_kinesis\_stream\_arn) | ARN of the Kinesis data stream Temporal Cloud writes audit logs to, for example `arn:aws:kinesis:us-east-1:111122223333:stream/temporal-audit-logs` | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_account_audit_log_sink_enabled"></a> [account\_audit\_log\_sink\_enabled](#output\_account\_audit\_log\_sink\_enabled) | Whether the sink is delivering audit logs |
| <a name="output_account_audit_log_sink_id"></a> [account\_audit\_log\_sink\_id](#output\_account\_audit\_log\_sink\_id) | The unique identifier of the account audit log sink |
| <a name="output_account_audit_log_sink_kinesis"></a> [account\_audit\_log\_sink\_kinesis](#output\_account\_audit\_log\_sink\_kinesis) | The Kinesis destination Temporal Cloud recorded for the sink |
| <a name="output_account_audit_log_sink_name"></a> [account\_audit\_log\_sink\_name](#output\_account\_audit\_log\_sink\_name) | The name of the account audit log sink |
<!-- END_TF_DOCS -->

## License

Apache-2.0 licensed. See [LICENSE](../../LICENSE).
