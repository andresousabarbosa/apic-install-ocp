#!/usr/bin/env bash
set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.env"

echo "🌐 Registrando Developer Portal no Cloud Manager..."
echo ""

# Check if logged in by trying to list resources
echo "🔍 Verificando login no APIC..."
if ! apic portal-services:list-all --org admin --server "$APIC_SERVER" --insecure-skip-tls-verify &> /dev/null; then
  echo "❌ Não está logado no APIC ou sessão expirou."
  echo "   Execute ./00-login.sh primeiro."
  exit 1
fi
echo "✅ Login verificado"
echo ""

echo "📋 Verificando pré-requisitos..."

# Check if TLS Client Profile exists
TLS_PROFILES=$(apic tls-client-profiles:list-all \
  --org admin \
  --server "$APIC_SERVER" \
  --format json \
  --insecure-skip-tls-verify 2>/dev/null || echo "{}")

if ! echo "$TLS_PROFILES" | jq -e '.results[] | select(.name == "'"$TLS_PROFILE_NAME"'")' > /dev/null 2>&1; then
  echo "❌ TLS Client Profile não encontrado: $TLS_PROFILE_NAME"
  echo "   Execute ./12-create-tls-client-profile.sh primeiro."
  exit 1
else
  echo "✅ TLS Client Profile encontrado: $TLS_PROFILE_NAME"
fi

echo ""
echo "📋 Verificando se portal já está registrado..."

# Check if portal service already exists
EXISTING_SERVICES=$(apic portal-services:list-all \
  --org admin \
  --server "$APIC_SERVER" \
  --format json \
  --insecure-skip-tls-verify 2>/dev/null || echo "{}")

# Check by endpoint URL
if echo "$EXISTING_SERVICES" | jq -e '.results[] | select(.endpoint == "'"$PORTAL_ADMIN_URL"'")' > /dev/null 2>&1; then
  EXISTING_NAME=$(echo "$EXISTING_SERVICES" | jq -r '.results[] | select(.endpoint == "'"$PORTAL_ADMIN_URL"'") | .title')
  echo "⚠️  Portal já está registrado: $EXISTING_NAME"
  echo "   Endpoint: $PORTAL_ADMIN_URL"
  echo ""
  read -p "❓ Deseja recriar o registro? (s/N): " -n 1 -r
  echo
  
  if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo "🗑️  Deletando registro existente..."
    SERVICE_NAME=$(echo "$EXISTING_SERVICES" | jq -r '.results[] | select(.endpoint == "'"$PORTAL_ADMIN_URL"'") | .name')
    apic portal-services:delete \
      --org admin \
      --server "$APIC_SERVER" \
      --insecure-skip-tls-verify \
      "$SERVICE_NAME" || true
    echo "✅ Registro deletado"
  else
    echo "ℹ️  Mantendo registro existente"
    exit 0
  fi
fi

echo ""
echo "📦 Registrando Developer Portal..."
echo "   Title: $TLS_PROFILE_NAME"
echo "   Admin Endpoint: $PORTAL_ADMIN_URL"
echo "   Web Endpoint: $PORTAL_SITE_URL"
echo "   TLS Client Profile: $TLS_PROFILE_NAME"
echo ""

# Register portal service
apic portal-services:create \
  --org admin \
  --server "$APIC_SERVER" \
  --title "$TLS_PROFILE_NAME" \
  --endpoint "$PORTAL_ADMIN_URL" \
  --web-endpoint-base "$PORTAL_SITE_URL" \
  --tls-client-profile-url "$(echo "$TLS_PROFILES" | jq -r '.results[] | select(.name == "'"$TLS_PROFILE_NAME"'") | .url')" \
  --visibility public \
  --insecure-skip-tls-verify

if [ $? -eq 0 ]; then
  echo ""
  echo "✅ Developer Portal registrado com sucesso!"
  echo ""
  echo "📋 Verificando portal registrado..."
  apic portal-services:list-all \
    --org admin \
    --server "$APIC_SERVER" \
    --format json \
    --insecure-skip-tls-verify | jq -r '.results[] | select(.endpoint == "'"$PORTAL_ADMIN_URL"'") | "   Title: \(.title)\n   Endpoint: \(.endpoint)\n   Web Endpoint: \(.web_endpoint_base)\n   URL: \(.url)"'
  
  echo ""
  echo "💡 Próximo passo: Execute ./30-validate-registration.sh para validar"
else
  echo ""
  echo "❌ Falha ao registrar Developer Portal"
  exit 1
fi

# Made with Bob
