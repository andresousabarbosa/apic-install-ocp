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
echo ""

# Check if logged in to OpenShift
echo "🔍 Verificando login no OpenShift..."
if ! oc whoami &> /dev/null; then
  echo "❌ Não está logado no cluster OpenShift"
  echo ""
  echo "💡 Para fazer login, execute um dos comandos:"
  echo "   1. Com usuário/senha:"
  echo "      oc login $OCP_SERVER -u $OCP_USER -p \$OCP_PASSWORD --insecure-skip-tls-verify"
  echo ""
  echo "   2. Com token:"
  echo "      oc login $OCP_SERVER --token=\$OCP_TOKEN --insecure-skip-tls-verify"
  echo ""
  exit 1
fi

OC_USER=$(oc whoami)
OC_SERVER=$(oc whoami --show-server)
echo "✅ Logado como: $OC_USER"
echo "   Servidor: $OC_SERVER"
echo ""

# Check if namespace exists
if ! oc get namespace "$NAMESPACE" &> /dev/null; then
  echo "❌ Namespace não encontrado: $NAMESPACE"
  echo ""
  echo "💡 Namespaces disponíveis:"
  oc get namespaces | grep -E "(NAME|apic|api-connect)" || echo "   Nenhum namespace APIC encontrado"
  echo ""
  exit 1
fi
echo "✅ Namespace encontrado: $NAMESPACE"
echo ""

# Create certificate directory
mkdir -p "$CERT_DIR"

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
