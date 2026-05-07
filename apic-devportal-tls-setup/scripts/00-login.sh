#!/usr/bin/env bash
set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.env"

echo "🔐 Logging into API Connect..."
echo "Server: $APIC_SERVER"
echo "User: $APIC_USER"
echo "Realm: $APIC_REALM"

apic login --server "$APIC_SERVER" \
  --username "$APIC_USER" \
  --password "$APIC_PASSWORD" \
  --realm "$APIC_REALM" \
  --insecure-skip-tls-verify

echo "✅ Login successful!"