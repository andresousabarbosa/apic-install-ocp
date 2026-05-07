#!/usr/bin/env bash
set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.env"

# Certificate directory
CERT_DIR="${SCRIPT_DIR}/../temp-certificates"

echo "🔐 Criando Truststore no Cloud Manager..."
echo ""

# Check if logged in by trying to list resources
echo "🔍 Verificando login no APIC..."
if ! apic truststores:list-all --org admin --server "$APIC_SERVER" --insecure-skip-tls-verify &> /dev/null; then
  echo "❌ Não está logado no APIC ou sessão expirou."
  echo "   Execute ./00-login.sh primeiro."
  exit 1
fi
echo "✅ Login verificado"
echo ""

# Check if CA certificate exists
if [ ! -f "$CERT_DIR/ingress-ca.pem" ]; then
  echo "❌ Certificado CA não encontrado: $CERT_DIR/ingress-ca.pem"
  echo "   Execute ./01-extract-certificates.sh primeiro."
  exit 1
fi

echo "📋 Verificando se truststore já existe..."

# Check if truststore already exists
EXISTING_TRUSTSTORE=$(apic truststores:list-all \
  --org admin \
  --server "$APIC_SERVER" \
  --format json \
  --insecure-skip-tls-verify 2>/dev/null || echo "{}")

if echo "$EXISTING_TRUSTSTORE" | jq -e '.results[] | select(.name == "'"$TRUSTSTORE_NAME"'")' > /dev/null 2>&1; then
  echo "⚠️  Truststore já existe: $TRUSTSTORE_NAME"
  echo ""
  read -p "❓ Deseja recriar o truststore? (s/N): " -n 1 -r
  echo
  
  if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo "🗑️  Deletando truststore existente..."
    apic truststores:delete \
      --org admin \
      --server "$APIC_SERVER" \
      --insecure-skip-tls-verify \
      "$TRUSTSTORE_NAME" || true
    echo "✅ Truststore deletado"
  else
    echo "ℹ️  Mantendo truststore existente"
    exit 0
  fi
fi

echo ""
echo "📦 Criando truststore: $TRUSTSTORE_NAME"
echo "   Certificado CA: $CERT_DIR/ingress-ca.pem"
echo ""

# Read CA certificate
CA_CONTENT=$(cat "$CERT_DIR/ingress-ca.pem")

# Create YAML payload file
cat > "$CERT_DIR/truststore-payload.yaml" <<EOF
name: $TRUSTSTORE_NAME
title: $TRUSTSTORE_NAME
truststore: |
$(echo "$CA_CONTENT" | sed 's/^/  /')
EOF

echo "📄 Payload criado em: $CERT_DIR/truststore-payload.yaml"
echo ""

# Create truststore
apic truststores:create \
  --org admin \
  --server "$APIC_SERVER" \
  --insecure-skip-tls-verify \
  "$CERT_DIR/truststore-payload.yaml"

if [ $? -eq 0 ]; then
  echo ""
  echo "✅ Truststore criado com sucesso: $TRUSTSTORE_NAME"
  echo ""
  echo "📋 Verificando truststore criado..."
  
  TRUSTSTORE_LIST=$(apic truststores:list \
    --org admin \
    --server "$APIC_SERVER" \
    --format json \
    --insecure-skip-tls-verify 2>/dev/null)
  
  if echo "$TRUSTSTORE_LIST" | jq -e . >/dev/null 2>&1; then
    echo "$TRUSTSTORE_LIST" | jq -r '.results[] | select(.name == "'"$TRUSTSTORE_NAME"'") | "   Name: \(.name)\n   Title: \(.title)\n   URL: \(.url)"'
  else
    echo "⚠️  Não foi possível verificar o truststore (resposta não-JSON)"
    echo "   Mas o truststore foi criado com sucesso"
  fi
  
  # Cleanup payload file
  rm -f "$CERT_DIR/truststore-payload.yaml"
else
  echo ""
  echo "❌ Falha ao criar truststore"
  rm -f "$CERT_DIR/truststore-payload.yaml"
  exit 1
fi

# Made with Bob
