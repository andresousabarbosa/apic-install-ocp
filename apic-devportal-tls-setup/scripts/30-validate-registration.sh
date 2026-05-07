#!/usr/bin/env bash
set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.env"

echo "🔍 Validando registro do Developer Portal..."
echo ""

# Check if logged in by trying to list resources
echo "🔍 Verificando login no APIC..."
if ! apic tls-client-profiles:list-all --org admin --server "$APIC_SERVER" --insecure-skip-tls-verify &> /dev/null; then
  echo "❌ Não está logado no APIC ou sessão expirou."
  echo "   Execute ./00-login.sh primeiro."
  exit 1
fi
echo "✅ Login verificado"
echo ""

echo "📋 Verificando TLS Client Profile..."
echo ""

# List TLS Client Profiles
TLS_PROFILES=$(apic tls-client-profiles:list-all \
  --org admin \
  --server "$APIC_SERVER" \
  --format json \
  --insecure-skip-tls-verify 2>/dev/null || echo "[]")

if echo "$TLS_PROFILES" | jq -e '.results[] | select(.name == "'"$TLS_PROFILE_NAME"'")' > /dev/null 2>&1; then
  echo "✅ TLS Client Profile encontrado: $TLS_PROFILE_NAME"
  
  # Get profile details
  PROFILE_VERSION=$(echo "$TLS_PROFILES" | jq -r '.results[] | select(.name == "'"$TLS_PROFILE_NAME"'") | .version')
  PROFILE_URL=$(echo "$TLS_PROFILES" | jq -r '.results[] | select(.name == "'"$TLS_PROFILE_NAME"'") | .url')
  
  echo "   Version: $PROFILE_VERSION"
  echo "   URL: $PROFILE_URL"
else
  echo "❌ TLS Client Profile não encontrado: $TLS_PROFILE_NAME"
  echo ""
  echo "Profiles disponíveis:"
  echo "$TLS_PROFILES" | jq -r '.results[]? | "  - \(.name) (version: \(.version))"'
  exit 1
fi

echo ""
echo "📋 Verificando Keystores..."
echo ""

# List Keystores
KEYSTORES=$(apic keystores:list-all \
  --org admin \
  --server "$APIC_SERVER" \
  --format json \
  --insecure-skip-tls-verify 2>/dev/null || echo "[]")

if echo "$KEYSTORES" | jq -e '.results[] | select(.name == "'"$KEYSTORE_NAME"'")' > /dev/null 2>&1; then
  echo "✅ Keystore encontrado: $KEYSTORE_NAME"
else
  echo "❌ Keystore não encontrado: $KEYSTORE_NAME"
fi

echo ""
echo "📋 Verificando Truststores..."
echo ""

# List Truststores
TRUSTSTORES=$(apic truststores:list-all \
  --org admin \
  --server "$APIC_SERVER" \
  --format json \
  --insecure-skip-tls-verify 2>/dev/null || echo "[]")

if echo "$TRUSTSTORES" | jq -e '.results[] | select(.name == "'"$TRUSTSTORE_NAME"'")' > /dev/null 2>&1; then
  echo "✅ Truststore encontrado: $TRUSTSTORE_NAME"
else
  echo "❌ Truststore não encontrado: $TRUSTSTORE_NAME"
fi

echo ""
echo "📋 Verificando Developer Portal Services..."
echo ""

# List Portal Services
PORTAL_SERVICES=$(apic portal-services:list-all \
  --org admin \
  --server "$APIC_SERVER" \
  --format json \
  --insecure-skip-tls-verify 2>/dev/null || echo "[]")

PORTAL_COUNT=$(echo "$PORTAL_SERVICES" | jq '.total_results // 0')

if [ "$PORTAL_COUNT" -gt 0 ]; then
  echo "✅ Portal Services encontrados: $PORTAL_COUNT"
  echo ""
  echo "Detalhes dos portais:"
  echo "$PORTAL_SERVICES" | jq -r '.results[]? | "  - \(.title // .name)"'
  echo ""
  echo "$PORTAL_SERVICES" | jq -r '.results[]? | "    Endpoint: \(.endpoint)"'
  echo "$PORTAL_SERVICES" | jq -r '.results[]? | "    Web Endpoint: \(.web_endpoint_base)"'
else
  echo "⚠️  Nenhum Portal Service registrado ainda"
  echo ""
  echo "Execute o script 20-register-devportal.sh para registrar o portal."
fi

echo ""
echo "📋 Verificando no Kubernetes..."
echo ""

# Check DevPortalCluster status
PORTAL_STATUS=$(oc get devportalcluster -n "$APIC_NAMESPACE" -o json 2>/dev/null || echo "{}")
PORTAL_NAME=$(echo "$PORTAL_STATUS" | jq -r '.items[0].metadata.name // "not-found"')
PORTAL_PHASE=$(echo "$PORTAL_STATUS" | jq -r '.items[0].status.phase // "Unknown"')
PORTAL_READY=$(echo "$PORTAL_STATUS" | jq -r '.items[0].status.conditions[] | select(.type=="Ready") | .status // "Unknown"')

if [ "$PORTAL_NAME" != "not-found" ]; then
  echo "✅ DevPortalCluster: $PORTAL_NAME"
  echo "   Phase: $PORTAL_PHASE"
  echo "   Ready: $PORTAL_READY"
  
  if [ "$PORTAL_PHASE" == "Running" ] && [ "$PORTAL_READY" == "True" ]; then
    echo "   Status: ✅ Portal está operacional"
  else
    echo "   Status: ⚠️  Portal não está completamente pronto"
  fi
else
  echo "❌ DevPortalCluster não encontrado"
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                  RESUMO DA VALIDAÇÃO                           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Summary
VALIDATION_OK=true

if echo "$TLS_PROFILES" | jq -e '.results[] | select(.name == "'"$TLS_PROFILE_NAME"'")' > /dev/null 2>&1; then
  echo "✅ TLS Client Profile: OK"
else
  echo "❌ TLS Client Profile: FALTANDO"
  VALIDATION_OK=false
fi

if echo "$KEYSTORES" | jq -e '.results[] | select(.name == "'"$KEYSTORE_NAME"'")' > /dev/null 2>&1; then
  echo "✅ Keystore: OK"
else
  echo "❌ Keystore: FALTANDO"
  VALIDATION_OK=false
fi

if echo "$TRUSTSTORES" | jq -e '.results[] | select(.name == "'"$TRUSTSTORE_NAME"'")' > /dev/null 2>&1; then
  echo "✅ Truststore: OK"
else
  echo "❌ Truststore: FALTANDO"
  VALIDATION_OK=false
fi

if [ "$PORTAL_COUNT" -gt 0 ]; then
  echo "✅ Portal Service: REGISTRADO"
else
  echo "⚠️  Portal Service: NÃO REGISTRADO"
  VALIDATION_OK=false
fi

if [ "$PORTAL_PHASE" == "Running" ]; then
  echo "✅ DevPortalCluster: RUNNING"
else
  echo "⚠️  DevPortalCluster: $PORTAL_PHASE"
fi

echo ""

if [ "$VALIDATION_OK" = true ] && [ "$PORTAL_COUNT" -gt 0 ]; then
  echo "🎉 Validação completa! O Developer Portal está configurado corretamente."
  exit 0
else
  echo "⚠️  Alguns componentes estão faltando ou não estão configurados."
  echo ""
  echo "Próximos passos:"
  if [ "$PORTAL_COUNT" -eq 0 ]; then
    echo "  - Execute: ./20-register-devportal.sh"
  fi
  exit 1
fi

# Made with Bob
