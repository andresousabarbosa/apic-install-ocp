#!/usr/bin/env bash
set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.env"

echo "📋 Listando organizações no API Connect..."
echo ""

apic orgs:list \
  --server "$APIC_SERVER" \
  --insecure-skip-tls-verify

echo ""
echo "💡 Dica: Os TLS Client Profiles são criados na org 'admin'"

# Made with Bob
