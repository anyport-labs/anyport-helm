# anyport-tei

The chart behind the **Text embeddings** entry in Anyport's managed-services catalog: Hugging
Face [Text Embeddings Inference](https://github.com/huggingface/text-embeddings-inference) serving
one model. Users never run this themselves — `InstallPlugin` provisions it through a `HelmApp` and
the console renders the few choices (model, size, architecture, storage) that map onto its values.

## Why a first-party chart

Hugging Face publishes no Helm chart for TEI. The console also pushes flat `--set` scalars, which
this chart's value shape is designed for, and TEI itself is one binary configured entirely through
its environment.

## What it serves

Whatever the model is. An embedding model answers `/embed` and the OpenAI-compatible
`/v1/embeddings`; a reranker answers `/rerank`; a sequence classifier answers `/predict`. TEI
loads one model per process, so a second model is a second service. The OpenAI SDKs take
`<address>/v1` as their base URL and append `/embeddings` themselves; the `model` they send is
not checked (TEI only logs a warning when it differs from the served model).

## Architecture

The CPU build is published as two single-architecture tags, not one multi-arch manifest:
`cpu-<version>` is amd64 only, and `cpu-arm64-<version>` is arm64 only (from 1.9 on).
`image.arch` picks the tag and pins the pod to `kubernetes.io/arch` nodes of that architecture,
overriding any `nodeSelector` entry for the same key. The chart refuses to render with any other
value.

GPU builds are not offered: Hugging Face publishes one tag per CUDA compute capability (`turing-`,
`86-`, `89-`, `hopper-`, ...), so the right image depends on the card in the node.

## Credentials

The platform mints the API key and writes it to `tei-auth-<instance>` before provisioning;
`auth.existingSecret` names that secret and the chart hands it to the server as the `API_KEY`
environment variable, which TEI reads natively — never on the command line. With a key set, every
inference route (`/embed`, `/v1/embeddings`, `/rerank`, `/info`, ...) answers 401 without
`Authorization: Bearer <key>`, while `/health`, `/metrics` and the OpenAPI docs at `/docs` stay
open — which is what lets the probes run without the key. The chart refuses to render without a
secret name rather than start a server that answers anyone.

## Storage and start-up

The model is downloaded from the Hugging Face Hub when the pod starts, into the Hub cache on the
`data` volume (`HUGGINGFACE_HUB_CACHE`), so the cluster needs internet access the first time and a
restart afterwards is seconds. The server only opens its port once the model is loaded and warmed
up, so the startup probe allows 30 minutes for a large model over slow egress. The claim is a
`volumeClaimTemplate` named `data`, so the PVC is `data-<instance>-0`; the catalog's StorageSpec
names it for teardown, and `persistentVolumeClaimRetentionPolicy` covers a release removed
outside Anyport.

## Security context

The image declares no user. The chart runs it as uid 1000 on a read-only root filesystem with every
capability dropped, on port 8080 rather than the image's 80. The only writable paths are the cache
volume and an `emptyDir` at `/tmp`, where the backend's unix socket lives. Verified against
`cpu-1.9.4` and `cpu-arm64-1.9.4`.

## Sizing

Inference is CPU-bound and the model's weights sit in memory, so memory follows the model and CPU
decides throughput. `threads` sets both the inference threads and the tokenizer workers; the
image's defaults (8 threads, one tokenizer per host core) only throttle a pod with a small CPU
limit, so the catalog sets it to the limit (`plugins/tei.go`, `teiSizePresets`).

## Releasing

Published to `oci://ghcr.io/anyport-labs/anyport-tei` by the release workflow, in lockstep with the
agent chart, which also rewrites `teiChartVersion` in the catalog. Never edit an
already-published version in place.
