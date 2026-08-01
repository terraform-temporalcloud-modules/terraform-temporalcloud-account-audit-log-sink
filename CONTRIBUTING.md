# Contributing

## Prerequisites

```bash
brew install pre-commit terraform-docs
brew install terraform-linters/tap/tflint
pre-commit install
```

Local tool versions must match the pins in
[`.github/workflows/pre-commit.yml`](.github/workflows/pre-commit.yml). terraform-docs changed its
markdown table style after v0.20.0, so a mismatch makes CI reject README tables that were generated
correctly on your machine. When you bump one side, bump the other in the same pull request.

## The gate

```bash
pre-commit run -a
```

This is what CI runs: `terraform fmt`, `terraform-docs`, `tflint`, `terraform validate`, plus two local
checks described below. Expect the first run after a change to *modify* files — terraform-docs rewrites
the README tables. Re-run until clean; it should pass twice in a row.

## Test layers

| Path | Runs on | Credentials | Proves |
| --- | --- | --- | --- |
| `examples/*` | every PR | no | The documented usage still type-checks against this code |
| `tests/local/` | every PR | no | Every input and output is still valid |
| `tests/*.tftest.hcl` | on demand, weekly | **yes** | The plan-time rules hold against a real provider |

`terraform validate` is not a test: it never executes anything and never contacts the API. Only the
apply layer can catch the API rejecting a configuration that looks valid.

`terraform plan` is not a usable middle ground for the API's own behaviour, because the provider
authenticates when it initialises and so needs a real key even for a plan that would create nothing.

### Why there is no applying test

Unusually for this module family, `tests/*.tftest.hcl` creates nothing. A Temporal Cloud account holds
a single Audit Log Integration, so a test that creates a sink replaces the account's real audit log
configuration for the duration of the run and then deletes it, leaving the account with none. The
blast radius is the whole account and there is no way to scope it down. Needing a real Kinesis stream
or Pub/Sub topic with Temporal-specific IAM is the second reason, and the lesser one.

[`tests/README.md`](tests/README.md) sets out what a maintainer would need in order to add one — a
dedicated disposable account, above all. A permanently-red test would be worse than an honest gap.

What the test files do cover is every plan-time rule, at `command = plan`, which is free of both
problems.

### Why examples are validated indirectly

`examples/*` source the **published** module so consumers can copy them verbatim from the Terraform
Registry. Validating them as written would check the last release rather than the working tree, which
would mean a module change and its example update could never land in the same pull request.

[`scripts/validate-examples.sh`](scripts/validate-examples.sh) resolves this: it copies each example to
a temporary directory, rewrites the registry source to a path to the repository root, and validates the
copy. Tracked files are never modified. `terraform_validate` excludes `examples/`, and the
`examples-validate` hook covers them instead.

One consequence: examples are validated only on the maximum supported Terraform version, because the
exclusion also removes them from the minimum-version matrix jobs. The root module and `tests/local/`
are still checked against the minimum, which is what `required_version` asserts.

### Why `wrappers/` is hand-maintained

The upstream `terraform_wrapper_module_for_each` pre-commit hook is not enabled. It hardcodes
`terraform-aws-modules` and `aws` in the source addresses it generates, and it overwrites
`wrappers/README.md` on every run with an Amazon S3 example whose inputs do not exist in this module.
It offers no way to skip that file, so restoring a correct one leaves the gate permanently dirty.

[`scripts/check-wrapper-sync.sh`](scripts/check-wrapper-sync.sh) replaces the one useful thing the hook
did: it fails if a root variable is not passed through `wrappers/main.tf`. When you add a variable to
the root module, add the matching line to the wrapper in the same change.

## Provider behaviours the checks guard against

Each of these type-checks fine and would otherwise fail only at apply.

1. **Exactly one destination.** The provider applies `objectvalidator.ExactlyOneOf` across `kinesis`
   and `pubsub`, so it catches this too — but it reports against its own attribute paths. The module
   repeats the check as a resource precondition so the message names the module's variables and fires
   before anything reaches the provider.
2. **The Pub/Sub service account either/or.** `service_account_email`, `service_account_id` and
   `gcp_project_id` are each `Optional + Computed` in the schema, which reads as "omit them all and
   Temporal Cloud fills them in". The provider derives the ID and project from the email only when
   both are absent, and otherwise raises `Missing Service Account Configuration`. The module's
   `pubsub` validation catches the all-absent case at plan time.
3. **`sink_name` carries `RequiresReplace`.** Editing it destroys and recreates the sink rather than
   erroring, which for an account-wide compliance control is a much bigger deal than the plan diff
   suggests. Documented on the variable.
4. **`destination_uri` wants an ARN; `role_name`'s accepted form is genuinely unknown.** The provider
   parses neither and passes both through verbatim. `destination_uri` is unambiguous — the schema and
   Temporal's docs both call it the stream ARN — so the module checks it starts with `arn:`.
   `role_name` is not: the provider's registry example passes a full role ARN, while Temporal's
   CloudFormation template and Cloud UI take a bare role name, and Temporal documents neither as the
   contract. The module therefore does not pattern-check it, and the README says so rather than
   picking a side. If an apply test ever settles this, record the answer here.

### Why the exactly-one check is a precondition, not a variable validation

A `variable` validation cannot reference a second variable below Terraform 1.9, and this module's floor
is 1.5.7. Attaching the check to the resource also gives the behaviour we want for free: the resource
is count-gated, so with `create_account_audit_log_sink = false` there are no instances and the
precondition is never evaluated — which is correct, because a disabled module is not expected to have a
destination. `tests/disabled.tftest.hcl` covers that half and
`tests/destination.tftest.hcl` covers the other.

## Running the tests

```bash
export TEMPORAL_CLOUD_API_KEY="<key for a scratch account>"
terraform init
terraform test -verbose
```

Nothing is created, but the provider is still configured, so a key is required. Without one every run
block is skipped, which is a cheap way to check the test files parse:

```text
Failure! 0 passed, 0 failed, 8 skipped.
```

In CI they run from the **Apply Tests** workflow. Its first step is
[`scripts/check-api.sh`](scripts/check-api.sh), a liveness check that confirms the API answers and the
key is accepted, so a credentials problem fails immediately rather than surfacing later as something
that reads like a test failure.

Apply Tests is chained after Pre-Commit, and Release after Apply Tests, so a merge to main runs:

```text
push to main -> Pre-Commit -> Apply Tests -> Release
```

A release is therefore only cut from code that passed both the static gate and the tests. Any failure
in the chain stops it.

`scripts/check-orphans.sh` runs afterwards with `if: always()`. For this module it is a no-op by
default, because the suite creates nothing; [`tests/README.md`](tests/README.md) explains how to point
it at a sink created by hand, and why a nameless sweep of the account is not possible.

## Pull requests

Titles must be [conventional commits](https://www.conventionalcommits.org/) — `feat:`, `fix:`, `docs:`,
`ci:`, `chore:` — with a capitalised subject. Squash-merge makes the title the commit message, and
semantic-release derives the next version from it, so an invalid title silently breaks versioning. A
workflow enforces this.

`CHANGELOG.md` and tags are generated on merge. Never bump versions by hand.

If CI reports fewer checks than usual, check whether the pull request has merge conflicts: GitHub skips
`pull_request` workflows when it cannot compute a merge ref, with no failed check to show for it.
