# These identify infrastructure in your own AWS account, so they have no
# sensible defaults. The README in this directory covers how to create them.

variable "kinesis_stream_arn" {
  description = "ARN of the Kinesis data stream Temporal Cloud writes audit logs to, for example `arn:aws:kinesis:us-east-1:111122223333:stream/temporal-audit-logs`"
  type        = string
}

variable "kinesis_region" {
  description = "AWS region the Kinesis stream is in, for example `us-east-1`"
  type        = string
}

variable "kinesis_role_arn" {
  description = "IAM role Temporal Cloud assumes to write to the stream, as a full ARN following the provider's own example, for example `arn:aws:iam::111122223333:role/Temporal-Cloud-Log-Writer`. Temporal's CloudFormation template uses a bare role name instead and the accepted form is undocumented — if the role fails to resolve on create, try `Temporal-Cloud-Log-Writer`"
  type        = string
}
