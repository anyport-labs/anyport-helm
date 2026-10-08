# anyport-speaches

The chart behind the **Speech to text** entry in Anyport's managed-services catalog. Users never
run this themselves — `InstallPlugin` provisions it through a `HelmApp` and the console renders
the choices (model, size, GPU, storage) that map onto its values.

[Speaches](https://github.com/speaches-ai/speaches) serves the OpenAI audio API — transcription
and translation on faster-whisper, speech on Kokoro and Piper — so an app talks to it with the
OpenAI SDK pointed at a different base URL.

## Why a first-party chart

Speaches publishes images and a compose file, no chart. The console also pushes flat `--set`
scalars, which this chart's value shape is designed for.

## Models are fetched before the server starts

Since 0.8 the server downloads nothing on its own: a transcription naming a model that is not on
disk is a 404 until someone calls `POST /v1/models/{id}`. 0.8.3 has no preload setting (the
unreleased 0.9 line adds one). So the `fetch-model` init container runs Speaches' own download
function for `model` against the same Hugging Face cache the server reads (`HF_HOME`, the volume):

- the pod is not ready until the model is on disk, so a bound app's first request works;
- a restart finds the files and makes no network call;
- a repository that is not a faster-whisper model fails the init container with a message naming
  it, instead of a server answering every transcription with 404.

Anything else — text-to-speech voices, a second whisper model — is added through the API and
lands on the same volume.

## Authentication

The platform mints the key into `auth.existingSecret`; the server reads it as `API_KEY`. With a
key set, every API route refuses a request without `Authorization: Bearer <key>` (403), `/health`
included — so the probes are exec probes that hand curl the header on stdin, keeping the key out
of the pod spec and out of argv. What answers without a key is FastAPI's `/docs` and
`/openapi.json` and the static assets of the realtime demo page; none of them reaches a model.

The Gradio UI is switched off (`ENABLE_UI=false`): it is mounted beside the API, outside the key
check, and calls the API with the server's own key — on, it would hand the service to anyone who
can reach the port.

## Hardening, verified

Run against `ghcr.io/speaches-ai/speaches:0.8.3-cpu` as uid 1000 on a read-only root filesystem
with every capability dropped: model fetch (and its offline no-op on restart), transcription
through the OpenAI SDK, a text-to-speech model downloaded through the API, and speech generated
with it. `/tmp` must be writable and must allow exec — text-to-speech unpacks espeak-ng's shared
library there and loads it; an `emptyDir` does both.

## Values that matter

| Value | Default | Notes |
| --- | --- | --- |
| `image.tag` | `0.8.3` | Rendered as `<tag>-cpu`, or `<tag>-cuda` with `gpu.enabled` |
| `model` | `Systran/faster-whisper-small` | Fetched by the init container; empty skips it |
| `gpu.enabled` | `false` | cuda image, one `nvidia.com/gpu`, and the usual GPU taint tolerated |
| `persistence.size` | `10Gi` | Backs a `volumeClaimTemplate`, so immutable once created |
| `resources` | 3Gi / 1–2 CPU | The catalog's size presets set these (`plugins/speaches.go`) |

## Releasing

Published to `oci://ghcr.io/anyport-labs/anyport-speaches` by the release workflow, in lockstep
with the agent chart, which also rewrites `speachesChartVersion` in `plugins/speaches.go`. Never
edit an already-published version in place.
