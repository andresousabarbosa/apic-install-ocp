#!/usr/bin/env bash
set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  API Connect Developer Portal TLS Setup - Complete Workflow   ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Function to run script with error handling
run_script() {
  local script_name=$1
  local description=$2
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "▶️  Step: $description"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  if bash "${SCRIPT_DIR}/${script_name}"; then
    echo ""
    echo "✅ $description - COMPLETED"
    echo ""
  else
    echo ""
    echo "❌ $description - FAILED"
    echo ""
    echo "Abortando execução. Corrija o erro e tente novamente."
    exit 1
  fi
}

# Step 0: Check prerequisites
run_script "00-check-prerequisites.sh" "Verificação de pré-requisitos"

# Step 1: Login to APIC
run_script "00-login.sh" "Login no API Connect"

# Step 2: Extract certificates
run_script "01-extract-certificates.sh" "Extração de certificados dos secrets K8s"

# Step 3: Create keystore
run_script "10-create-keystore.sh" "Criação do Keystore no Cloud Manager"

# Step 4: Create truststore
run_script "11-create-truststore.sh" "Criação do Truststore no Cloud Manager"

# Step 5: Create TLS Client Profile
run_script "12-create-tls-client-profile.sh" "Criação do TLS Client Profile"

# Step 6: Register Developer Portal
run_script "20-register-devportal.sh" "Registro do Developer Portal"

# Step 7: Validate registration
run_script "30-validate-registration.sh" "Validação do registro do Portal"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    🎉 SETUP COMPLETO! 🎉                       ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "✅ Todos os passos foram executados com sucesso!"
echo ""
echo "📋 Próximos passos:"
echo "  1. Verifique o TLS Client Profile no Cloud Manager:"
echo "     Resources → TLS → Keystores"
echo "  2. Teste o acesso ao Developer Portal"
echo "  3. Execute o script de limpeza quando terminar:"
echo "     ./99-cleanup-certificates.sh"
echo ""
