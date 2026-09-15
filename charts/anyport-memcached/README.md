# anyport-memcached

The chart behind the **Memcached** entry in Anyport's managed-services catalog. Users never run
this themselves — `InstallPlugin` provisions it through a `HelmApp` and the console renders the
one choice (size) that maps onto its values.

## Why a first-party chart

The same reasons as `anyport-redis`: Bitnami's chart is a dead pin, and the console pushes flat
`--set` scalars, which this chart's value shape is designed for. Memcached itself is a single
static binary with three flags worth setting, so there is not much chart to be third-party about.

## No authentication, on purpose

Memcached has no credential in the shape client libraries expect: the ASCII authentication mode
(`-Y`) is supported by almost none of them, and SASL needs a build most images do not ship. The
boundary this service relies on is the project namespace's NetworkPolicy baseline
(docs/network-isolation), under which nothing outside the project can open a connection to it.
That is the same stance as every deployment of Memcached anywhere, made explicit.

## One process, on purpose

Memcached does not replicate. Clients scale it by being handed *every* server address and
hashing keys across them, which is a different connection shape from the one host the Connect
tab promises. `replicaCount` exists so the platform can pause the service by scaling to zero,
and is read as-is so that 0 is honoured — a `default 1` would turn a pause into a lie.

## Sizing

`memoryMB` is what the daemon may hold (`-m`) and is kept below the container's memory limit;
the difference is the process's own overhead. The catalog's size presets set both together
(`plugins/catalog.go`, `memcachedSizePresets`).

## Releasing

Published to `oci://ghcr.io/anyport-labs/anyport-memcached` by the release workflow, in lockstep
with the agent chart, which also rewrites `memcachedChartVersion` in the catalog. Never edit an
already-published version in place.
