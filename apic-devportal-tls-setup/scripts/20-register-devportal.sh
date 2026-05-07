#!/usr/bin/env bash
set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.env"

echo "🌐 Registrando Developer Portal no Cloud Manager..."
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

# Validate availability zone ID
if [ -z "$AVAILABILITY_ZONE_ID" ]; then
  echo "❌ AVAILABILITY_ZONE_ID não está definido!"
  echo "   Execute 'source ../config.env' novamente para carregar a configuração."
  exit 1
fi

echo ""
echo "📋 Verificando se portal já está registrado..."

# Check if portal service already exists
EXISTING_SERVICES=$(apic portal-services:list \
  --org admin \
  --availability-zone "$AVAILABILITY_ZONE_ID" \
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

# Get TLS Client Profile URL
TLS_PROFILE_URL=$(echo "$TLS_PROFILES" | jq -r '.results[] | select(.name == "'"$TLS_PROFILE_NAME"'") | .url')

echo ""
echo "📋 Buscando integração do Developer Portal..."

# Get Developer Portal integration URL
INTEGRATIONS=$(apic integrations:list \
  --subcollection portal-service \
  --server "$APIC_SERVER" \
  --format json \
  --insecure-skip-tls-verify 2>/dev/null)

INTEGRATION_URL=$(echo "$INTEGRATIONS" | jq -r '.results[] | select(.name == "devportal") | .url')

if [ -z "$INTEGRATION_URL" ]; then
  echo "❌ Integração 'devportal' não encontrada!"
  echo "   Integrações disponíveis:"
  echo "$INTEGRATIONS" | jq -r '.results[] | "   - \(.name): \(.title)"'
  exit 1
fi

echo "✅ Integração encontrada: $INTEGRATION_URL"

# Create temporary directory for payload
TEMP_DIR="${SCRIPT_DIR}/../temp-certificates"
mkdir -p "$TEMP_DIR"

# Create portal service payload file
# Based on wm-portal.yaml reference structure and working script


cat > "$TEMP_DIR/portal-service-payload.yaml" <<EOF
name: wm-devportal
title: Developer Portal Service
summary: Developer Portal Service for API Connect
endpoint: $PORTAL_ADMIN_URL
web_endpoint_base: $PORTAL_SITE_URL
endpoint_tls_client_profile_url: $TLS_PROFILE_URL
integration_url: $INTEGRATION_URL
EOF

echo "📄 Payload criado em: $TEMP_DIR/portal-service-payload.yaml"
echo ""
echo "📋 Conteúdo do payload:"
cat "$TEMP_DIR/portal-service-payload.yaml"
echo ""

# Register portal service with debug output
echo "🚀 Executando comando de registro..."
echo "   Comando: apic portal-services:create --org admin --availability-zone \"$AVAILABILITY_ZONE_ID\" --server \"$APIC_SERVER\" --insecure-skip-tls-verify"
echo ""

apic portal-services:create \
  --org admin \
  --availability-zone "$AVAILABILITY_ZONE_ID" \
  --server "$APIC_SERVER" \
  --insecure-skip-tls-verify \
  --output - \
  "$TEMP_DIR/portal-service-payload.yaml" 2>&1 | tee "$TEMP_DIR/portal-service-create-output.log"

CREATE_EXIT_CODE=${PIPESTATUS[0]}

echo ""
echo "📋 Log completo salvo em: $TEMP_DIR/portal-service-create-output.log"
echo ""

if [ $CREATE_EXIT_CODE -eq 0 ]; then
  echo ""
  echo "✅ Developer Portal registrado com sucesso!"
  echo ""
  echo "📋 Verificando portal registrado..."
  
  PORTAL_LIST=$(apic portal-services:list \
    --org admin \
    --availability-zone "$AVAILABILITY_ZONE_ID" \
    --server "$APIC_SERVER" \
    --format json \
    --insecure-skip-tls-verify 2>/dev/null)
  
  if echo "$PORTAL_LIST" | jq -e . >/dev/null 2>&1; then
    echo "$PORTAL_LIST" | jq -r '.results[] | select(.endpoint == "'"$PORTAL_ADMIN_URL"'") | "   Title: \(.title)\n   Endpoint: \(.endpoint)\n   Web Endpoint: \(.web_endpoint_base)\n   URL: \(.url)"'
  else
    echo "⚠️  Não foi possível verificar o portal (resposta não-JSON)"
    echo "   Mas o portal foi registrado com sucesso"
  fi
  
  # Cleanup payload file
  rm -f "$TEMP_DIR/portal-service-payload.yaml"
  
  echo ""
  echo "💡 Próximo passo: Execute ./30-validate-registration.sh para validar"
else
  echo ""
  echo "❌ Falha ao registrar Developer Portal"
  rm -f "$TEMP_DIR/portal-service-payload.yaml"
  exit 1
fi

# Made with Bob
