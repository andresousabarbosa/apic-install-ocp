# API Connect Platform - Kustomize Project

Este projeto organiza a instalação do IBM API Connect usando Kustomize com uma estrutura modular e reutilizável.

## Estrutura do Projeto

```
01-apic-platform/
├── base/                           # Configurações base reutilizáveis
│   ├── management/                 # ManagementCluster base
│   ├── gateway/                    # GatewayCluster base
│   └── analytics/                  # AnalyticsCluster base
│
└── overlays/                       # Configurações específicas por ambiente
    ├── apic-lab/                   # Ambiente completo (deploy tudo)
    │   ├── certificates/           # Issuers e CA compartilhados
    │   ├── management/
    │   │   ├── certificates/       # Certificate resources (cert-manager)
    │   │   └── patches/            # Patches específicos do ambiente
    │   ├── gateway/
    │   │   ├── certificates/       # Certificate resources (cert-manager)
    │   │   ├── admin-secret.yaml   # Credenciais admin do DataPower
    │   │   └── patches/            # Patches específicos do ambiente
    │   └── analytics/
    │       └── patches/            # Patches específicos do ambiente
    │
    ├── apic-lab-phase1-certs/      # 🆕 Fase 1: Certificados base
    ├── apic-lab-phase2-mgmt/       # 🆕 Fase 2: Management
    ├── apic-lab-phase3-gateway/    # 🆕 Fase 3: Gateway
    └── apic-lab-phase4-analytics/  # 🆕 Fase 4: Analytics
```

## Gerenciamento de Certificados

Este projeto usa **cert-manager** para gerenciar certificados automaticamente:

- ✅ **Certificate resources** em vez de secrets estáticas
- ✅ Renovação automática antes de expirar
- ✅ Sem dados sensíveis hardcoded no Git
- ✅ Cert-manager cria e atualiza as secrets automaticamente

### Certificados Gerenciados

**Management:**
- `analytics-ingestion-client` - Para comunicação Management → Analytics
- `gateway-client-client` - Para comunicação Management → Gateway
- `portal-admin-client` - Para comunicação Management → Portal
- `wmapigateway-mgmt-client` - Para comunicação Management → WM API Gateway

**Gateway:**
- `gateway-peering` - Para comunicação entre gateways
- `gateway-service` - Para o serviço do gateway

**Infraestrutura:**
- `selfsigning-issuer` - Issuer raiz self-signed
- `ingress-issuer` - Issuer CA para certificados de ingress
- `ingress-ca` - CA compartilhado

## Deploy

> **⚠️ Importante**: Os comandos abaixo assumem que você está na pasta `repo/`. Se estiver na raiz do projeto, adicione `repo/` antes dos caminhos.

### Opção 1: Deploy por Fases (Recomendado) 🆕

Para controle granular e troubleshooting facilitado, use os overlays por fase:

```bash
# Certifique-se de estar na pasta correta
cd /caminho/para/install-apic/repo

# Fase 1: Certificados Base (2-5 minutos)
oc apply -k 01-apic-platform/overlays/apic-lab-phase1-certs
oc wait --for=condition=Ready certificate/ingress-ca -n apic-lab --timeout=300s

# Fase 2: Management (20-30 minutos)
oc apply -k 01-apic-platform/overlays/apic-lab-phase2-mgmt
oc wait --for=condition=Ready managementcluster/management -n apic-lab --timeout=1800s

# Configuração inicial via API REST
cd ..
./scripts/87j-apic-initial-config.sh -n apic-lab
./scripts/87k-apic-new-porg-lur.sh -n apic-lab -u "user,email@domain.com,First,Last"

# Fase 3: Gateway (15-20 minutos)
cd repo
oc apply -k 01-apic-platform/overlays/apic-lab-phase3-gateway
oc wait --for=condition=Ready gatewaycluster/gwv6-apic-lab -n apic-lab --timeout=1800s

# Configuração Gateway via API REST
cd ..
./scripts/87m-apic-dp-api-gateway-config.sh -n apic-lab

# Fase 4: Analytics - Opcional (20-30 minutos)
cd repo
oc apply -k 01-apic-platform/overlays/apic-lab-phase4-analytics
oc wait --for=condition=Ready analyticscluster/analytics -n apic-lab --timeout=1800s

# Configuração Analytics via API REST
cd ..
./scripts/87l-apic-analytics-config.sh -n apic-lab
```

**Vantagens do Deploy por Fases:**
- ✅ Controle total sobre a ordem de instalação
- ✅ Troubleshooting mais fácil (isola problemas por componente)
- ✅ Permite validar cada etapa antes de prosseguir
- ✅ Ideal para ambientes de produção

### Opção 2: Deploy Completo (Tudo de uma vez)

```bash
# Certifique-se de estar na pasta correta
cd /caminho/para/install-apic/repo

# Deploy tudo
oc apply -k 01-apic-platform/overlays/apic-lab

# Aguardar componentes prontos
oc wait --for=condition=Ready certificate --all -n apic-lab --timeout=300s
oc wait --for=condition=Ready managementcluster/management -n apic-lab --timeout=1800s
oc wait --for=condition=Ready gatewaycluster/gwv6-apic-lab -n apic-lab --timeout=1800s
oc wait --for=condition=Ready analyticscluster/analytics -n apic-lab --timeout=1800s

# Executar configurações via API REST
cd ..
./scripts/87j-apic-initial-config.sh -n apic-lab
./scripts/87k-apic-new-porg-lur.sh -n apic-lab -u "user,email@domain.com,First,Last"
./scripts/87m-apic-dp-api-gateway-config.sh -n apic-lab
./scripts/87l-apic-analytics-config.sh -n apic-lab
```

### Opção 3: Deploy Sequencial (Componentes Individuais)

```bash
# Certifique-se de estar na pasta correta
cd /caminho/para/install-apic/repo

# 1. Certificados e Issuers primeiro
oc apply -k 01-apic-platform/overlays/apic-lab/certificates

# 2. Management e seus certificados
oc apply -k 01-apic-platform/overlays/apic-lab/management

# 3. Aguardar Management ficar Ready
oc wait --for=condition=Ready managementcluster/management -n apic-lab --timeout=30m

# 4. Gateway e Analytics (podem ser paralelos)
oc apply -k 01-apic-platform/overlays/apic-lab/gateway
oc apply -k 01-apic-platform/overlays/apic-lab/analytics
```

## Configuração Pós-Deploy

Após o deploy dos recursos Kubernetes, é necessário executar configurações via API REST:

### 1. Configuração Inicial do Management
```bash
./scripts/87j-apic-initial-config.sh -n apic-lab
```
**O que faz:**
- Configura User Registry (LUR)
- Cria Mail Server (MailPit)
- Atualiza Cloud Settings

### 2. Criar Provider Organization
```bash
./scripts/87k-apic-new-porg-lur.sh -n apic-lab -u "user,email@domain.com,First,Last"
```
**O que faz:**
- Cria usuário no LUR
- Cria Provider Organization
- Armazena credenciais em secret

### 3. Registrar Gateway na Topologia
```bash
./scripts/87m-apic-dp-api-gateway-config.sh -n apic-lab
```
**O que faz:**
- Registra Gateway Service no Management
- Cria TLS Client/Server Profiles
- Associa com Analytics (se existir)

### 4. Registrar Analytics na Topologia
```bash
./scripts/87l-apic-analytics-config.sh -n apic-lab
```
**O que faz:**
- Registra Analytics Service no Management
- Cria TLS Client Profile

## Monitoramento

### Verificar Status dos Componentes

```bash
# Management
oc get managementcluster -n apic-lab
oc describe managementcluster management -n apic-lab

# Gateway (nome atualizado: gwv6-apic-lab)
oc get gatewaycluster -n apic-lab
oc describe gatewaycluster gwv6-apic-lab -n apic-lab

# Analytics
oc get analyticscluster -n apic-lab
oc describe analyticscluster analytics -n apic-lab

# Todos os componentes
oc get managementcluster,gatewaycluster,analyticscluster -n apic-lab
```

### Verificar Certificados

```bash
# Listar todos os Certificate resources
oc get certificate -n apic-lab

# Ver detalhes de um certificado específico
oc describe certificate analytics-ingestion-client -n apic-lab

# Verificar se as secrets foram criadas
oc get secret -n apic-lab | grep -E "(analytics|gateway|portal|wmapigateway)"

# Verificar validade dos certificados
oc get certificate -n apic-lab -o custom-columns=NAME:.metadata.name,READY:.status.conditions[0].status,EXPIRATION:.status.notAfter
```

### Capturar Credenciais

```bash
# Senha do admin do Management
oc get secret management-admin-secret -n apic-lab -o jsonpath='{.data.password}' | base64 -d

# Senha do admin do Gateway (DataPower)
oc get secret admin-secret -n apic-lab -o jsonpath='{.data.password}' | base64 -d
```

### Endpoints Configurados

**Management:**
- Platform API: `https://api.apiclab.apps.itz-h4eig5.infra01-lb.lon04.techzone.ibm.com`
- API Manager: `https://manager.apiclab.apps.itz-h4eig5.infra01-lb.lon04.techzone.ibm.com`
- Cloud Manager: `https://admin.apiclab.apps.itz-h4eig5.infra01-lb.lon04.techzone.ibm.com`

**Gateway:**
- Gateway: `https://rgw.apiclab.apps.itz-h4eig5.infra01-lb.lon04.techzone.ibm.com`
- Gateway Manager: `https://rgwd.apiclab.apps.itz-h4eig5.infra01-lb.lon04.techzone.ibm.com`

**Analytics:**
- Analytics Ingestion: `https://ai.apiclab.apps.itz-h4eig5.infra01-lb.lon04.techzone.ibm.com`

### Logs do Operador

```bash
# Logs do operador API Connect
oc logs -n openshift-operators deployment/ibm-apiconnect -f

# Filtrar por namespace específico
oc logs -n openshift-operators deployment/ibm-apiconnect -f | grep '"namespace":"apic-lab"'

# Ver apenas erros
oc logs -n openshift-operators deployment/ibm-apiconnect --since=10m | egrep -i "error|fail|panic"

# Logs do DataPower Operator
oc logs -n openshift-operators deployment/datapower-operator -f
```

## Customização para Novos Ambientes

Para criar um novo ambiente (ex: `apic-prod`):

1. Copie o overlay existente:
```bash
cp -r overlays/apic-lab overlays/apic-prod
```

2. Atualize os patches com valores específicos:
   - Hostnames nos patches de cada componente
   - Storage classes se necessário
   - Profiles de recursos
   - Nome do namespace

3. Atualize o nome do Gateway no base se necessário:
   - O base atual tem `name: gwv6-apic-lab` (específico do ambiente)
   - Para reutilizar em outro ambiente, considere usar um nome genérico

4. Deploy:
```bash
oc apply -k 01-apic-platform/overlays/apic-prod
```

## Troubleshooting

### Certificados não são criados

```bash
# Verificar se cert-manager está instalado
oc get pods -n cert-manager

# Verificar logs do cert-manager
oc logs -n cert-manager deployment/cert-manager -f

# Verificar se o Issuer está pronto
oc get issuer -n apic-lab

# Ver detalhes de um Certificate que não está Ready
oc describe certificate <cert-name> -n apic-lab
```

### Management não fica Ready

```bash
# Ver eventos do namespace
oc get events -n apic-lab --sort-by=.metadata.creationTimestamp

# Ver pods
oc get pods -n apic-lab

# Ver PVCs
oc get pvc -n apic-lab

# Ver logs de um pod específico
oc logs -n apic-lab <pod-name> -f
```

### Gateway não registra no Management

```bash
# Verificar se o Gateway está Ready
oc get gatewaycluster gwv6-apic-lab -n apic-lab

# Verificar certificados do Gateway
oc get certificate -n apic-lab | grep gateway

# Verificar se o script de configuração foi executado
./scripts/87m-apic-dp-api-gateway-config.sh -n apic-lab

# Verificar logs do Gateway Manager
oc logs -n apic-lab <gateway-manager-pod> -f
```

### Patches não são aplicados

```bash
# Verificar se o nome do recurso no patch corresponde ao base
# Gateway: nome deve ser 'gwv6-apic-lab' (não 'gateway')
# Management: nome deve ser 'management'
# Analytics: nome deve ser 'analytics'

# Testar o build do kustomize sem aplicar
oc kustomize 01-apic-platform/overlays/apic-lab | less
```

## Documentação Adicional

Para informações detalhadas sobre o deploy por fases, consulte:
- **[README-PHASES.md](overlays/README-PHASES.md)** - Guia completo do deploy por fases

## Referências

- [IBM API Connect Documentation](https://www.ibm.com/docs/en/api-connect)
- [Kustomize Documentation](https://kustomize.io/)
- [Cert-Manager Documentation](https://cert-manager.io/docs/)
- [OpenShift Documentation](https://docs.openshift.com/)