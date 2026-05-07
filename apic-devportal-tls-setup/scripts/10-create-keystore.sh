#!/usr/bin/env bash
set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.env"

# Certificate directory
CERT_DIR="${SCRIPT_DIR}/../temp-certificates"

echo "🔐 Criando Keystore no Cloud Manager..."
echo ""


# Check if certificates exist
if [ ! -f "$CERT_DIR/devportal-admin-client.crt.pem" ]; then
  echo "❌ Certificado não encontrado: $CERT_DIR/devportal-admin-client.crt.pem"
  echo "   Execute ./01-extract-certificates.sh primeiro."
  exit 1
fi

if [ ! -f "$CERT_DIR/devportal-admin-client.key.pem" ]; then
  echo "❌ Chave privada não encontrada: $CERT_DIR/devportal-admin-client.key.pem"
  echo "   Execute ./01-extract-certificates.sh primeiro."
  exit 1
fi

echo "📋 Verificando se keystore já existe..."

# Check if keystore already exists
EXISTING_KEYSTORE=$(apic keystores:list \
  --org admin \
  --server "$APIC_SERVER" \
  --format json \
  --insecure-skip-tls-verify 2>/dev/null || echo "{}")

if echo "$EXISTING_KEYSTORE" | jq -e '.results[] | select(.name == "'"$KEYSTORE_NAME"'")' > /dev/null 2>&1; then
  echo "⚠️  Keystore já existe: $KEYSTORE_NAME"
  echo ""
  read -p "❓ Deseja recriar o keystore? (s/N): " -n 1 -r
  echo
  
  if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo "🗑️  Deletando keystore existente..."
    apic keystores:delete \
      --org admin \
      --server "$APIC_SERVER" \
      --insecure-skip-tls-verify \
      "$KEYSTORE_NAME" || true
    echo "✅ Keystore deletado"
  else
    echo "ℹ️  Mantendo keystore existente"
    exit 0
  fi
fi

echo ""
echo "📦 Criando keystore: $KEYSTORE_NAME"
echo "   Certificado: $CERT_DIR/devportal-admin-client.crt.pem"
echo "   Chave privada: $CERT_DIR/devportal-admin-client.key.pem"
echo ""

# Read certificate and key - combine them in one field
CERT_CONTENT=$(cat "$CERT_DIR/devportal-admin-client.crt.pem")
KEY_CONTENT=$(cat "$CERT_DIR/devportal-admin-client.key.pem")

# Create YAML payload file with certificate and key combined
cat > "$CERT_DIR/keystore-payload.yaml" <<EOF
name: $KEYSTORE_NAME
title: $KEYSTORE_TITLE
summary: $KEYSTORE_SUMMARY
keystore: |
$(echo "$CERT_CONTENT" | sed 's/^/  /')
$(echo "$KEY_CONTENT" | sed 's/^/  /')
EOF

echo "📄 Payload criado em: $CERT_DIR/keystore-payload.yaml"
echo ""

#Create keystore
apic keystores:create \
  --org admin \
  --server "$APIC_SERVER" \
  --insecure-skip-tls-verify \
  "$CERT_DIR/keystore-payload.yaml"

if [ $? -eq 0 ]; then
  echo ""
  echo "✅ Keystore criado com sucesso: $KEYSTORE_NAME"
  echo ""
  echo "📋 Verificando keystore criado..."
  
  KEYSTORE_LIST=$(apic keystores:list \
    --org admin \
    --server "$APIC_SERVER" \
    --format json \
    --insecure-skip-tls-verify 2>/dev/null)
  
  if echo "$KEYSTORE_LIST" | jq -e . >/dev/null 2>&1; then
    echo "$KEYSTORE_LIST" | jq -r '.results[] | select(.name == "'"$KEYSTORE_NAME"'") | "   Name: \(.name)\n   Title: \(.title)\n   URL: \(.url)"'
  else
    echo "⚠️  Não foi possível verificar o keystore (resposta não-JSON)"
    echo "   Mas o keystore foi criado com sucesso"
  fi
  
  # Cleanup payload file
  rm -f "$CERT_DIR/keystore-payload.yaml"
else
  echo ""
  echo "❌ Falha ao criar keystore"
  rm -f "$CERT_DIR/keystore-payload.yaml"
  exit 1
fi
