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

### What a maintainer would need in order to add one

- A **dedicated, disposable Temporal Cloud account** whose audit log nobody depends on. Reason 1 makes
  this non-negotiable; it cannot be a shared or production account, nor the account the rest of this
  module family tests against.
- An API key for that account belonging to an **Account Owner or Global Administrator**.
- Either the AWS side (stream, role, external ID) or the GCP side (topic, service account, both IAM
  bindings) standing permanently, created out of band and referenced by ARN or email — not created by
  the test.
- The destination identifiers supplied as test variables, since they are account-specific.

`setup/` already generates a unique `sink_name` for that test, so it does not need rebuilding.
`sink_name` cannot be changed in place, which is exactly why a fixed name would be awkward.

## What the test files do cover

| File | Covers |
| --- | --- |
| `disabled.tftest.hcl` | `create_account_audit_log_sink = false` creates nothing and every output falls back through `try()` |
| `destination.tftest.hcl` | Every plan-time rule, at `command = plan`: exactly one destination, the Kinesis ARN and non-empty field checks, the bare Pub/Sub topic name, and the Pub/Sub service account either/or |

Neither file creates a resource or changes account state. Both still configure the provider, which is
why they need `TEMPORAL_CLOUD_API_KEY`.

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
