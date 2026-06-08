# CI/CD - Aplicação .NET, Docker, Kubernetes e Terraform

## Visão Geral

Este repositório utiliza GitHub Actions para automatizar todo o ciclo de entrega da aplicação e da infraestrutura.

A estratégia é composta por dois pipelines independentes:

* Pipeline de Infraestrutura (Terraform)
* Pipeline de Aplicação (.NET + Docker + EKS)

Os pipelines seguem práticas de DevOps, GitOps e Infrastructure as Code, incluindo validações de qualidade, segurança, estimativa de custos, deploy automatizado e aprovação manual para produção.

---

# Fluxo de Branches

```text
Feature Branch
      │
      ▼
Pull Request
      │
      ▼
   staging
      │
      ▼
   main
      │
      ▼
 Production
```

---

# Pipeline de Infraestrutura (Terraform)

Arquivo principal:

```text
.github/workflows/terraform.yml
```

Objetivo:

* Validar código Terraform
* Executar verificações de segurança
* Estimar custos
* Gerar Terraform Plan
* Aplicar mudanças em Staging
* Aplicar mudanças em Production mediante aprovação

---

## Triggers

### Pull Request para Main

```text
pull_request -> main
```

Executa:

* Validate
* Security
* Infracost
* Plan Staging

Sem deploy.

---

### Push para Staging

```text
push -> staging
```

Executa:

* Validate
* Security
* Infracost
* Plan Staging

Sem Apply.

---

### Tag Semântica

```text
v1.0.0
v1.0.1
v2.0.0
```

Executa:

* Validate
* Security
* Infracost
* Plan Staging
* Apply Staging

Utilizado para homologação.

---

### Push para Main

```text
push -> main
```

Executa:

* Validate
* Security
* Infracost
* Plan Production
* Apply Production

O Apply Production exige aprovação manual.

---

# Resolução Automática de Ambiente

A pipeline determina automaticamente o ambiente de execução.

| Trigger      | Ambiente   | Deploy |
| ------------ | ---------- | ------ |
| Pull Request | Staging    | Não    |
| Push Staging | Staging    | Não    |
| Tag v*       | Staging    | Sim    |
| Push Main    | Production | Sim    |

---

# Etapas da Pipeline Terraform

## 1. Validate

Workflow:

```text
tf_validate.yaml
```

Executa:

### Terraform Format

```bash
terraform fmt -check -recursive
```

Valida padronização do código.

---

### Terraform Init

```bash
terraform init -backend=false
```

Inicializa providers sem utilizar backend remoto.

---

### Terraform Validate

```bash
terraform validate
```

Valida sintaxe e consistência da configuração.

---

### TFLint

```bash
tflint --recursive
```

Valida boas práticas e possíveis problemas de configuração.

---

## 2. Security

Executa ferramentas de análise estática de segurança.

### tfsec

Verifica:

* Recursos inseguros
* Configurações AWS inadequadas
* Exposição de dados

---

### Checkov

Verifica:

* Compliance
* Segurança
* Boas práticas

Resultados enviados para:

```text
GitHub Security Tab
```

através de arquivos SARIF.

---

## 3. Infracost

Calcula estimativa mensal de custos da infraestrutura.

Ferramenta:

```text
Infracost
```

Em Pull Requests publica comentários automáticos contendo:

* Recursos criados
* Recursos alterados
* Impacto financeiro estimado

---

## 4. Terraform Plan

### Staging

Workflow:

```text
tf_plan_stag.yaml
```

Executa:

```bash
terraform init
terraform plan
```

Gera:

```text
tfplan-staging
```

Armazenado como Artifact.

---

### Production

Workflow:

```text
tf_plan_prod.yaml
```

Executa:

```bash
terraform init
terraform plan
```

Gera:

```text
tfplan-production
```

Armazenado como Artifact.

---

## 5. Terraform Apply

### Apply Staging

Workflow:

```text
tf_apply_stag.yaml
```

Executado apenas quando uma tag semântica é criada.

Utiliza o artefato:

```text
tfplan-staging
```

---

### Apply Production

Workflow:

```text
tf_apply_prod.yaml
```

Executado apenas após merge na branch main.

Proteções:

* GitHub Environment
* Required Reviewers
* Aprovação Manual

Fluxo:

```text
Plan Production
        │
        ▼
Aprovação Manual
        │
        ▼
Apply Production
```

---

# Pipeline da Aplicação

Arquivo:

```text
.github/workflows/dotnet-build.yml
```

Objetivo:

* Build
* Testes
* Qualidade de código
* Build Docker
* Publicação Docker Hub
* Deploy Kubernetes

---

# Triggers

### Pull Request para Main

Executa:

* Build
* Testes
* SonarCloud

Sem deploy.

---

### Push para Staging

Executa:

* Build
* Testes
* Docker Build
* Docker Push
* Deploy EKS Staging

---

### Push para Main

Executa:

* Build
* Testes
* Docker Build
* Docker Push
* Deploy EKS Production

---

# Etapas da Pipeline da Aplicação

## 1. Build

### Restore

```bash
dotnet restore
```

Restaura dependências.

---

### Build

```bash
dotnet build
```

Compila a solução.

---

### Testes Unitários

```bash
dotnet test
```

Executa testes unitários.

Também gera:

* Cobertura de código
* Arquivos TRX

---

## 2. SonarCloud

Executa análise estática.

Valida:

* Bugs
* Vulnerabilidades
* Code Smells
* Cobertura

Ferramenta:

```text
SonarCloud
```

---

## 3. Testes de Integração

Executados utilizando MongoDB temporário.

Container utilizado:

```text
mongo:4.4
```

Valida integração da aplicação com banco de dados.

---

## 4. Build e Push Docker

Login:

```text
Docker Hub
```

Build da imagem:

```bash
docker build
```

Publicação:

```text
usuario/catalogo:latest
usuario/catalogo:<commit_sha>
```

---

## 5. Deploy Kubernetes

Após publicação da imagem.

Etapas:

### Configuração AWS

Assume Role utilizando OIDC.

---

### Atualização do kubeconfig

```bash
aws eks update-kubeconfig
```

---

### Atualização da imagem

Substitui:

```yaml
image: usuario/catalogo:latest
```

por:

```yaml
image: usuario/catalogo:<commit_sha>
```

Garantindo rastreabilidade completa.

---

### Aplicação dos manifests

```bash
kubectl apply -f k8s/ -R
```

---

### Verificação de rollout

```bash
kubectl rollout status
```

---

### Rollback Automático

Em caso de falha:

```bash
kubectl rollout undo
```

---

# Segurança

A autenticação AWS é realizada utilizando:

```text
GitHub OIDC
```

Não são utilizadas Access Keys permanentes.

Benefícios:

* Credenciais temporárias
* Menor superfície de ataque
* Rotação automática
* Melhor auditoria

---

# Secrets Utilizados

## Terraform

```text
AWS_ROLE
TFVARS
TFVARS_PROD
BUCKET
BUCKET_PROD
KEY
KEY_PROD
INFRACOST_API_KEY
```

---

## Aplicação

```text
SONAR_TOKEN
SONAR_PROJECT_KEY
SONAR_ORGANIZATION
docker_user
DOCKER_TOKEN
MONGO_CONNECTION_STRING
AWS_ROLE
```

---

# Ferramentas Utilizadas

## Infraestrutura

* Terraform
* TFLint
* tfsec
* Checkov
* Infracost

## Aplicação

* .NET 8
* xUnit
* SonarCloud
* Docker
* Docker Hub

## Plataforma

* GitHub Actions
* Amazon EKS
* AWS IAM OIDC
* Kubernetes

---

# Fluxo Completo

```text
Pull Request
     │
     ▼
Terraform Validate
     │
     ▼
Security Scan
     │
     ▼
Infracost
     │
     ▼
Terraform Plan
     │
     ▼
Merge

─────────────────────────────────

Push Staging
     │
     ▼
Build
     │
     ▼
Testes
     │
     ▼
Docker Build
     │
     ▼
Docker Push
     │
     ▼
Deploy EKS Staging

─────────────────────────────────

Push Main
     │
     ▼
Terraform Plan Production
     │
     ▼
Aprovação Manual
     │
     ▼
Terraform Apply Production
     │
     ▼
Build
     │
     ▼
Testes
     │
     ▼
Docker Push
     │
     ▼
Deploy EKS Production
```
