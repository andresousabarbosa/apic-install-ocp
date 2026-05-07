#!/usr/bin/env bash
set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.env"

# Certificate directory
CERT_DIR="${SCRIPT_DIR}/../temp-certificates"

echo "🔐 Criando TLS Client Profile no Cloud Manager..."
echo ""

# Check if keystore exists and get URL
KEYSTORES=$(apic keystores:list \
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
TRUSTSTORES=$(apic truststores:list \
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
  EXISTING_VERSION=$(echo "$EXISTING_PROFILE" | jq -r '.results[] | select(.name == "'"$TLS_PROFILE_NAME"'") | .version')
  echo "⚠️  TLS Client Profile já existe: $TLS_PROFILE_NAME (versão: $EXISTING_VERSION)"
  echo ""
  read -p "❓ Deseja recriar o profile? (s/N): " -n 1 -r
  echo
  
  if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo "🗑️  Deletando profile existente..."
    apic tls-client-profiles:delete \
      --org admin \
      --server "$APIC_SERVER" \
      --insecure-skip-tls-verify \
      "${TLS_PROFILE_NAME}:${EXISTING_VERSION}" || true
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

# Create YAML payload file - start with basic fields
cat > "$CERT_DIR/tls-profile-payload.yaml" <<'YAML_START'
name: TLS_PROFILE_NAME_PLACEHOLDER
title: TLS_PROFILE_TITLE_PLACEHOLDER
summary: TLS_PROFILE_SUMMARY_PLACEHOLDER
keystore_url: KEYSTORE_URL_PLACEHOLDER
truststore_url: TRUSTSTORE_URL_PLACEHOLDER
protocols:
YAML_START

# Add protocols
if [ -n "$TLS_PROTOCOLS" ]; then
  IFS=',' read -ra PROTOCOL_ARRAY <<< "$TLS_PROTOCOLS"
  for protocol in "${PROTOCOL_ARRAY[@]}"; do
    echo "  - $(echo $protocol | xargs)" >> "$CERT_DIR/tls-profile-payload.yaml"
  done
else
  echo "  - tls_v1.2" >> "$CERT_DIR/tls-profile-payload.yaml"
  echo "  - tls_v1.3" >> "$CERT_DIR/tls-profile-payload.yaml"
fi

# Add ciphers if specified
if [ -n "$TLS_CIPHERS" ]; then
  echo "ciphers:" >> "$CERT_DIR/tls-profile-payload.yaml"
  IFS=',' read -ra CIPHER_ARRAY <<< "$TLS_CIPHERS"
  for cipher in "${CIPHER_ARRAY[@]}"; do
    echo "  - $(echo $cipher | xargs)" >> "$CERT_DIR/tls-profile-payload.yaml"
  done
fi

# Add version
echo "version: 1.0.0" >> "$CERT_DIR/tls-profile-payload.yaml"

# Replace placeholders with actual values
sed -i.bak \
  -e "s|TLS_PROFILE_NAME_PLACEHOLDER|$TLS_PROFILE_NAME|g" \
  -e "s|TLS_PROFILE_TITLE_PLACEHOLDER|$TLS_PROFILE_TITLE|g" \
  -e "s|TLS_PROFILE_SUMMARY_PLACEHOLDER|$TLS_PROFILE_SUMMARY|g" \
  -e "s|KEYSTORE_URL_PLACEHOLDER|$KEYSTORE_URL|g" \
  -e "s|TRUSTSTORE_URL_PLACEHOLDER|$TRUSTSTORE_URL|g" \
  "$CERT_DIR/tls-profile-payload.yaml"

# Remove backup file
rm -f "$CERT_DIR/tls-profile-payload.yaml.bak"

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
  
  PROFILE_LIST=$(apic tls-client-profiles:list-all \
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
