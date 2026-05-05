#!/usr/bin/env bash

# ===== MANAGEMENT ENDPOINTS =====
APIC_MGMT_PLATFORM_API="https://api.apiclab.apps.itz-h4eig5.infra01-lb.lon04.techzone.ibm.com"

# ===== CREDENTIALS (ajuste se necessário) =====
APIC_ADMIN_USER="admin"
APIC_ADMIN_PASSWORD="manager@2026"

# ===== WORK FILES =====
WORKDIR="$(pwd)/.work"
TOKEN_FILE="${WORKDIR}/platform-token.json"

mkdir -p "${WORKDIR}"