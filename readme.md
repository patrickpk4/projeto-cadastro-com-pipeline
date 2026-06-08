# PedeLogo Catálogo

## Visão Geral

O PedeLogo Catálogo é uma aplicação desenvolvida em .NET 8 executada em Kubernetes na AWS utilizando Amazon EKS.

Toda a infraestrutura é provisionada com Terraform e o ciclo completo de entrega é automatizado através de GitHub Actions.

O projeto segue práticas modernas de:

* DevOps
* GitOps
* Infrastructure as Code (IaC)
* Continuous Integration (CI)
* Continuous Delivery (CD)
* Cloud Native Architecture

---

# Arquitetura da Solução

A solução é composta por quatro camadas principais:

```text
Aplicação .NET 8
        │
        ▼
Docker
        │
        ▼
Amazon EKS
        │
        ▼
Infraestrutura AWS Provisionada por Terraform
```

---

# Tecnologias Utilizadas

## Aplicação

* .NET 8
* ASP.NET Core
* MongoDB
* xUnit

## Containers

* Docker
* Docker Hub

## Kubernetes

* Amazon EKS
* kubectl

## Infraestrutura

* Terraform
* AWS

## Qualidade e Segurança

* SonarCloud
* TFLint
* tfsec
* Checkov
* Infracost

## CI/CD

* GitHub Actions

---

# Estrutura do Projeto

```text
.
├── .github
│   └── workflows
│       ├── terraform.yml
│       ├── tf_validate.yaml
│       ├── tf_plan_stag.yaml
│       ├── tf_plan_prod.yaml
│       ├── tf_apply_stag.yaml
│       ├── tf_apply_prod.yaml
│       └── dotnet-build.yml
│
├── infra
│   └── env
│       ├── staging
│       └── production
│
├── src
│   └── PedeLogo.Catalogo.Api
│
├── tests
│   ├── PedeLogo.Catalogo.UnitTests
│   └── PedeLogo.Catalogo.IntegrationTests
│
└── k8s
    └── cadastro-k8s
```

---

# Infraestrutura AWS

A infraestrutura é provisionada através do Terraform utilizando módulos oficiais da AWS.

## Recursos Provisionados

### VPC

A VPC é criada utilizando o módulo oficial:

```text
terraform-aws-modules/vpc/aws
```

Recursos:

* VPC
* Internet Gateway
* NAT Gateway
* VPN Gateway
* Route Tables
* Subnets Públicas
* Subnets Privadas

---

### Amazon EKS

O cluster Kubernetes é criado utilizando:

```text
terraform-aws-modules/eks/aws
```

Recursos:

* Cluster Kubernetes
* Managed Node Groups
* IAM Roles
* Security Groups
* Endpoint Público
* Endpoint Privado

---

### Add-ons Instalados

* CoreDNS
* kube-proxy
* VPC CNI
* EKS Pod Identity Agent

---

### Ambientes

A infraestrutura é separada em:

```text
staging
production
```

Cada ambiente possui:

* Terraform State independente
* Variáveis independentes
* Backend remoto independente
* Cluster Kubernetes independente

---

# Fluxo de Desenvolvimento

O fluxo adotado utiliza três tipos principais de branches.

```text
feature/*
     │
     ▼
 staging
     │
     ▼
  main
```

---

## Feature Branch

Desenvolvimento de novas funcionalidades.

Exemplo:

```text
feature/criar-endpoint-produtos
```

---

## Staging

Ambiente de homologação.

Utilizado para:

* Testes integrados
* Validação funcional
* Homologação

---

## Main

Ambiente produtivo.

Toda alteração na main é considerada pronta para produção.

---

# Pipeline de Infraestrutura

Arquivo principal:

```text
.github/workflows/terraform.yml
```

Responsável por:

* Validação
* Segurança
* Estimativa de custos
* Terraform Plan
* Terraform Apply

---

## Pull Request

Quando um Pull Request é aberto para a branch main:

```text
feature/*
       │
       ▼
Pull Request
       │
       ▼
main
```

Executa:

* Terraform Format
* Terraform Validate
* TFLint
* tfsec
* Checkov
* Infracost
* Terraform Plan

Nenhuma alteração é aplicada.

---

## Push para Staging

Executa:

* Validate
* Security Scan
* Infracost
* Terraform Plan

Sem deploy.

---

## Criação de Tag

Exemplo:

```text
v1.0.0
```

Executa:

* Validate
* Security
* Infracost
* Plan Staging
* Apply Staging

Permite homologação da infraestrutura.

---

## Push para Main

Executa:

* Validate
* Security
* Infracost
* Plan Production
* Apply Production

---

# Validações Terraform

## Terraform Format

```bash
terraform fmt -check -recursive
```

Valida padronização do código.

---

## Terraform Validate

```bash
terraform validate
```

Valida sintaxe e consistência.

---

## TFLint

Executa verificações de boas práticas.

Exemplos:

* Recursos mal configurados
* Variáveis não utilizadas
* Configurações inválidas

---

## tfsec

Executa análise de segurança.

Verifica:

* Recursos inseguros
* Configurações públicas indevidas
* Falhas conhecidas

---

## Checkov

Executa análise de compliance.

Resultados enviados para:

```text
GitHub Security
```

---

## Infracost

Calcula o impacto financeiro das alterações.

Exibe:

* Recursos criados
* Recursos alterados
* Custo estimado mensal

---

# Deploy da Infraestrutura

## Staging

Executado automaticamente após criação de tag.

Fluxo:

```text
Plan
   │
   ▼
Apply Staging
```

---

## Production

Executado após merge para main.

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

A aprovação é controlada através de GitHub Environments.

---

# Pipeline da Aplicação

Arquivo:

```text
.github/workflows/dotnet-build.yml
```

Responsável por:

* Build
* Testes
* SonarCloud
* Docker Build
* Docker Push
* Deploy Kubernetes

---

# Etapa 1 - Build

Executa:

```bash
dotnet restore
dotnet build
```

Objetivo:

* Restaurar dependências
* Compilar a aplicação

---

# Etapa 2 - Testes Unitários

Executa:

```bash
dotnet test
```

Valida:

* Regras de negócio
* Métodos isolados
* Cobertura de código

---

# Etapa 3 - SonarCloud

Executa análise estática.

Valida:

* Bugs
* Vulnerabilidades
* Code Smells
* Cobertura

---

# Etapa 4 - Testes de Integração

Executados utilizando MongoDB temporário.

Container utilizado:

```text
mongo:4.4
```

Valida:

* Integração com banco de dados
* Fluxos completos da aplicação

---

# Etapa 5 - Build da Imagem Docker

Após aprovação dos testes.

Executa:

```bash
docker build
```

Utilizando o Dockerfile da API.

---

# Etapa 6 - Publicação Docker Hub

Publica duas versões:

```text
catalogo:latest
catalogo:<commit_sha>
```

Exemplo:

```text
catalogo:4d9f3f9
```

Permite rastreabilidade completa entre código e imagem.

---

# Deploy Kubernetes

Após publicação da imagem.

---

## Identificação do Ambiente

A pipeline identifica automaticamente:

```text
staging
production
```

de acordo com a branch.

---

## Atualização do kubeconfig

Executa:

```bash
aws eks update-kubeconfig
```

Conectando ao cluster correto.

---

## Atualização da Imagem

A imagem utilizada pelo Deployment é substituída pela versão do commit.

Exemplo:

```text
catalogo:4d9f3f9
```

---

## Aplicação dos Manifestos

Executa:

```bash
kubectl apply -f k8s/ -R
```

---

## Verificação do Rollout

Executa:

```bash
kubectl rollout status
```

Garantindo que a nova versão esteja saudável.

---

## Rollback Automático

Em caso de falha:

```bash
kubectl rollout undo
```

A aplicação retorna para a versão anterior.

---

# Segurança

A autenticação AWS utiliza OIDC.

Fluxo:

```text
GitHub Actions
       │
       ▼
OIDC
       │
       ▼
AWS IAM Role
       │
       ▼
AWS Resources
```

Não são utilizadas Access Keys permanentes.

Benefícios:

* Credenciais temporárias
* Menor risco de vazamento
* Rotação automática
* Melhor auditoria

---

# Secrets Utilizados

## Infraestrutura

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

## Aplicação

```text
SONAR_TOKEN
SONAR_PROJECT_KEY
SONAR_ORGANIZATION
DOCKER_USER
DOCKER_TOKEN
MONGO_CONNECTION_STRING
AWS_ROLE
```

---

# Fluxo Completo da Entrega

```text
Desenvolvedor
      │
      ▼
Feature Branch
      │
      ▼
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

──────────────────────────────────

Push Staging
      │
      ▼
Build
      │
      ▼
Testes
      │
      ▼
SonarCloud
      │
      ▼
Docker Build
      │
      ▼
Docker Push
      │
      ▼
Deploy EKS Staging

──────────────────────────────────

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
Docker Build
      │
      ▼
Docker Push
      │
      ▼
Deploy EKS Production
```

---

# Objetivos do Projeto

* Automatizar o provisionamento da infraestrutura
* Garantir qualidade de código através de testes automatizados
* Aplicar validações de segurança em todas as mudanças
* Controlar custos de infraestrutura antes do deploy
* Automatizar publicação de imagens Docker
* Automatizar deploy em Kubernetes
* Garantir rastreabilidade entre código, imagem e ambiente
* Implementar um fluxo seguro para promoção entre Staging e Production
* Reduzir riscos operacionais através de validações e aprovações automatizadas
