# anyport-helm

Helm charts for [Anyport](https://anyport.dev) — deploy the Anyport agent to connect your Kubernetes clusters to the Anyport console, plus the first-party charts the managed-services catalog installs.

This repo also hosts the [Anyport CLI](#cli) binaries, released under `cli/vX.Y.Z` tags.

## Contents

| Chart | Description |
|-------|-------------|
| [**agent**](charts/agent/) | Anyport agent and operator: runs in-cluster, syncs state to the console, and optionally serves validating/mutating webhooks. Includes CRDs for Clusters, Projects, Secrets, ContainerApps, HelmApps, Routes, BuildConfigs, BuildRuns and Tasks. Published as `anyport-agent-chart`. |
| [**anyport-redis**](charts/anyport-redis/) | Redis-compatible in-memory store (Valkey by default) behind the **Redis** entry in the managed-services catalog. Installed by the console, not by hand. |
| [**anyport-rabbitmq**](charts/anyport-rabbitmq/) | Single-node RabbitMQ broker behind the **RabbitMQ** entry in the managed-services catalog. Installed by the console, not by hand. |

## Prerequisites

- **Kubernetes** 1.24+
- **Helm** 3.8+
- **cert-manager** v1.13+ (only if you enable webhooks; the agent installs it for you if it is missing)

## Quick start

### With the CLI (recommended)

The CLI registers the cluster and installs the agent in one step, so the agent token never has to be copied by hand:

```bash
curl -sfL https://anyport.dev/cli.sh | sh
```

```bash
anyport init
```

### With Helm

Use `helm upgrade --install` so the same command is idempotent (installs if missing, upgrades if already installed). The agent's only required setting is `env.agentToken` — the platform resolves the cluster identity from the token, so there is no cluster name or id to configure.

Get the token from the console when you add a cluster; it is shown once.

**Release tarball:**

```bash
helm upgrade --install anyport-agent https://github.com/anyport-labs/anyport-helm/releases/download/v0.0.1/anyport-agent-chart-0.0.1.tgz \
  --namespace anyport \
  --create-namespace \
  --set env.agentToken="YOUR_AGENT_TOKEN"
```

Replace `v0.0.1` and `anyport-agent-chart-0.0.1.tgz` with the [release](https://github.com/anyport-labs/anyport-helm/releases) you want.

**OCI (ghcr.io):**

```bash
helm upgrade --install anyport-agent oci://ghcr.io/anyport-labs/anyport-agent-chart \
  --version 0.0.1 \
  --namespace anyport \
  --create-namespace \
  --set env.agentToken="YOUR_AGENT_TOKEN"
```

Replace `0.0.1` with the [release](https://github.com/anyport-labs/anyport-helm/releases) version.

### From a local clone

For development or custom changes:

```bash
helm upgrade --install anyport-agent ./charts/agent \
  --namespace anyport \
  --create-namespace \
  --set env.agentToken="YOUR_AGENT_TOKEN"
```

Webhooks are on by default and need [cert-manager](https://cert-manager.io). The agent installs cert-manager itself when it finds it missing; to install it up front, use the same chart and version so the two never fight over the release:

```bash
helm repo add jetstack https://charts.jetstack.io --force-update
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --version v1.14.0 \
  --set installCRDs=true \
  --wait
```

## Configuration

Key values for the agent chart:

| Value | Description | Default |
|-------|-------------|---------|
| `env.agentToken` | Agent authentication token from the console — required | `""` |
| `env.agentId` | Scopes resource names and namespaces; set only when running several agents on one cluster | `""` |
| `env.portServerUrl` | gRPC address of the Anyport platform | `grpc.server.anyport.dev:443` |
| `env.gatewayEndpoint` | Self-hosted gateway agent-plane address; empty disables the tunnel | `gateway.anyport.dev:7000` |
| `env.autoHttps` | Create a Let's Encrypt ClusterIssuer so routes get trusted certificates | `false` |
| `env.acmeEmail` | Let's Encrypt account contact; required when `autoHttps` is true | `""` |
| `env.logLevel` | Log level | `info` |
| `webhook.enabled` | Enable validating/mutating webhooks | `true` |
| `webhook.webhookOnly` | Run only the webhook server (no controllers) | `false` |
| `replicaCount` | Number of agent replicas | `1` |
| `image.repository` | Agent image | `ghcr.io/anyport-labs/anyport-agent` |
| `image.tag` | Image tag | chart `appVersion` |

See [charts/agent/values.yaml](charts/agent/values.yaml) for all options.

## Documentation

- **[Agent chart](charts/agent/README.md)** — full install options, webhook setup, RBAC and troubleshooting.
- **[anyport-redis](charts/anyport-redis/README.md)** and **[anyport-rabbitmq](charts/anyport-rabbitmq/README.md)** — value shapes for the catalog charts.

## Upgrade and uninstall

Re-run the same `helm upgrade --install` command with a new `--version` (or new tarball URL) to upgrade. No separate upgrade flow. The console can also roll the agent forward for you from the cluster's settings.

**Uninstall:**

```bash
helm uninstall anyport-agent --namespace anyport
```

Note: uninstalling does not remove CRDs or existing custom resources. Remove those separately if needed.

## CLI

The Anyport CLI is published here rather than in the product repo, so it can be downloaded anonymously. Releases are tagged `cli/vX.Y.Z`, alongside the chart releases tagged `vX.Y.Z`.

```bash
curl -sfL https://anyport.dev/cli.sh | sh
curl -sfL https://anyport.dev/cli.sh | sh -s -- v0.0.2          # pin a version
curl -sfL https://anyport.dev/cli.sh | ANYPORT_INSTALL_DIR=~/bin sh
```

## Release workflow

Charts are not edited here. They are synced from `helms/` in the [anyport](https://github.com/anyport-labs/anyport) repo by its `release-charts.yml` workflow, which pushes to `main` and then tags this repo.

That tag triggers the [Release workflow](.github/workflows/release.yaml), which discovers every chart under `charts/`, stamps its `version:` from the tag, packages it, pushes it to `ghcr.io/anyport-labs/<chart>` and attaches the tarball to a [GitHub Release](https://github.com/anyport-labs/anyport-helm/releases).

All charts are versioned in lockstep — one tag, one version, every chart — so a chart can be republished byte-identical under a new number. Only `version:` is stamped; `appVersion:` (the agent image tag) is left as synced, so a Redis-only release cannot advertise a phantom agent update.

A GHCR package is private on its first push. Make it public once, in the repo's Packages settings, or agents in customer clusters cannot pull it.
