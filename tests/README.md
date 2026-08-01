# Tests

Not usage examples — see [examples/](../examples) for those.

| Path | Runs on | Credentials |
| --- | --- | --- |
| `local/` | every pull request | no |
| `*.tftest.hcl` | on demand, weekly | **yes** |
| `setup/` | helper for `*.tftest.hcl` | no |
| `liveness/` | before the apply tests | **yes** |
| `orphan-check/` | after the apply tests | **yes** |

`local/` passes every module input and references every output, so `terraform validate` fails there as
soon as the variable surface changes.

## No test creates an audit log sink

This is the significant gap in this module's coverage and it is deliberate. Two reasons, in order of
weight:

1. **Creating a sink mutates account-wide compliance state.** Temporal Cloud presents a single Audit
   Log Integration per account. A test that creates one does not add an isolated resource alongside
   the account's real configuration — it *is* the account's configuration, replacing whatever was
   there and redirecting the account's audit trail for the duration of the run. Teardown then
   deletes it, leaving the account with no audit logging at all rather than what it had before.
   There is no scoping mechanism that would confine the blast radius: no per-namespace variant, no
   test mode. For any account that someone relies on, that is unacceptable regardless of how
   carefully the test is written, and it is why no amount of extra infrastructure would make the
   current test account a valid target.

2. **It needs real cloud infrastructure the test account does not have.** For Kinesis: a data stream,
   plus an IAM role in an AWS account whose trust policy names Temporal Cloud's delivery principals
   and carries the `sts:ExternalId` Temporal issues. For Pub/Sub: a topic, a service account,
   `roles/pubsub.publisher` on the topic and `roles/iam.serviceAccountTokenCreator` granted to
   Temporal's service accounts. The root README covers both. None of this can be stood up from within
   `terraform test`, and the external ID and Temporal service account addresses are only available
   through the Temporal Cloud UI.

A permanently-red test would be worse than the gap, so there is none.

## External access required to make this suite real

The full list of what a maintainer would have to hold before a sink could be created by an automated
test. None of it can be stood up from inside `terraform test`, and two items are obtainable only
through the Temporal Cloud UI.

**Temporal Cloud**

1. A **dedicated, disposable account** whose audit log nobody depends on. Reason 1 above makes this
   non-negotiable: not a shared or production account, and not the account the rest of this module
   family tests against. This is the hard blocker — no amount of cloud infrastructure substitutes
   for it.
2. An API key for that account belonging to an **Account Owner or Global Administrator**. Audit log
   configuration is an account-level setting.
3. For Kinesis, the **`sts:ExternalId` value Temporal issues to that account**. Not published and not
   exposed by any API; the Cloud UI hands over a CloudFormation template prefilled with it.
4. For Pub/Sub, the **addresses of Temporal's own service accounts**, which need
   `roles/iam.serviceAccountTokenCreator` on your service account. Also unpublished, also UI-only,
   and account-specific.

**Amazon Kinesis** — standing permanently, created out of band and referenced by ARN, not created by
the test:

1. A **Kinesis data stream**; `kinesis.destination_uri` takes its ARN.
2. An **IAM role** whose trust policy names Temporal Cloud's audit log delivery principals with the
   `sts:ExternalId` condition from item 3, and whose permissions policy allows `kinesis:PutRecord`,
   `kinesis:PutRecords`, `kinesis:DescribeStreamSummary` and `kinesis:UpdateShardCount` on that
   stream. Do not hand-write it: Temporal publishes
   [`iam-role-for-temporal-audit-logs.yaml`](https://temporal-auditlogs-config.s3.us-west-2.amazonaws.com/cloudformation/iam-role-for-temporal-audit-logs.yaml),
   which is the authoritative source for the current principal list. The root
   [README](../README.md) covers this in full.

**Google Cloud Pub/Sub** — likewise standing permanently, referenced by email:

1. A **Pub/Sub topic**; `pubsub.topic_name` takes its bare name.
2. A **service account in the same project**, with `roles/pubsub.publisher` on the topic and
   `roles/iam.serviceAccountTokenCreator` granted to Temporal's service accounts from item 4.
   Temporal maintains
   [`terraform-modules//modules/auditlog-sa`](https://github.com/temporalio/terraform-modules/tree/main/modules/auditlog-sa)
   for exactly this.

**Then, in this repository:** supply the destination identifiers as test variables, since they are
account-specific. `setup/` already generates a unique `sink_name`, so it does not need rebuilding —
`sink_name` cannot be changed in place, which is why a fixed name would be awkward.

### What stays unverifiable until that access exists

- **That Temporal Cloud accepts any sink configuration.** No test reaches the create path.
- **Which form `role_name` takes.** The provider's example uses a full ARN, Temporal's CloudFormation
  template uses a bare name, Temporal documents neither, and so the module enforces neither. Only an
  apply settles it.
- **Any value the API returns.** Every assertion is on a `try()` fallback or a rejected plan, so
  `account_audit_log_sink_id`, `_kinesis` and `_pubsub` are unproven beyond their fallbacks — in
  particular the Pub/Sub attributes Temporal Cloud *derives* from the email are never observed.
- **`enabled` and `timeouts` end to end.** `local/` proves they type-check and nothing more.

## What the test files do cover

| File | Covers | Creates |
| --- | --- | --- |
| `disabled.tftest.hcl` | `create_account_audit_log_sink = false` declares no resource and every output falls back through `try()` | nothing (applies an empty plan) |
| `destination.tftest.hcl` | Every plan-time rule, at `command = plan`: exactly one destination, the Kinesis ARN and non-empty field checks, the bare Pub/Sub topic name, and the Pub/Sub service account either/or | nothing |

Neither file creates a resource or changes account state. Both still configure the provider, which is
why they need `TEMPORAL_CLOUD_API_KEY`.

Each case in `destination.tftest.hcl` is aimed at exactly one rule and leaves the rest satisfied, so
neutralising any single rule turns exactly one run block red. `rejects_empty_kinesis_fields` empties
`region` and `role_name` rather than `destination_uri` for that reason: an empty URI also fails the
`arn:` rule, which would leave the block green even with the non-empty rule deleted.

`destination.tftest.hcl` is worth more than it looks. The Pub/Sub service account rule in particular is
invisible in the provider schema — all three attributes are optional — and omitting them all fails at
apply with `Missing Service Account Configuration`. That case is covered here at plan time.

## Running them

```bash
export TEMPORAL_CLOUD_API_KEY="<key for a scratch account>"
terraform init
terraform test -verbose
```

Without a key every run block is skipped, which is a cheap way to confirm the files parse:

```text
Failure! 0 passed, 0 failed, 8 skipped.
```

## Cleaning up leftovers

There is nothing to clean up: the suite creates no sink. `scripts/check-orphans.sh` still runs in CI
and says exactly that.

It becomes a real check when someone creates a sink by hand. Pass the name:

```bash
scripts/check-orphans.sh audit-logs
```

The provider offers no data source that **enumerates** audit log sinks — only
`temporalcloud_account_audit_log_sink`, which requires a name — so a nameless sweep of the account is
not possible, and `orphan-check/` is count-gated on the name for that reason. That data source also
fails rather than returning an empty result when the sink is absent, so the script reads terraform's
exit status as well as its outputs and prints the error instead of claiming the account is clean.

Deleting a leftover sink stops audit logging for the whole account. Confirm no live configuration owns
it first.

[CONTRIBUTING.md](../CONTRIBUTING.md) explains why the layers are split this way.
