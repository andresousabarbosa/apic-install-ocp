# API Connect Developer Portal TLS Setup

Este diretório contém scripts para configurar certificados TLS e registrar o Developer Portal (wM) no API Connect Cloud Manager.

## 📋 Pré-requisitos

### Ferramentas Necessárias

- `oc` - OpenShift CLI
- `apic` - API Connect CLI (versão 12.x)
- `jq` - JSON processor
- `openssl` - Para manipulação de certificados

### Acesso Necessário

- Acesso ao cluster OpenShift com permissões no namespace do APIC
- Credenciais de administrador do API Connect Cloud Manager
- Developer Portal já implantado no cluster

## 🚀 Início Rápido

### 1. Configurar Ambiente

Edite o arquivo `config.env` com suas configurações:

```bash
# Edite apenas as seções "Static Configuration"
vi config.env
```

Principais configurações a ajustar:
- `APIC_PASSWORD` - Senha do admin do Cloud Manager
- `APIC_NAMESPACE` - Namespace onde o APIC está instalado
- `MGMT_INSTANCE_NAME` - Nome da instância do Management (padrão: management)
- `PORTAL_INSTANCE_NAME` - Nome da instância do Portal (padrão: wm-devportal)

### 2. Carregar Configuração

```bash
source config.env
```

O script irá:
- ✅ Descobrir automaticamente as URLs do OpenShift
- ✅ Buscar o Availability Zone ID do APIC
- ✅ Validar a configuração
- ✅ Exibir um resumo das configurações

### 3. Fazer Login no APIC

```bash
cd scripts
./00-login.sh
```

### 4. Executar Scripts na Ordem

```bash
# 1. Extrair certificados do Developer Portal
./01-extract-certificates.sh

# 2. Criar Keystore no Cloud Manager
./10-create-keystore.sh

# 3. Criar Truststore no Cloud Manager
./11-create-truststore.sh

# 4. Criar TLS Client Profile
./12-create-tls-client-profile.sh

# 5. Registrar Developer Portal
./20-register-devportal.sh
```

## 📁 Estrutura de Diretórios

```
apic-devportal-tls-setup/
├── config.env                      # Configuração (auto-discovery)
├── README.md                       # Esta documentação
├── scripts/
│   ├── 00-login.sh                # Login no APIC CLI
│   ├── 01-extract-certificates.sh # Extrai certs do K8s
│   ├── 10-create-keystore.sh      # Cria keystore
│   ├── 11-create-truststore.sh    # Cria truststore
│   ├── 12-create-tls-client-profile.sh # Cria TLS profile
│   ├── 20-register-devportal.sh   # Registra portal
│   └── wm-portal.yaml             # Referência de estrutura
└── temp-certificates/             # Certificados temporários
    ├── devportal-admin-cert.pem
    ├── devportal-admin-key.pem
    └── ingress-ca.pem
```

## 🔐 Processo de TLS

### 1. Extração de Certificados

O script `01-extract-certificates.sh` extrai do Kubernetes:

- **Client Certificate** (`devportal-admin-client`) - Para autenticação mTLS
- **Client Private Key** - Chave privada do certificado
- **CA Certificate** (`ingress-ca`) - Para validar o servidor

### 2. Criação de Recursos no Cloud Manager

#### Keystore
Contém o certificado e chave privada do cliente em um único campo (formato PEM combinado).

#### Truststore
Contém o certificado CA para validar o servidor do Developer Portal.

#### TLS Client Profile
Combina keystore e truststore, definindo:
- Ciphers suportados (34 ciphers configurados)
- Protocolos TLS (1.2 e 1.3)
- SNI habilitado

### 3. Registro do Portal

O script `20-register-devportal.sh`:

1. Valida que o TLS Client Profile existe
2. Busca a **integração** `devportal` (não `cms`)
3. Cria o payload com:
   - `endpoint` - URL da API admin do portal
   - `web_endpoint_base` - URL do site do portal
   - `endpoint_tls_client_profile_url` - Referência ao TLS profile
   - `integration_url` - **Campo obrigatório** para Developer Portal (wM)
4. Registra o portal no Cloud Manager

## 🔍 Troubleshooting

### Erro: "Invalid portal type"

**Causa**: Falta o campo `integration_url` no payload ou está usando a integração errada.

**Solução**: O script agora busca automaticamente a integração `devportal`. Verifique se ela existe:

```bash
apic integrations:list --subcollection portal-service \
  --server $APIC_SERVER --insecure-skip-tls-verify
```

### Erro: "AVAILABILITY_ZONE_ID não está definido"

**Causa**: Não fez login no APIC antes de carregar o config.env.

**Solução**:
```bash
cd scripts
./00-login.sh
cd ..
source config.env
```

### Erro: "Could not discover URLs from OpenShift"

**Causa**: Não está logado no OpenShift ou as rotas não existem.

**Solução**:
```bash
oc login <cluster-url>
oc get routes -n <namespace>
```

### Portal não aparece na UI

**Causa**: Pode estar registrado em uma availability zone diferente.

**Solução**: Verifique todas as zonas:
```bash
apic availability-zones:list --org admin \
  --server $APIC_SERVER --insecure-skip-tls-verify
```

## 📚 Diferenças entre Portais

### Portal Drupal (CMS)
- Integração: `cms`
- Registro mais simples
- Não requer `integration_url` obrigatoriamente

### Developer Portal (wM)
- Integração: `devportal`
- **Requer** campo `integration_url`
- Suporta recursos modernos (batch, feedback_2)

## 🔄 Recriar Registro

Para recriar o registro do portal:

```bash
cd scripts
./20-register-devportal.sh
# Responda 's' quando perguntado se deseja recriar
```

Ou delete manualmente:

```bash
apic portal-services:delete wm-devportal \
  --org admin \
  --server $APIC_SERVER \
  --insecure-skip-tls-verify
```

## 📝 Notas Importantes

1. **Certificados Temporários**: Os certificados em `temp-certificates/` são extraídos do Kubernetes e não devem ser commitados no Git.

2. **Auto-Discovery**: O `config.env` descobre automaticamente:
   - URLs do Management e Portal (via rotas do OpenShift)
   - Availability Zone ID (via APIC CLI)

3. **Validação**: Todos os scripts validam pré-requisitos antes de executar.

4. **Idempotência**: Os scripts verificam se os recursos já existem antes de criar.

5. **Debug**: Use `--debug` nos comandos APIC para ver requisições HTTP completas.

## 🆘 Suporte

Para mais informações, consulte:
- [IBM API Connect Documentation](https://www.ibm.com/docs/en/api-connect)
- [Developer Portal Configuration Guide](https://www.ibm.com/docs/en/api-connect/12.x)

## 📄 Licença

Este projeto segue as mesmas licenças do IBM API Connect.