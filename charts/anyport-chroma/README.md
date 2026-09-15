# anyport-chroma

The chart behind the **Chroma** entry in Anyport's managed-services catalog. Users never run this
themselves — `InstallPlugin` provisions it through a `HelmApp` and the console renders the
choices (size, storage, version) that map onto its values.

## Why a first-party chart

Chroma publishes no chart. The one community chart in circulation was built around the pre-1.0
Python server: its authentication values set `CHROMA_SERVER_AUTHN_*`, which the 1.x Rust server
ignores, and its defaults describe a process that no longer exists. The console also pushes flat
`--set` scalars, which this chart's value shape is designed for. Chroma 1.x is a single static
binary reading one config file, so there is not much chart to be third-party about.

## No authentication, on purpose

Since 1.0 the single-node server has no authentication provider: the server is constructed with
the no-op authorizer, and the `CHROMA_SERVER_AUTHN_CREDENTIALS` / `CHROMA_SERVER_AUTHN_PROVIDER`
environment of the Python server is read by nothing (Chroma's own migration notes say so, and the
1.5.9 source confirms it). Chroma's advice is network-level control, which is what this chart
relies on: the project namespace's NetworkPolicy baseline (docs/network-isolation), under which
nothing outside the project can open a connection to it. The catalog entry therefore mints no
credential and offers no domain.

## One node, on purpose

The single-node server keeps its catalogue in an embedded SQLite database and every collection's
HNSW index on the same volume; there is no replication. `replicaCount` exists so the platform can
pause the service by scaling to zero, and is read as-is so that 0 is honoured — a `default 1`
would turn a pause into a lie.

## Hardening, verified

The image sets no user. This chart runs it as uid 1000 on a read-only root filesystem with every
capability dropped, which was exercised against `chromadb/chroma:1.5.9`: create a collection,
add, query, restart, query again. Two things it needs and gets: `fsGroup` so the data volume is
writable, and an `emptyDir` at `/tmp` — without a temp directory SQLite fails on first boot with
`disk I/O error`.

## Values that matter

| Value | Default | Notes |
| --- | --- | --- |
| `image.tag` | `1.5.9` | Exact release; Chroma publishes no floating series tag |
| `persistence.size` | `10Gi` | Backs a `volumeClaimTemplate`, so immutable once created |
| `persistence.mountPath` | `/data` | Also handed to the server as `CHROMA_PERSIST_PATH` |
| `resources` | 1Gi / 250m–1 CPU | The catalog's size presets set these (`plugins/chroma.go`) |

## Releasing

Published to `oci://ghcr.io/anyport-labs/anyport-chroma` by the release workflow, in lockstep
with the agent chart, which also rewrites `chromaChartVersion` in `plugins/chroma.go`. Never edit
an already-published version in place.
