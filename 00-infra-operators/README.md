# API Connect - Infraestrutura e Operadores

Esta pasta contém os recursos de **infraestrutura cluster-scoped** necessários para instalar os operadores do IBM API Connect e DataPower.

> **📌 Importante**: Esta é a **primeira etapa** da instalação. Os operadores devem estar instalados e prontos antes de fazer o deploy dos runtimes (Management, Gateway, Analytics).

## 🎯 Objetivo

Separar a instalação da **infraestrutura** (operadores) do **runtime** (instâncias do API Connect):

- **00-infra-operators** → Operadores (cluster-scoped, executado uma vez)
- **01-apic-platform** → Runtimes das APIs (namespace-scoped, pode ter múltiplos ambientes)

## 📁 Estrutura

```
00-infra-operators/
├── kustomization.yaml              # Orquestra todos os recursos
├── entitlement/                    # IBM Entitlement Key
│   ├── namespace.yaml              # Namespace: ibm-entitlement-key
│   ├── entitlement-secret.yaml     # Secret com a chave
│   ├── entitlement/
│   │   └── .dockerconfigjson       # Arquivo com a chave (não commitado)
│   └── kustomization.yaml
├── catalog-sources/                # Catálogos de operadores
│   ├── ibm-apiconnect-catalog.yaml # Catálogo API Connect v7.2
│   ├── ibm-datapower-operator-catalog.yaml # Catálogo DataPower
│   └── kustomization.yaml
├── subscriptions/                  # Subscriptions dos operadores
│   ├── 04-api-connect-v12-subscription.yaml # Subscription API Connect
│   ├── datapower-operator.yaml     # Subscription DataPower
│   └── kustomization.yaml
└── ibm-common-services/            # (Opcional - não usado atualmente)
    ├── namespace.yaml
    └── opencloud-operators.yaml
```

## 🚀 Instalação

### Pré-requisitos

1. **OpenShift Cluster** com acesso de cluster-admin
2. **IBM Entitlement Key** - Obter em [IBM Container Library](https://myibm.ibm.com/products-services/containerlibrary)
3. **oc CLI** instalado e configurado

### Passo 1: Configurar IBM Entitlement Key

A chave de entitlement é necessária para baixar as imagens dos operadores do IBM Container Registry.

```bash
# Navegar para a pasta do projeto
cd /caminho/para/install-apic/repo

# Criar o arquivo com a chave (não será commitado no Git)
echo -n 'cp:SUA_CHAVE_AQUI' | base64 > 00-infra-operators/entitlement/entitlement/.dockerconfigjson
```

**Exemplo de chave:**
```bash
echo -n 'cp:eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJJQk0gTWFya2V0cGxhY2UiLCJpYXQiOjE3NzUwMTE4NjgsImp0aSI6ImI5MjE3YzJlZTUyZjQxMmViOWYzMWRmNTMzYjAwODg4In0.JCJkhF-Ehrs1JpwUUCg627R1kjcv4PAPujeG4lfMQvU' | base64 > 00-infra-operators/entitlement/entitlement/.dockerconfigjson
```

> **⚠️ Segurança**: O arquivo `.dockerconfigjson` está no `.gitignore` e não será commitado. Cada ambiente deve ter sua própria chave.

### Passo 2: Deploy dos Operadores

```bash
# Certifique-se de estar na pasta repo/
cd /caminho/para/install-apic/repo

# Deploy de todos os recursos
oc apply -k 00-infra-operators/

# OU deploy passo a passo (recomendado para troubleshooting)

# 1. Entitlement Key
oc apply -k 00-infra-operators/entitlement

# 2. Catalog Sources
oc apply -k 00-infra-operators/catalog-sources

# 3. Subscriptions
oc apply -k 00-infra-operators/subscriptions
```

### Passo 3: Verificar Instalação

```bash
# Verificar Catalog Sources
oc get catalogsources -n openshift-marketplace
# Deve mostrar: ibm-apiconnect-catalog, ibm-datapower-operator-catalog

# Verificar Subscriptions
oc get subscription -n openshift-operators
# Deve mostrar: ibm-apiconnect, datapower-operator

# Verificar CSVs (Cluster Service Versions)
oc get csv -n openshift-operators
# Deve mostrar os operadores com status "Succeeded"

# Verificar Deployments dos operadores
oc get deployment -n openshift-operators | grep -E "apiconnect|datapower"
# Deve mostrar: ibm-apiconnect, datapower-operator

# Verificar se os pods estão rodando
oc get pods -n openshift-operators | grep -E "apiconnect|datapower"
```

## 📊 Recursos Instalados

### 1. Entitlement Key
- **Namespace**: `ibm-entitlement-key`
- **Secret**: `ibm-entitlement-key`
- **Tipo**: `kubernetes.io/dockerconfigjson`
- **Uso**: Autenticação no IBM Container Registry

### 2. Catalog Sources
- **ibm-apiconnect-catalog**
  - Versão: v7.2.0
  - Imagem: `icr.io/cpopen/ibm-apiconnect-catalog@sha256:7e933f9139aee40520bc29e022baf16b0f6664e331eb7e68212dbc49ca18574b`
  - Namespace: `openshift-marketplace`

- **ibm-datapower-operator-catalog**
  - Namespace: `openshift-marketplace`

### 3. Subscriptions
- **ibm-apiconnect**
  - Channel: `v7.2`
  - Namespace: `openshift-operators`
  - Instala: API Connect Operator

- **datapower-operator**
  - Namespace: `openshift-operators`
  - Instala: DataPower Operator

## 🔄 Atualização

### Atualizar Catalog Source

Para usar uma versão mais recente do catálogo:

```bash
# Editar o arquivo
vi 00-infra-operators/catalog-sources/ibm-apiconnect-catalog.yaml

# Atualizar a imagem para a versão desejada
# image: icr.io/cpopen/ibm-apiconnect-catalog:latest
# OU
# image: icr.io/cpopen/ibm-apiconnect-catalog@sha256:NOVO_HASH

# Aplicar a mudança
oc apply -k 00-infra-operators/catalog-sources
```

### Atualizar Operadores

Os operadores são atualizados automaticamente pelo OLM (Operator Lifecycle Manager) quando uma nova versão está disponível no catálogo, desde que o `installPlanApproval` seja `Automatic` (padrão).

Para atualização manual:
```bash
# Ver install plans pendentes
oc get installplan -n openshift-operators

# Aprovar um install plan específico
oc patch installplan <install-plan-name> -n openshift-operators --type merge --patch '{"spec":{"approved":true}}'
```

## 🗑️ Remoção

Para remover os operadores (cuidado - isso afetará todas as instâncias do API Connect):

```bash
# Remover subscriptions (para os operadores)
oc delete -k 00-infra-operators/subscriptions

# Remover catalog sources
oc delete -k 00-infra-operators/catalog-sources

# Remover CSVs manualmente se necessário
oc delete csv -n openshift-operators ibm-apiconnect.v<version>
oc delete csv -n openshift-operators datapower-operator.v<version>

# Remover entitlement key
oc delete -k 00-infra-operators/entitlement
```

> **⚠️ Atenção**: Remover os operadores não remove as instâncias do API Connect (ManagementCluster, GatewayCluster, etc). Você deve removê-las primeiro.

## 🔍 Troubleshooting

### Catalog Source não aparece

```bash
# Verificar se o pod do catalog source está rodando
oc get pods -n openshift-marketplace | grep apiconnect

# Ver logs do catalog source
oc logs -n openshift-marketplace <catalog-source-pod>

# Verificar se a imagem está acessível
oc describe catalogsource ibm-apiconnect-catalog -n openshift-marketplace
```

### Subscription não instala o operador

```bash
# Verificar status da subscription
oc describe subscription ibm-apiconnect -n openshift-operators

# Verificar install plans
oc get installplan -n openshift-operators

# Ver eventos
oc get events -n openshift-operators --sort-by=.metadata.creationTimestamp
```

### Operador não inicia

```bash
# Verificar deployment
oc get deployment ibm-apiconnect -n openshift-operators

# Ver logs do operador
oc logs -n openshift-operators deployment/ibm-apiconnect -f

# Verificar se a entitlement key está correta
oc get secret ibm-entitlement-key -n ibm-entitlement-key -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d
```

### Erro de autenticação no registry

```bash
# Verificar se a entitlement key está válida
# 1. Acessar https://myibm.ibm.com/products-services/containerlibrary
# 2. Copiar a nova chave
# 3. Atualizar o arquivo .dockerconfigjson
# 4. Reaplicar o secret

oc delete secret ibm-entitlement-key -n ibm-entitlement-key
oc apply -k 00-infra-operators/entitlement
```

## 📝 Notas Importantes

1. **Cluster-Scoped**: Os operadores são instalados no namespace `openshift-operators` e têm permissões cluster-wide
2. **Uma vez por cluster**: Você só precisa instalar os operadores uma vez. Depois pode criar múltiplas instâncias do API Connect em diferentes namespaces
3. **Entitlement Key**: Cada ambiente deve ter sua própria chave. Não commitar no Git
4. **Versão do Catálogo**: O catálogo está fixado em uma versão específica (SHA256). Para usar `latest`, descomente a linha correspondente

## 🔗 Próximos Passos

Após os operadores estarem instalados e prontos:

1. ✅ Operadores instalados (você está aqui)
2. ➡️ Deploy do runtime: `01-apic-platform/`
   - Escolha entre deploy completo ou por fases
   - Consulte: [01-apic-platform/README.md](../01-apic-platform/README.md)

## 📚 Referências

- [IBM API Connect Operator Documentation](https://www.ibm.com/docs/en/api-connect/10.0.x?topic=operator-installing-api-connect)
- [IBM Container Library](https://myibm.ibm.com/products-services/containerlibrary)
- [OpenShift Operator Lifecycle Manager](https://docs.openshift.com/container-platform/latest/operators/understanding/olm/olm-understanding-olm.html)