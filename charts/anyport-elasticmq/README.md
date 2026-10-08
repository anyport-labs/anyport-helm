# anyport-elasticmq

The chart behind the **SQS queue** entry in Anyport's managed-services catalog. Users never run
this themselves — `InstallPlugin` provisions it through a `HelmApp` and the console renders the
choices (size, queues, storage) that map onto its values.

## Why a first-party chart

ElasticMQ publishes no chart, and it is configured by a single HOCON file rather than by
environment. The console pushes flat `--set` scalars, so this chart renders that file from
scalar values (queue names arrive one index at a time, `queues[0]=orders`) and mounts it over the
image's own `/opt/elasticmq.conf`, which the image's entrypoint already names.

## No authentication, on purpose

ElasticMQ accepts any access key and never verifies a request signature. The chart relies on the
project namespace's NetworkPolicy baseline (docs/network-isolation), under which nothing outside
the project can open a connection to it. The catalog entry therefore offers no domain and no
public port, and hands bound apps a dummy key pair only because every AWS SDK refuses to sign
without one.

## Durable by default

ElasticMQ serves from memory. With `messages-storage` on, which this chart always sets, every
queue and message change is journalled to an H2 database on the volume and replayed on start.
Verified against `softwaremill/elasticmq-native:1.7.1`: messages sent, consumed and deleted
survive both a clean restart and a SIGKILL, and a queue created through the API comes back with
its messages.

Two consequences worth knowing:

- **The backlog has to fit in memory**, journal or not. When the heap fills, the server exits
  with `OutOfMemoryError`; on restart it replays the same journal into the same heap. Size the
  service for the largest backlog you expect.
- **`PurgeQueue` is not journalled** in 1.7.1: a purged queue is empty until the next restart,
  then the purged messages come back. Delete messages individually if that matters.

## One node, on purpose

ElasticMQ has no clustering, so `replicaCount` exists only for the platform to pause the service
by scaling to zero. It is read as-is so that 0 is honoured — a `default 1` would turn a pause
into a lie.

## Hardening, verified

The image sets no user. This chart runs it as uid 1000 on a read-only root filesystem with every
capability dropped, which was exercised against 1.7.1 with the config this chart renders. The
native binary needs no writable path besides the data volume, which `fsGroup` makes writable. It
sizes its heap to about 80% of the container's memory limit on its own, so no `-Xmx` is passed.

## Queue URLs

`node-address.host` is `"*"`, so the server builds each queue URL from the host the request came
in on: `http://<release>.<namespace>.svc:9324/000000000000/<queue>` in-cluster, and a reachable
`localhost` URL through a port-forward.

## Values that matter

| Value | Default | Notes |
| --- | --- | --- |
| `image.tag` | `1.7.1` | Exact release; there is no floating series tag |
| `queues` | `[]` | Created at start; `.fifo` names become FIFO queues |
| `aws.region` / `aws.accountId` | `us-east-1` / `000000000000` | Stamped into queue ARNs and URLs |
| `sqsLimits` | `strict` | Refuses what real SQS refuses |
| `persistence.size` | `5Gi` | Backs a `volumeClaimTemplate`, so immutable once created |
| `resources` | 256Mi / 50m–500m CPU | The catalog's size presets set these (`plugins/elasticmq.go`) |

## Releasing

Published to `oci://ghcr.io/anyport-labs/anyport-elasticmq` by the release workflow, in lockstep
with the agent chart, which also rewrites `elasticmqChartVersion` in `plugins/elasticmq.go`. Never
edit an already-published version in place.
