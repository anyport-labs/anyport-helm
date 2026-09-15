# anyport-typesense

The chart behind the **Typesense** entry in Anyport's managed-services catalog. Users never run
this themselves — `InstallPlugin` provisions it through a `HelmApp` and the console renders the
few choices (size, storage, version) that map onto its values.

## Why a first-party chart

Typesense publishes no Helm chart: its own documentation deploys with a raw manifest, and the
community charts are single-maintainer and stale. The console also pushes flat `--set` scalars,
which this chart's value shape is designed for. Typesense itself is one static binary with a
handful of flags, so there is not much chart to be third-party about.

## Credentials

The platform mints the API key and writes it to `typesense-auth-<instance>` before provisioning;
`auth.existingSecret` names that secret and the chart hands it to the server as the
`TYPESENSE_API_KEY` environment variable, which Typesense reads natively. It is never passed as
`--api-key`, so the credential is in no argv, pod spec, or Helm value. The chart refuses to
render without a secret name rather than start an unauthenticated server.

## One node, on purpose

Typesense clusters through Raft with a peers file naming every member, which is a different
install with a different failure model from this one. `replicaCount` exists so the platform can
pause the service by scaling to zero, and is read as-is so that 0 is honoured — a `default 1`
would turn a pause into a lie.

## Storage

Always a volume. Typesense serves from an in-memory index but writes everything to RocksDB under
`/data`, and rebuilds the index from there on every start — so the volume is the data, and the
startup probe is generous because a large collection takes minutes to load. The claim is a
`volumeClaimTemplate` named `data`, so the PVC is `data-<instance>-0`; the catalog's StorageSpec
names it for teardown, and `persistentVolumeClaimRetentionPolicy` covers a release removed
outside Anyport.

## Sizing

The index lives in memory, so memory is the knob and CPU follows it. Typesense's own guidance is
RAM of two to three times the size of the JSON you index. The catalog's size presets set the
request and limit together (`plugins/typesense.go`, `typesenseSizePresets`).

## Releasing

Published to `oci://ghcr.io/anyport-labs/anyport-typesense` by the release workflow, in lockstep
with the agent chart, which also rewrites `typesenseChartVersion` in the catalog. Never edit an
already-published version in place.
