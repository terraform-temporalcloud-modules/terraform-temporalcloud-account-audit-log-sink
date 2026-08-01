# Generates a unique sink name per test run.
#
# `sink_name` cannot be changed once set, and an account holds a single audit log
# sink, so a fixed name would collide with anything a previous — or concurrent —
# run left behind and could not simply be renamed out of the way.
#
# Nothing in tests/*.tftest.hcl consumes this yet: creating a sink needs real
# Kinesis or Pub/Sub infrastructure and mutates account-wide compliance state, so
# no applying test exists. See ../README.md. The fixture is kept so a maintainer
# with a dedicated account can add one without rebuilding it.
resource "random_pet" "this" {
  length    = 2
  separator = "-"
}
