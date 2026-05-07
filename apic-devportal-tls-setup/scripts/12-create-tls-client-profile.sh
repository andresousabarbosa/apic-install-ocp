#!/usr/bin/env bash
set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.env"

# Certificate directory
CERT_DIR="${SCRIPT_DIR}/../temp-certificates"

echo "🔐 Criando TLS Client Profile no Cloud Manager..."
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

echo "📋 Verificando pré-requisitos..."

# Check if keystore exists and get URL
KEYSTORES=$(apic keystores:list-all \
  --org admin \
  --server "$APIC_SERVER" \
  --format json \
  --insecure-skip-tls-verify 2>/dev/null || echo "{}")

if ! echo "$KEYSTORES" | jq -e '.results[] | select(.name == "'"$KEYSTORE_NAME"'")' > /dev/null 2>&1; then
  echo "❌ Keystore não encontrado: $KEYSTORE_NAME"
  echo "   Execute ./10-create-keystore.sh primeiro."
  exit 1
else
  KEYSTORE_URL=$(echo "$KEYSTORES" | jq -r '.results[] | select(.name == "'"$KEYSTORE_NAME"'") | .url')
  echo "✅ Keystore encontrado: $KEYSTORE_NAME"
  echo "   URL: $KEYSTORE_URL"
fi

# Check if truststore exists and get URL
TRUSTSTORES=$(apic truststores:list-all \
  --org admin \
  --server "$APIC_SERVER" \
  --format json \
  --insecure-skip-tls-verify 2>/dev/null || echo "{}")

if ! echo "$TRUSTSTORES" | jq -e '.results[] | select(.name == "'"$TRUSTSTORE_NAME"'")' > /dev/null 2>&1; then
  echo "❌ Truststore não encontrado: $TRUSTSTORE_NAME"
  echo "   Execute ./11-create-truststore.sh primeiro."
  exit 1
else
  TRUSTSTORE_URL=$(echo "$TRUSTSTORES" | jq -r '.results[] | select(.name == "'"$TRUSTSTORE_NAME"'") | .url')
  echo "✅ Truststore encontrado: $TRUSTSTORE_NAME"
  echo "   URL: $TRUSTSTORE_URL"
fi

echo ""
echo "📋 Verificando se TLS Client Profile já existe..."

# Check if TLS Client Profile already exists
EXISTING_PROFILE=$(apic tls-client-profiles:list-all \
  --org admin \
  --server "$APIC_SERVER" \
  --format json \
  --insecure-skip-tls-verify 2>/dev/null || echo "{}")

if echo "$EXISTING_PROFILE" | jq -e '.results[] | select(.name == "'"$TLS_PROFILE_NAME"'")' > /dev/null 2>&1; then
  echo "⚠️  TLS Client Profile já existe: $TLS_PROFILE_NAME"
  echo ""
  read -p "❓ Deseja recriar o profile? (s/N): " -n 1 -r
  echo
  
  if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo "🗑️  Deletando profile existente..."
    apic tls-client-profiles:delete \
      --org admin \
      --server "$APIC_SERVER" \
      --insecure-skip-tls-verify \
      "$TLS_PROFILE_NAME" || true
    echo "✅ Profile deletado"
  else
    echo "ℹ️  Mantendo profile existente"
    exit 0
  fi
fi

echo ""
echo "📦 Criando TLS Client Profile: $TLS_PROFILE_NAME"
echo "   Keystore: $KEYSTORE_NAME"
echo "   Truststore: $TRUSTSTORE_NAME"
echo ""

# Create YAML payload file
cat > "$CERT_DIR/tls-profile-payload.yaml" <<EOF
name: $TLS_PROFILE_NAME
title: $TLS_PROFILE_NAME
keystore_url: $KEYSTORE_URL
truststore_url: $TRUSTSTORE_URL
protocols:
  - tls_v1.2
  - tls_v1.3
version: 1.0.0
EOF

echo "📄 Payload criado em: $CERT_DIR/tls-profile-payload.yaml"
echo ""

# Create TLS Client Profile
apic tls-client-profiles:create \
  --org admin \
  --server "$APIC_SERVER" \
  --insecure-skip-tls-verify \
  "$CERT_DIR/tls-profile-payload.yaml"

if [ $? -eq 0 ]; then
  echo ""
  echo "✅ TLS Client Profile criado com sucesso: $TLS_PROFILE_NAME"
  echo ""
  echo "📋 Verificando profile criado..."
  
  PROFILE_LIST=$(apic tls-client-profiles:list \
    --org admin \
    --server "$APIC_SERVER" \
    --format json \
    --insecure-skip-tls-verify 2>/dev/null)
  
  if echo "$PROFILE_LIST" | jq -e . >/dev/null 2>&1; then
    echo "$PROFILE_LIST" | jq -r '.results[] | select(.name == "'"$TLS_PROFILE_NAME"'") | "   Name: \(.name)\n   Title: \(.title)\n   Version: \(.version)\n   URL: \(.url)"'
  else
    echo "⚠️  Não foi possível verificar o profile (resposta não-JSON)"
    echo "   Mas o TLS Client Profile foi criado com sucesso"
  fi
  
  echo ""
  echo "💡 Próximo passo: Execute ./20-register-devportal.sh para registrar o portal"
  
  # Cleanup payload file
  rm -f "$CERT_DIR/tls-profile-payload.yaml"
else
  echo ""
  echo "❌ Falha ao criar TLS Client Profile"
  rm -f "$CERT_DIR/tls-profile-payload.yaml"
  exit 1
fi

# Made with Bob
