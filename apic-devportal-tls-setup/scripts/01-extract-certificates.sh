#!/usr/bin/env bash
set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.env"

# Certificate directory
CERT_DIR="${SCRIPT_DIR}/../temp-certificates"

# Namespace from config or default
NAMESPACE="${APIC_NAMESPACE:-apic-lab}"

echo "🔐 Extraindo certificados do namespace: $NAMESPACE"
echo "📁 Diretório de destino: $CERT_DIR"

# Create certificate directory
mkdir -p "$CERT_DIR"

echo ""
echo "📄 Extraindo chave privada do Portal Admin..."
oc get secret devportal-admin-client -n "$NAMESPACE" \
  -o jsonpath='{.data.tls\.key}' \
  | base64 -d > "$CERT_DIR/devportal-admin-client.key.pem"

echo "📄 Extraindo certificado público do Portal Admin..."
oc get secret devportal-admin-client -n "$NAMESPACE" \
  -o jsonpath='{.data.tls\.crt}' \
  | base64 -d > "$CERT_DIR/devportal-admin-client.crt.pem"

echo "📄 Extraindo CA do Ingress (Truststore)..."
oc get secret ingress-ca -n "$NAMESPACE" \
  -o jsonpath='{.data.ca\.crt}' \
  | base64 -d > "$CERT_DIR/ingress-ca.pem"

echo ""
echo "🔍 Validando arquivos gerados..."
echo ""
ls -lh "$CERT_DIR"

echo ""
echo "📋 Informações do certificado do Portal Admin:"
openssl x509 -in "$CERT_DIR/devportal-admin-client.crt.pem" -noout -subject -issuer -dates

echo ""
echo "📋 Informações do CA do Ingress:"
openssl x509 -in "$CERT_DIR/ingress-ca.pem" -noout -subject -issuer -dates

echo ""
echo "✅ Certificados extraídos com sucesso:"
echo "  📦 Keystore (Portal Admin Client):"
echo "    - $CERT_DIR/devportal-admin-client.key.pem"
echo "    - $CERT_DIR/devportal-admin-client.crt.pem"
echo "  📦 Truststore (Ingress CA):"
echo "    - $CERT_DIR/ingress-ca.pem"
echo ""
echo "💡 Use esses certificados nos próximos scripts (10, 11, 12)"

# Made with Bob
