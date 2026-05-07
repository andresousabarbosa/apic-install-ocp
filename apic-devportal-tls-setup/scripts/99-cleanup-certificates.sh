#!/usr/bin/env bash
set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Certificate directory
CERT_DIR="${SCRIPT_DIR}/../temp-certificates"

echo "🧹 Limpando certificados temporários..."
echo "📁 Diretório: $CERT_DIR"

if [ -d "$CERT_DIR" ]; then
  echo ""
  echo "📋 Arquivos a serem removidos:"
  ls -lh "$CERT_DIR" 2>/dev/null || echo "  (diretório vazio)"
  
  echo ""
  read -p "❓ Confirma a remoção dos certificados temporários? (s/N): " -n 1 -r
  echo
  
  if [[ $REPLY =~ ^[Ss]$ ]]; then
    rm -rf "$CERT_DIR"
    echo "✅ Certificados temporários removidos com sucesso!"
  else
    echo "❌ Operação cancelada. Certificados mantidos em: $CERT_DIR"
  fi
else
  echo "ℹ️  Diretório de certificados não existe: $CERT_DIR"
fi

# Made with Bob
