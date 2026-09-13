#!/usr/bin/env bash
# Compares the console's current GraphQL schema with the published one and fails on a
# breaking change (docs/competitive-gaps §4). The published copy is what customers' scripts,
# the CLI and the Terraform provider were written against; it lives on the landing site at
# /api/schema.graphql and is refreshed by the release workflow.
#
#   scripts/api-schema-check.sh              # gate: exit 1 on a breaking change
#   scripts/api-schema-check.sh --publish    # refresh the published copy from the current schema
#   ALLOW_BREAKING_API_CHANGES=1 scripts/api-schema-check.sh   # a break that was decided
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
published="$root/ui/landing/public/api/schema.graphql"
current="$(mktemp -t anyport-schema.XXXXXX)"
trap 'rm -f "$current"' EXIT

go -C "$root/backend" run ./cmd/gqlschema --out "$current"

if [ "${1:-}" = "--publish" ]; then
  cp "$current" "$published"
  echo "published $(wc -l < "$published" | tr -d ' ') lines to ${published#"$root/"}"
  exit 0
fi

args=()
if [ "${ALLOW_BREAKING_API_CHANGES:-}" = "1" ]; then
  args+=(-allow-breaking)
fi
go -C "$root/backend" run ./cmd/gqldiff ${args[@]+"${args[@]}"} "$published" "$current"
