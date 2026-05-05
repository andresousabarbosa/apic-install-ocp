# API Connect Platform - Kustomize Project

Este projeto organiza a instalação do IBM API Connect usando Kustomize com uma estrutura modular e reutilizável.

## Estrutura do Projeto

```
01-apic-platform/
├── base/                           # Configurações base reutilizáveis
│   ├── management/                 # ManagementCluster genérico
│   ├── gateway/                    # GatewayCluster genérico
│   └── analytics/                  # AnalyticsCluster genérico
│
└── overlays/                       # Configurações específicas por ambiente
    └── apic-lab/                   # Ambiente de laboratório
        ├── certificates/           # Issuers e CA compartilhados
        ├── management/
        │   ├── certificates/       # Certificate resources (cert-manager)
        │   └── patches/            # Patches específicos do ambiente
        ├── gateway/
        │   ├── certificates/       # Certificate resources (cert-manager)
        │   ├── admin-secret.yaml   # Credenciais admin do DataPower
        │   └── patches/            # Patches específicos do ambiente
        └── analytics/
            └── patches/            # Patches específicos do ambiente
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

### Opção 1: Deploy Completo (Tudo de uma vez)

```bash
oc apply -k repo/01-apic-platform/overlays/apic-lab
```

### Opção 2: Deploy Sequencial (Recomendado)

Para garantir que os componentes sejam criados na ordem correta:

```bash
# 1. Certificados e Issuers primeiro
oc apply -k repo/01-apic-platform/overlays/apic-lab/certificates

# 2. Management e seus certificados
oc apply -k repo/01-apic-platform/overlays/apic-lab/management

# 3. Aguardar Management ficar Ready
oc wait --for=condition=Ready managementcluster/management -n apic-lab --timeout=30m

# 4. Gateway e Analytics (podem ser paralelos)
oc apply -k repo/01-apic-platform/overlays/apic-lab/gateway
oc apply -k repo/01-apic-platform/overlays/apic-lab/analytics
```

### Opção 3: Deploy por Componente

```bash
# Apenas Management
oc apply -k repo/01-apic-platform/overlays/apic-lab/management

# Apenas Gateway
oc apply -k repo/01-apic-platform/overlays/apic-lab/gateway

# Apenas Analytics
oc apply -k repo/01-apic-platform/overlays/apic-lab/analytics
```

## Monitoramento

### Verificar Status dos Componentes

```bash
# Management
oc get managementcluster -n apic-lab
oc describe managementcluster management -n apic-lab

# Gateway
oc get gatewaycluster -n apic-lab
oc describe gatewaycluster gateway -n apic-lab

# Analytics
oc get analyticscluster -n apic-lab
oc describe analyticscluster analytics -n apic-lab
```

### Verificar Certificados

```bash
# Listar todos os Certificate resources
oc get certificate -n apic-lab

# Ver detalhes de um certificado específico
oc describe certificate analytics-ingestion-client -n apic-lab

# Verificar se as secrets foram criadas
oc get secret -n apic-lab | grep -E "(analytics|gateway|portal|wmapigateway)"
```

### Capturar senha para login no Admin

```bash
oc get secret management-admin-secret -n apic-lab -o jsonpath='{.data.password}' | base64 -d
admin/4g38XeHh2Ouv
```

### Executar configuracao via interface

Servicos configurados (Topologia)
Data Power 

Management terminal in the gateway service
https://rgwd.apiclab.apps.itz-h4eig5.infra01-lb.lon04.techzone.ibm.com

API endpoint base 
Você colocou:
https://rgw.apiclab.apps.itz-h4eig5.infra01-lb.lon04.techzone.ibm.com

Analytic

https://ai.apiclab.apps.itz-h4eig5.infra01-lb.lon04.techzone.ibm.com

No API Dentro do Sandbox
Associar o Gateway

Dentro do Cloud Manager
Criado uma organizacao e definido a senha.

Depois que criar o analytic config tem que Clicar no Gateway e associar o analytic que vai capturar as informacoes

### Logs do Operador

```bash
# Logs do operador API Connect
oc logs -n openshift-operators deployment/ibm-apiconnect -f

# Filtrar por namespace específico
oc logs -n openshift-operators deployment/ibm-apiconnect -f | grep '"namespace":"apic-lab"'

# Ver apenas erros
oc logs -n openshift-operators deployment/ibm-apiconnect --since=10m | egrep -i "error|fail|panic"
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

3. Deploy:
```bash
oc apply -k repo/01-apic-platform/overlays/apic-prod
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
```

### Management não fica Ready

```bash
# Ver eventos do namespace
oc get events -n apic-lab --sort-by=.metadata.creationTimestamp

# Ver pods
oc get pods -n apic-lab

# Ver PVCs
oc get pvc -n apic-lab
```

## Referências

- [IBM API Connect Documentation](https://www.ibm.com/docs/en/api-connect)
- [Kustomize Documentation](https://kustomize.io/)
- [Cert-Manager Documentation](https://cert-manager.io/docs/)