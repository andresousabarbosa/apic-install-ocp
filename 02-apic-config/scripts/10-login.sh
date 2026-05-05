#!/usr/bin/env bash
set -e

source "$(dirname "$0")/01-env.sh"

echo "🔐 Fazendo login no Management (Platform API)..."

echo "📄 User salvo em: ${APIC_ADMIN_USER}"

RESPONSE=$(curl -sk -X POST \
  "${APIC_MGMT_PLATFORM_API}/cloud/login" \
  -H "Content-Type: application/json" \
  -d "{
    \"username\": \"${APIC_ADMIN_USER}\",
    \"password\": \"${APIC_ADMIN_PASSWORD}\"
  }")

echo "${RESPONSE}"
echo "${RESPONSE}" > "${TOKEN_FILE}"

echo "✅ Login realizado."
echo "📄 Token salvo em: ${TOKEN_FILE}"