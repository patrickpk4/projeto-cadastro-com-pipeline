# Terraform

Esta infraestrutura usa três states independentes no mesmo bucket S3:

| Stack | Diretório Terraform | Chave do state |
|---|---|---|
| Hub | `infra/hub` | `hub/terraform.tfstate` |
| Staging | `infra/spoke` | `spoke/staging/terraform.tfstate` |
| Production | `infra/spoke` | `spoke/production/terraform.tfstate` |

O root `infra/spoke/` contém o código compartilhado pelas duas spokes. Selecione staging ou production com `infra/envs/<ambiente>.tfvars`; cada uma lê os outputs do hub por `terraform_remote_state`. O hub não deve ler os states das spokes.

O módulo EKS em `spoke/main.tf` usa o commit upstream completo do release `v21.30.2`. Esse release declara internamente o módulo KMS `terraform-aws-modules/kms/aws` na versão exata `4.0.0` do Terraform Registry. O Checkov `CKV_TF_1` exige hash Git também para esse módulo transitivo; mantenha uma exceção controlada e restrita a `module.eks[0].kms` ao atualizar a pipeline, sem desabilitar o check globalmente.

Inicialize cada stack com o bucket e a região do laboratório:

```sh
terraform -chdir=infra/hub init \
  -backend-config="bucket=<bucket>" \
  -backend-config="key=hub/terraform.tfstate" \
  -backend-config="region=<região>"

terraform -chdir=infra/spoke init \
  -backend-config="bucket=<bucket>" \
  -backend-config="key=spoke/staging/terraform.tfstate" \
  -backend-config="region=<região>"
```

Para production, use o mesmo root `infra/spoke/`, a chave `spoke/production/terraform.tfstate` e `-var-file=../envs/production.tfvars`.

Exemplo de plano para staging depois do `init`:

```sh
TF_VAR_state_bucket=<bucket> terraform -chdir=infra/spoke plan \
  -var-file=../envs/staging.tfvars
```

Para production, troque o arquivo de variáveis por `../envs/production.tfvars`. Crie/aplique o hub antes das spokes. Os arquivos `terraform.tfvars` reais não devem ser versionados; use os exemplos em `infra/hub/` e `infra/envs/` como referência. Os backends usam lock nativo S3 (`use_lockfile`); o bucket deve ter versionamento e criptografia habilitados.

Como esta infraestrutura de laboratório foi destruída, a migração dos states antigos pode não ser necessária. Antes do primeiro apply, confira os states nas chaves antigas (`infra/hub/terraform.tfstate`, `infra/staging/terraform.tfstate` e `infra/production/terraform.tfstate`): se não existirem ou não listarem recursos, não os copie; mantenha os objetos antigos como backup e comece nas novas chaves. Se ainda listarem recursos, mesmo sem recursos na AWS, não copie nem aplique automaticamente: preserve o state e revise a situação antes de iniciar os novos states.

O workflow atual ainda aponta para `infra/`; sua atualização para os novos roots e arquivos de variáveis será feita separadamente, conforme planejado.
