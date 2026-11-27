# Terraform

Esta infraestrutura usa três states independentes no mesmo bucket S3:

| Stack | Diretório Terraform | Chave do state |
|---|---|---|
| Hub | `infra/hub` | `hub/terraform.tfstate` |
| Staging | `infra/spoke` | `spoke/staging/terraform.tfstate` |
| Production | `infra/spoke` | `spoke/production/terraform.tfstate` |

O root `infra/spoke/` contém o código compartilhado pelas duas spokes. Selecione staging ou production com `infra/envs/<ambiente>.tfvars`; cada uma lê os outputs do hub por `terraform_remote_state`. O hub não deve ler os states das spokes.

O módulo EKS em `spoke/main.tf` usa o commit upstream completo do release `v21.30.2`. Esse release declara internamente o módulo KMS `terraform-aws-modules/kms/aws` na versão exata `4.0.0` do Terraform Registry. O baseline `.github/checkov/infra-baseline.json` contém exceções restritas aos findings aceitos para o laboratório: endpoint EKS público para os runners hospedados do GitHub; logging EKS nos tipos/retention padrão do módulo para limitar custos; HTTP do ALB e entre o ALB e os targets sem domínio/certificado; ausência de WAF/ALB access logs/VPC Flow Logs para evitar custos adicionais; proteção contra exclusão desabilitada para permitir destroy; e findings de relacionamento de security groups internos ao módulo EKS upstream. O EKS está configurado com criptografia de Secrets, mas o Checkov não consegue avaliar o bloco dinâmico do módulo e reporta `CKV_AWS_58`; essa exceção também é específica ao recurso. O restante dos checks continua bloqueando o workflow.

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

## GitHub Actions

- `infra_static_checks.yaml` valida os roots `hub` e `spoke`, confere formatação e executa Checkov.
- O mesmo workflow executa TFLint nos roots e módulos Terraform; roda em pushes para `feature/**` e `hotfix/**` quando arquivos de infraestrutura/workflows mudam, e em todos os pull requests para `main`. Roda em todos os PRs para que seus checks possam ser exigidos nas regras da branch sem ficarem pendentes quando o PR não altera infraestrutura. Não roda novamente no push de merge em `main`.
- `security_gitleaks.yaml` verifica o histórico completo do repositório em pushes para `feature/**`, `hotfix/**` e `main`, além de pull requests para `main`. O push para `main` é uma verificação extra pós-merge, não um bloqueio do deploy. Se o repositório pertencer a uma organização GitHub, configure o secret `GITLEAKS_LICENSE`.
- Os workflows de checagem cancelam uma execução anterior da mesma branch quando chega uma nova alteração. Isso economiza runners; não ordena os checks em relação ao CD.
- `infra_ci_plan_hub.yaml`, `infra_ci_plan_staging.yaml` e `infra_ci_plan_production.yaml` geram e publicam o plan correspondente em pull requests.
- `infra_cd_deploy_all_states.yaml` aplica, em sequência, hub → staging → production em pushes para `main`, somente quando o plan de cada state contém mudanças.
- `infra_reusable_terraform_plan.yaml` e `infra_reusable_terraform_apply.yaml` são os workflows reutilizáveis chamados pelos anteriores.

Os plans de PR são workflows independentes, sem apply; rodam em paralelo conforme os arquivos alterados. Alterações no hub também acionam os plans das spokes. Esses plans leem os outputs atualmente aplicados no state do hub, não os outputs ainda não aplicados do plan do PR. Após merge em `main`, o CD é sequencial: planeja e aplica hub e staging; após um apply bem-sucedido de staging, executa o smoke test e só então permite planejar/aplicar production. Se staging não tiver mudanças, o apply e o smoke test são pulados, e o CD segue para production. Se o smoke test de staging falhar, production não é planejado nem aplicado. Após um apply bem-sucedido de production, também executa o smoke test de production. Cada apply só roda se houver mudanças; os smoke tests só rodam após um apply real. Production pode aguardar aprovação do GitHub Environment. O CD é serializado para evitar execuções de deploy sobrepostas. As validações e plans de PR são somente leitura e não cancelam outras execuções.

Para impedir merge com falhas de segurança ou validação, configure nas regras da branch `main` os checks dos workflows de validação Terraform e Gitleaks como obrigatórios. Isso é uma configuração do GitHub (Rulesets/Branch protection), não controlada por estes arquivos YAML. A execução adicional do Gitleaks no push de `main` é pós-merge e não bloqueia o CD.

Cada artefato é nomeado `tfplan-<state>-<github.sha>` (por exemplo, `tfplan-hub-<SHA>`), é enviado somente se houver mudanças e expira após sete dias. O apply do mesmo run baixa o plan daquele commit; o CI de pull request não é reaproveitado depois do merge, pois o CD gera um plan novo para o commit de `main`. Isso versiona os plans por commit, não por número de release.

Os plans e applies usam os arquivos versionados `terraform.tfvars.example` e `envs/*.tfvars.example`; esses valores são configuração de rede/cluster, não credenciais. Configure os secrets de repositório `AWS_ROLE`, `BUCKET`, `TF_VERSION` e `TF_VARS`, além da variável `REGION`. O secret de repositório `TF_VARS` deve conter atribuições HCL válidas de um arquivo `.tfvars`, incluindo `kubernetes_version = "1.35"`; o Checkov o grava temporariamente e o usa nos pushes de `feature/**` e `hotfix/**`. Em pull requests, o Checkov usa `envs/production.tfvars.example` para não disponibilizar secrets ao código do PR. O arquivo temporário é removido após o scan. Os smoke tests também usam as variáveis `eks_stg` e `eks_prod` com os nomes dos clusters. As chaves de state são fixas; o secret `KEY` não é consumido por estes workflows.

Os jobs de apply selecionam os GitHub Environments `hub`, `staging` e `production`. Configure reviewers no Environment `hub` e, principalmente, em `production`. Como os jobs usam esses Environments, confirme também que a trust policy OIDC da role permite os subjects `repo:patrickpk4/projeto-cadastro-com-pipeline:environment:hub`, `...:environment:staging` e `...:environment:production`, além do subject necessário para os plans em pull requests/`main`.

Os plans de staging/production em pull requests são pulados com uma mensagem clara se o state do hub ainda não tiver os outputs necessários; aplique o hub primeiro. A versão do Terraform vem do secret `TF_VERSION`, os providers estão travados nos lockfiles e o módulo EKS está fixado por commit SHA. O versionamento histórico dos states depende do versionamento habilitado no bucket S3.
