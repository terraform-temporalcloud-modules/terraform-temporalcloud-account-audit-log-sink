# Local regression coverage

This directory is **not an example** — do not copy it. See [examples/](../../examples) for usage.

## Why it exists

The `examples/` directories source the *published* module from the Terraform Registry so they are
copy-pasteable for consumers. The tradeoff is that they validate the last release rather than the code
in this repository: a renamed or removed variable would pass CI unnoticed.

This directory sources the module by relative path (`../../`) and passes **every** input, so
`terraform validate` fails here the moment the variable surface changes incompatibly. It covers:

| Module call | What it proves |
| --- | --- |
| `all_inputs_kinesis` | Every input is still valid, with the Kinesis destination |
| `all_inputs_pubsub` | The Pub/Sub destination, with all three service account attributes supplied |
| `minimal` | The module works with a name, a topic and a service account email |
| `disabled` | `create_account_audit_log_sink = false` produces no resources, every output falls back through `try()`, and the exactly-one-destination precondition stays inert |
| `wrapper` | `wrappers/` accepts `defaults` / `items` and passes them through, including an item that overrides the shared Kinesis default with Pub/Sub |

`outputs.tf` references every output, so a broken output expression fails here rather than in a
consumer's plan.

Note that the enabled calls above would all contend for the same account audit log sink if they were
ever applied. They are not: this directory is only ever validated. It is also part of why there is no
applying test — see [../README.md](../README.md).

## Maintenance

When you add a variable to the root module, **add it here in the same PR** — the `wrapper-sync` hook
guards `wrappers/main.tf`, but nothing else would catch an untested input. Adding it to `examples/` has
to wait until the next release publishes it.

CI discovers this directory automatically: the workflow globs for any directory containing a `.tf`
file with `required_version`, so no matrix entry needs maintaining.

## Running it

```bash
terraform init
terraform validate
```

`terraform plan` additionally requires `TEMPORAL_CLOUD_API_KEY`, because the provider authenticates at
configure time even when no resources would be created.
