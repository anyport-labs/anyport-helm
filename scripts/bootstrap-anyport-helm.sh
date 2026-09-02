#!/usr/bin/env bash
# Bootstrap anyport-helm repo with agent chart and workflows.
# Run from anyport repo root. Requires: helm, git, and optional task (for CRD sync).
#
# Usage:
#   ./scripts/bootstrap-anyport-helm.sh [path-to-anyport-helm-clone]
# If path omitted, uses ../anyport-helm (create if missing).

set -e

ANYPORT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELM_REPO="${1:-$ANYPORT_ROOT/../anyport-helm}"
DOCS_HELM="$ANYPORT_ROOT/docs/anyport-helm-repo"

cd "$ANYPORT_ROOT"

if [ ! -d "helms/agent" ]; then
  echo "Error: helms/agent not found. Run from anyport repo root." >&2
  exit 1
fi

echo "Syncing CRDs into agent chart..."
if command -v task &>/dev/null; then
  (cd helms && task sync:crds:agent 2>/dev/null) || true
else
  mkdir -p helms/agent/crds
  cp -f backend/operators/config/crd/bases/*.yaml helms/agent/crds/ 2>/dev/null || true
fi

if [ ! -d "$HELM_REPO" ]; then
  echo "Cloning anyport-helm into $HELM_REPO..."
  git clone git@github.com:anyport-labs/anyport-helm.git "$HELM_REPO"
fi

echo "Copying agent chart to $HELM_REPO/charts/agent..."
mkdir -p "$HELM_REPO/charts"
rm -rf "$HELM_REPO/charts/agent"
cp -r helms/agent "$HELM_REPO/charts/agent"

# Only the CLI installer now. The cluster and agent scripts were removed when the
# CLI took over both halves of connecting a cluster — it registers and installs
# in one process, so there is no token to paste between them.
echo "Copying the CLI installer (served via raw.githubusercontent as anyport.dev/cli.sh)..."
mkdir -p "$HELM_REPO/scripts"
cp -f "$ANYPORT_ROOT/scripts/install-cli.sh" "$HELM_REPO/scripts/"

echo "Copying workflows and README..."
mkdir -p "$HELM_REPO/.github/workflows"
cp -f "$DOCS_HELM/.github/workflows/release-charts.yml" "$HELM_REPO/.github/workflows/"
cp -f "$DOCS_HELM/.github/workflows/lint.yml" "$HELM_REPO/.github/workflows/"
cp -f "$DOCS_HELM/README.md" "$HELM_REPO/README.md"

echo "Done. Next steps:"
echo "  1. cd $HELM_REPO"
echo "  2. Enable GitHub Pages from branch 'gh-pages' (Settings → Pages)."
echo "  3. git add . && git status"
echo "  4. git commit -m 'chore: add agent chart and release workflows' && git push origin main"
echo "  5. After push, chart-releaser will run and publish the chart."
