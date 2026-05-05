# API Connect - Deploy por Fases

Este diretório contém overlays organizados por fase de deploy, permitindo um controle granular sobre a ordem de instalação dos componentes do API Connect.

## 📁 Estrutura de Overlays

```
overlays/
├── apic-lab/                    # Overlay completo (deploy tudo de uma vez)
├── apic-lab-phase1-certs/       # Fase 1: Certificados base (Issuers e CA)
├── apic-lab-phase2-mgmt/        # Fase 2: Management + certificados cliente
├── apic-lab-phase3-gateway/     # Fase 3: Gateway + certificados
└── apic-lab-phase4-analytics/   # Fase 4: Analytics (opcional)
```

## 🚀 Deploy Sequencial (Recomendado)

### Pré-requisitos

1. Operadores instalados:
   ```bash
   # Common Services
   ./scripts/00d-cp4i-operators-install.sh -o common-services
   
   # API Connect e DataPower operators
   oc apply -k repo/00-infra-operators
   ```

2. Aguardar operadores prontos:
   ```bash
   oc get csv -n openshift-operators | grep -E 'ibm-apiconnect|datapower'
   ```

### Fase 1: Certificados Base

Deploy dos Issuers e CA raiz que serão usados por todos os componentes:

```bash
# Deploy
oc apply -k repo/01-apic-platform/overlays/apic-lab-phase1-certs

# Aguardar certificados prontos
oc wait --for=condition=Ready certificate/ingress-ca -n apic-lab --timeout=300s

# Verificar
oc get issuer,certificate -n apic-lab
```

**Recursos criados:**
- Namespace `apic-lab`
- Issuer `selfsigning-issuer` (self-signed)
- Certificate `ingress-ca` (CA raiz)
- Issuer `ingress-issuer` (baseado na CA)

### Fase 2: Management Subsystem

Deploy do Management com seus certificados cliente:

```bash
# Deploy
oc apply -k repo/01-apic-platform/overlays/apic-lab-phase2-mgmt

# Aguardar Management pronto (pode levar 20-30 minutos)
oc wait --for=condition=Ready managementcluster/management -n apic-lab --timeout=1800s

# Verificar status
oc get managementcluster,certificate -n apic-lab
oc get pods -n apic-lab | grep management
```

**Recursos criados:**
- ManagementCluster `management`
- Certificates:
  - `portal-admin-client`
  - `gateway-client-client`
  - `analytics-ingestion-client`
  - `wmapigateway-mgmt-client`

**Endpoints criados:**
- Platform API: `https://api.apiclab.apps.itz-h4eig5.infra01-lb.lon04.techzone.ibm.com`
- API Manager: `https://manager.apiclab.apps.itz-h4eig5.infra01-lb.lon04.techzone.ibm.com`
- Cloud Manager: `https://admin.apiclab.apps.itz-h4eig5.infra01-lb.lon04.techzone.ibm.com`

### Configuração Inicial do Management

Após o Management estar pronto, executar configurações via API REST:

```bash
# 1. Configuração inicial (mail server, user registry)
./scripts/87j-apic-initial-config.sh -n apic-lab

# 2. Criar Provider Organization e usuário
./scripts/87k-apic-new-porg-lur.sh -n apic-lab -u "user,email@domain.com,First,Last"
```

### Fase 3: Gateway Subsystem

Deploy do DataPower Gateway:

```bash
# Deploy
oc apply -k repo/01-apic-platform/overlays/apic-lab-phase3-gateway

# Aguardar Gateway pronto (pode levar 15-20 minutos)
oc wait --for=condition=Ready gatewaycluster/gateway -n apic-lab --timeout=1800s

# Verificar status
oc get gatewaycluster,certificate -n apic-lab
oc get pods -n apic-lab | grep gateway
```

**Recursos criados:**
- GatewayCluster `gateway`
- Secret `admin-secret` (senha do DataPower)
- Certificates:
  - `gateway-service`
  - `gateway-peering`

**Endpoints criados:**
- Gateway: `https://rgw.apiclab.apps.itz-h4eig5.infra01-lb.lon04.techzone.ibm.com`
- Gateway Manager: `https://rgwd.apiclab.apps.itz-h4eig5.infra01-lb.lon04.techzone.ibm.com`

### Configuração do Gateway

Registrar o Gateway na topologia do Management:

```bash
# Registrar Gateway Service
./scripts/87m-apic-dp-api-gateway-config.sh -n apic-lab
```

### Fase 4: Analytics Subsystem (Opcional)

Deploy do Analytics:

```bash
# Deploy
oc apply -k repo/01-apic-platform/overlays/apic-lab-phase4-analytics

# Aguardar Analytics pronto (pode levar 20-30 minutos)
oc wait --for=condition=Ready analyticscluster/analytics -n apic-lab --timeout=1800s

# Verificar status
oc get analyticscluster -n apic-lab
oc get pods -n apic-lab | grep analytics
```

**Recursos criados:**
- AnalyticsCluster `analytics`

**Endpoints criados:**
- Analytics Ingestion: `https://ai.apiclab.apps.itz-h4eig5.infra01-lb.lon04.techzone.ibm.com`

### Configuração do Analytics

Registrar o Analytics na topologia do Management:

```bash
# Registrar Analytics Service
./scripts/87l-apic-analytics-config.sh -n apic-lab
```

## 🎯 Deploy Completo (Alternativa)

Se preferir fazer o deploy de tudo de uma vez:

```bash
# Deploy tudo
oc apply -k repo/01-apic-platform/overlays/apic-lab

# Aguardar todos os componentes
oc wait --for=condition=Ready certificate --all -n apic-lab --timeout=300s
oc wait --for=condition=Ready managementcluster/management -n apic-lab --timeout=1800s
oc wait --for=condition=Ready gatewaycluster/gateway -n apic-lab --timeout=1800s
oc wait --for=condition=Ready analyticscluster/analytics -n apic-lab --timeout=1800s

# Executar configurações
./scripts/87j-apic-initial-config.sh -n apic-lab
./scripts/87k-apic-new-porg-lur.sh -n apic-lab -u "user,email@domain.com,First,Last"
./scripts/87m-apic-dp-api-gateway-config.sh -n apic-lab
./scripts/87l-apic-analytics-config.sh -n apic-lab
```

## 🔍 Verificação e Troubleshooting

### Verificar certificados
```bash
oc get certificate -n apic-lab
oc describe certificate <cert-name> -n apic-lab
```

### Verificar clusters
```bash
oc get managementcluster,gatewaycluster,analyticscluster -n apic-lab
oc describe managementcluster management -n apic-lab
```

### Logs dos operadores
```bash
oc logs -n openshift-operators deployment/ibm-apiconnect -f
oc logs -n openshift-operators deployment/datapower-operator -f
```

### Logs dos pods
```bash
oc logs -n apic-lab <pod-name> -f
```

## 📝 Notas Importantes

1. **Ordem de Deploy**: Sempre seguir a ordem das fases (1 → 2 → 3 → 4)
2. **Aguardar Conclusão**: Cada fase deve estar completamente pronta antes de iniciar a próxima
3. **Certificados**: A Fase 1 deve estar pronta antes de qualquer outra fase
4. **Configurações API REST**: Scripts de configuração devem ser executados após o deploy dos recursos Kubernetes
5. **Namespace**: Todos os overlays usam o namespace `apic-lab`
6. **Customização**: Para usar em outro ambiente, ajustar os hostnames nos patches de cada fase

## 🔄 Atualização de Componentes

Para atualizar um componente específico:

```bash
# Atualizar apenas Management
oc apply -k repo/01-apic-platform/overlays/apic-lab-phase2-mgmt

# Atualizar apenas Gateway
oc apply -k repo/01-apic-platform/overlays/apic-lab-phase3-gateway
```

## 🗑️ Remoção

Para remover componentes na ordem inversa:

```bash
# Remover Analytics
oc delete -k repo/01-apic-platform/overlays/apic-lab-phase4-analytics

# Remover Gateway
oc delete -k repo/01-apic-platform/overlays/apic-lab-phase3-gateway

# Remover Management
oc delete -k repo/01-apic-platform/overlays/apic-lab-phase2-mgmt

# Remover Certificados
oc delete -k repo/01-apic-platform/overlays/apic-lab-phase1-certs

# Remover namespace
oc delete namespace apic-lab