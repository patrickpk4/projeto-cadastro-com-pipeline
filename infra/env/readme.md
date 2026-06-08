# Infraestrutura AWS - EKS e VPC com Terraform

## Visão Geral

Este projeto provisiona uma infraestrutura Kubernetes na AWS utilizando Terraform.

A arquitetura é composta por:

- VPC dedicada
- Sub-redes públicas e privadas distribuídas em múltiplas Availability Zones
- NAT Gateway
- VPN Gateway
- Cluster Amazon EKS
- Node Group Gerenciado
- Add-ons oficiais da AWS
- Backend remoto em S3 para armazenamento do Terraform State

A infraestrutura possui dois ambientes independentes:

- Staging
- Production

---

## Estrutura do Projeto

```text
infra/
├── env/
│   ├── production/
│   │   ├── main.tf
│   │   ├── provider.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   └── .terraform.lock.hcl
│   │
│   └── staging/
│       ├── main.tf
│       ├── provider.tf
│       ├── variables.tf
│       ├── terraform.tfvars
│       └── .terraform.lock.hcl
│
└── .terraform/
```

---

## Arquitetura

```text
                           Internet
                               │
                               ▼
                    +------------------+
                    |     AWS VPC      |
                    +------------------+
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
        ▼                      ▼                      ▼

  Public Subnet A      Public Subnet B       Public Subnet C
        │                      │                      │
        └────────── NAT Gateway ──────────────────────┘
                               │
                               ▼

  Private Subnet A     Private Subnet B      Private Subnet C
        │                      │                      │
        └────────────── Amazon EKS ───────────────────┘
                               │
                               ▼
                     Managed Node Group
```

---

## Recursos Provisionados

### VPC

Módulo utilizado:

```hcl
terraform-aws-modules/vpc/aws
```

Recursos provisionados:

- VPC
- Internet Gateway
- NAT Gateway
- VPN Gateway
- Route Tables
- Public Subnets
- Private Subnets

Configuração principal:

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.1"

  name = var.vpc_name
  cidr = var.cidr_vpc

  azs             = var.azs_subnets
  private_subnets = var.cidr_private_sub
  public_subnets  = var.cidr_public_sub

  enable_nat_gateway = true
  enable_vpn_gateway = true

  tags = var.project_tags
}
```

---

### EKS

Módulo utilizado:

```hcl
terraform-aws-modules/eks/aws
```

Recursos provisionados:

- Cluster Kubernetes
- Managed Node Group
- IAM Roles
- Security Groups
- Endpoint Público
- Endpoint Privado

Configuração principal:

```hcl
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.kube_name
  kubernetes_version = var.kube_version

  endpoint_public_access  = true
  endpoint_private_access = true

  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    default = {
      instance_types = var.instance_types

      min_size     = 2
      max_size     = 4
      desired_size = 2
    }
  }

  tags = var.project_tags
}
```

---

## Add-ons Instalados

### CoreDNS

Responsável pela resolução DNS dentro do cluster Kubernetes.

### kube-proxy

Gerencia regras de rede e comunicação dos serviços Kubernetes.

### VPC CNI

Configuração aplicada:

```hcl
vpc-cni = {
  before_compute = true
  configuration_values = jsonencode({
    env = {
      ENABLE_PREFIX_DELEGATION = "true"
      WARM_PREFIX_TARGET       = "1"
    }
  })
}
```

Benefícios:

- Melhor aproveitamento de endereços IP
- Maior escalabilidade dos Pods
- Redução de problemas relacionados à falta de IPs

### EKS Pod Identity Agent

Permite que Pods assumam permissões IAM sem necessidade de utilizar IRSA.

---

## Requisitos

### Terraform

```text
>= 1.7.0
```

### AWS Provider

```text
~> 6.42.0
```

### AWS CLI

```bash
aws --version
```

### kubectl

```bash
kubectl version --client
```

---

## Variáveis

| Variável | Descrição |
|-----------|------------|
| vpc_name | Nome da VPC |
| cidr_vpc | Range CIDR da VPC |
| regiao | Região AWS |
| cidr_private_sub | CIDRs das subnets privadas |
| cidr_public_sub | CIDRs das subnets públicas |
| azs_subnets | Availability Zones |
| project_tags | Tags aplicadas aos recursos |
| kube_name | Nome do cluster Kubernetes |
| kube_version | Versão do Kubernetes |
| instance_types | Tipo das instâncias dos Nodes |

---

## Exemplo terraform.tfvars - Staging

```hcl
vpc_name = "staging-vpc"

cidr_vpc = "10.10.0.0/16"

cidr_private_sub = [
  "10.10.1.0/24",
  "10.10.2.0/24"
]

cidr_public_sub = [
  "10.10.101.0/24",
  "10.10.102.0/24"
]

azs_subnets = [
  "us-east-1a",
  "us-east-1b"
]

regiao = "us-east-1"

kube_name    = "staging-eks"
kube_version = "1.33"

instance_types = [
  "t3.medium"
]

project_tags = {
  Environment = "staging"
  Project     = "cadastro-com-pipeline"
  ManagedBy   = "Terraform"
}
```

---

## Exemplo terraform.tfvars - Production

```hcl
vpc_name = "production-vpc"

cidr_vpc = "10.20.0.0/16"

cidr_private_sub = [
  "10.20.1.0/24",
  "10.20.2.0/24"
]

cidr_public_sub = [
  "10.20.101.0/24",
  "10.20.102.0/24"
]

azs_subnets = [
  "us-east-1a",
  "us-east-1b"
]

regiao = "us-east-1"

kube_name    = "production-eks"
kube_version = "1.33"

instance_types = [
  "m5.large"
]

project_tags = {
  Environment = "production"
  Project     = "cadastro-com-pipeline"
  ManagedBy   = "Terraform"
}
```

---

## Backend Remoto

O Terraform State é armazenado em um bucket S3.

Exemplo recomendado:

```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state-company"
    key            = "eks/staging/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

Boas práticas:

- Versionamento habilitado no bucket
- Criptografia SSE-KMS
- Lock via DynamoDB
- Bucket privado
- Controle de acesso por IAM

---

## Inicialização

### Ambiente Staging

```bash
cd infra/env/staging

terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

### Ambiente Production

```bash
cd infra/env/production

terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

---

## Acesso ao Cluster

Atualizar kubeconfig:

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name staging-eks
```

Validar Nodes:

```bash
kubectl get nodes
```

Validar Pods:

```bash
kubectl get pods -A
```

Validar informações do cluster:

```bash
kubectl cluster-info
```

---

## Destruição da Infraestrutura

### Staging

```bash
cd infra/env/staging

terraform destroy
```

### Production

```bash
cd infra/env/production

terraform destroy
```

---

## Boas Práticas Implementadas

- Separação entre ambientes Staging e Production
- Utilização de módulos oficiais da AWS
- Uso de Terraform State remoto
- Lock de State recomendado via DynamoDB
- Tags padronizadas
- Subnets privadas para workloads Kubernetes
- Endpoint público e privado habilitados
- EKS Managed Node Groups
- Prefix Delegation habilitado para otimização de IPs
- Infraestrutura reproduzível através de Infrastructure as Code

---

## Versões Utilizadas

### Terraform

```text
>= 1.7.0
```

### AWS Provider

```text
~> 6.42.0
```

### VPC Module

```text
terraform-aws-modules/vpc/aws
6.6.1
```

### EKS Module

```text
terraform-aws-modules/eks/aws
~> 21.0
```

---

## Observações

Atualmente cada ambiente possui sua própria configuração dentro do diretório `env/`.

Para evolução futura recomenda-se:

- Criar uma pasta `modules/eks`
- Criar uma pasta `modules/vpc`
- Manter apenas os arquivos de ambiente em `env/staging` e `env/production`
- Utilizar backends independentes para cada ambiente
- Implementar CI/CD para execução automatizada dos comandos Terraform
- Implementar validações com `terraform fmt`, `terraform validate`, `tflint`, `checkov` e `tfsec`