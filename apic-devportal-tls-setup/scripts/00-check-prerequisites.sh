#!/usr/bin/env bash
set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.env"

echo "🔍 Verificando pré-requisitos..."
echo ""

# Check if oc is installed
if ! command -v oc &> /dev/null; then
  echo "❌ oc CLI não encontrado. Instale o OpenShift CLI."
  exit 1
else
  echo "✅ oc CLI encontrado: $(oc version --client | head -1)"
fi

# Check if apic is installed
if ! command -v apic &> /dev/null; then
  echo "❌ apic CLI não encontrado. Instale o IBM API Connect CLI."
  exit 1
else
  echo "✅ apic CLI encontrado: $(apic --version)"
fi

# Check if openssl is installed
if ! command -v openssl &> /dev/null; then
  echo "❌ openssl não encontrado."
  exit 1
else
  echo "✅ openssl encontrado: $(openssl version)"
fi

echo ""
echo "🔐 Verificando login no OpenShift..."

# Check if already logged in
if oc whoami &> /dev/null; then
  echo "✅ Já logado no OpenShift como: $(oc whoami)"
  echo "   Servidor: $(oc whoami --show-server)"
else
  echo "⚠️  Não logado no OpenShift. Tentando login..."
  
  if [ -n "$OCP_TOKEN" ]; then
    echo "   Usando token do config.env..."
    oc login --server="$OCP_SERVER" --token="$OCP_TOKEN" --insecure-skip-tls-verify=true
  elif [ -n "$OCP_USER" ] && [ -n "$OCP_PASSWORD" ] && [ "$OCP_PASSWORD" != "CHANGE_ME" ]; then
    echo "   Usando usuário/senha do config.env..."
    oc login --server="$OCP_SERVER" --username="$OCP_USER" --password="$OCP_PASSWORD" --insecure-skip-tls-verify=true
  else
    echo "❌ Credenciais do OCP não configuradas no config.env"
    echo "   Configure OCP_TOKEN ou OCP_USER/OCP_PASSWORD"
    exit 1
  fi
  
  if oc whoami &> /dev/null; then
    echo "✅ Login no OpenShift realizado com sucesso!"
  else
    echo "❌ Falha no login do OpenShift"
    exit 1
  fi
fi

echo ""
echo "📦 Verificando namespace: $APIC_NAMESPACE"

if oc get namespace "$APIC_NAMESPACE" &> /dev/null; then
  echo "✅ Namespace $APIC_NAMESPACE existe"
else
  echo "❌ Namespace $APIC_NAMESPACE não encontrado"
  exit 1
fi

echo ""
echo "🔐 Verificando secrets necessários..."

# Check devportal-admin-client secret
if oc get secret devportal-admin-client -n "$APIC_NAMESPACE" &> /dev/null; then
  echo "✅ Secret devportal-admin-client encontrado"
else
  echo "❌ Secret devportal-admin-client não encontrado no namespace $APIC_NAMESPACE"
  echo "   Execute o deploy do Phase 5 (portal) primeiro"
  exit 1
fi

# Check ingress-ca secret
if oc get secret ingress-ca -n "$APIC_NAMESPACE" &> /dev/null; then
  echo "✅ Secret ingress-ca encontrado"
else
  echo "❌ Secret ingress-ca não encontrado no namespace $APIC_NAMESPACE"
  echo "   Execute o deploy do Phase 1 (certificates) primeiro"
  exit 1
fi

echo ""
echo "🎯 Verificando Developer Portal..."

if oc get devportalcluster -n "$APIC_NAMESPACE" &> /dev/null; then
  PORTAL_STATUS=$(oc get devportalcluster -n "$APIC_NAMESPACE" -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Unknown")
  PORTAL_NAME=$(oc get devportalcluster -n "$APIC_NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "Unknown")
  echo "✅ Developer Portal encontrado: $PORTAL_NAME"
  echo "   Status: $PORTAL_STATUS"
  
  if [ "$PORTAL_STATUS" != "Running" ]; then
    echo "⚠️  Portal não está em estado Running. Aguarde o deploy completar."
  fi
else
  echo "❌ Developer Portal não encontrado no namespace $APIC_NAMESPACE"
  exit 1
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║          ✅ TODOS OS PRÉ-REQUISITOS VERIFICADOS! ✅            ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Você pode prosseguir com o setup do TLS."

# Made with Bob
