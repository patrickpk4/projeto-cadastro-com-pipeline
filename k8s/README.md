# Kubernetes

[![Kubernetes](https://img.shields.io/badge/Kubernetes-EKS-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![API](https://img.shields.io/badge/API-.NET%208-512BD4?logo=dotnet&logoColor=white)](https://dotnet.microsoft.com/)
[![MongoDB](https://img.shields.io/badge/MongoDB-4.4.0-47A248?logo=mongodb&logoColor=white)](https://www.mongodb.com/)
[![Deployment](https://img.shields.io/badge/Deployment-Kubernetes%20manifests-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/docs/concepts/workloads/)

Este diretório contém os manifests Kubernetes da API PedeLogo Catálogo e do MongoDB. As configurações de OpenTelemetry, Prometheus e Grafana estão separadas em [`../observability/`](../observability/README.md); os manifests auxiliares do teste do cluster estão em [`../testeEks/`](../testeEks/).

## Componentes e arquitetura

```text
Cliente
  -> ALB do hub (staging :80 ou production :8080)
  -> Transit Gateway
  -> TargetGroupBinding -> Service api-service (ClusterIP :80)
  -> Deployment api-deployment (.NET 8, container :8080)
  -> Service mongo-service (headless :27017)
  -> StatefulSet mongodb-statefulset (MongoDB 4.4.0)
```

| Componente | Recurso | Configuração |
|---|---|---|
| API de catálogo | Deployment `api-deployment` | 1 réplica inicial; imagem publicada no Amazon ECR; probes `/read` e `/health`; recursos requests 200m CPU/256Mi e limits 500m CPU/384Mi |
| Acesso à API | Service `api-service` | Tipo `ClusterIP`; TargetGroupBinding registra os IPs dos pods no target group do ALB central |
| Banco | StatefulSet `mongodb-statefulset` | MongoDB 4.4.0, 1 réplica, porta 27017, startup/readiness/liveness probes e recursos definidos |
| Acesso ao banco | Service `mongo-service` | Headless Service, porta 27017, descoberta interna no namespace `default` |
| Configuração da API | ConfigMap `catalogo-config` | Host, porta e nome do banco MongoDB |
| Escala | HPAs `api-autoscaling` e `mongodb-hpa` | Autoscaling por CPU/memória; API de 1 a 10 réplicas |
| Segurança de rede | NetworkPolicies para API e MongoDB | Regras de tráfego entre API, banco e DNS |
| Acesso a recursos | ServiceAccounts, Roles e RoleBindings | Controles RBAC separados para API e banco |

Os manifests usam o namespace `default` quando não especificam um namespace.

## Estrutura

```text
k8s/
├── cadastro-k8s/   # Deployment, Service, ConfigMap, HPA, RBAC e NetworkPolicy da API
├── environments/   # TargetGroupBinding específico de staging e production
├── mongodb-k8s/    # StatefulSet, Service, HPA, RBAC e NetworkPolicy do MongoDB
└── README.md
```

## Pré-requisitos

- `kubectl` configurado para o cluster EKS correto.
- Permissão para criar/atualizar workloads, Services, Secrets, RBAC, NetworkPolicies e HPAs.
- EKS Auto Mode habilitado; ele mantém os TargetGroupBindings declarados em `environments/`.
- Metrics Server para que os HPAs obtenham métricas de CPU e memória.
- Suporte a NetworkPolicy no plugin de rede do cluster para que as políticas tenham efeito.
- Uma imagem da API publicada no Amazon ECR; os nós EKS precisam de permissão para baixá-la.
- O Secret `mongodb-secret` no namespace `default`, criado a partir das credenciais correspondentes no AWS Secrets Manager.

## Implantação

Execute os comandos a partir da raiz do repositório e confira primeiro se o contexto do `kubectl` aponta para o cluster desejado:

```bash
kubectl config current-context
kubectl get nodes
```

### 1. MongoDB

```bash
kubectl apply -f k8s/mongodb-k8s/
kubectl rollout status statefulset/mongodb-statefulset \
  -n default --timeout=180s
kubectl get service mongo-service -n default
```

### 2. API

O manifesto `cadastro.yaml` contém `__ECR_REGISTRY__` e `IMAGE_TAG` como placeholders. O workflow de CD substitui ambos e publica a imagem do ECR. Em uma implantação manual, substitua-os por um registry e uma tag existentes no ECR e confirme que o `mongodb-secret` já foi criado no namespace `default` a partir do Secrets Manager. Não é necessário `imagePullSecret` quando os nós EKS têm a permissão de pull apropriada.

```bash
kubectl apply -f k8s/cadastro-k8s/
kubectl rollout status deployment/api-deployment \
  -n default --timeout=180s
kubectl get service api-service -n default
```

No cluster de staging, aplique apenas o binding de staging; no cluster production, aplique apenas o de production:

```bash
kubectl apply -f k8s/environments/staging/targetgroupbinding.yaml
# Ou, no cluster production:
kubectl apply -f k8s/environments/production/targetgroupbinding.yaml
```

O DNS é o mesmo para os dois ambientes: staging usa a porta 80 e production a porta 8080. Consulte `terraform output -raw staging_url` e `terraform output -raw production_url` no diretório `infra/`. Não remova um TargetGroupBinding isoladamente: o EKS Auto Mode pode excluir o target group associado.

O Deployment aguarda o MongoDB na inicialização. Se ele não ficar pronto, verifique os pods, eventos e logs antes de reiniciar os workloads:

```bash
kubectl get pods -n default -o wide
kubectl get events -n default --sort-by=.lastTimestamp
kubectl logs -n default deployment/api-deployment --all-containers=true
```

## Autoscaling

Os manifests declaram HPA da API (mínimo 1, máximo 10 réplicas, alvos de CPU e memória em 50%) e HPA do MongoDB StatefulSet (mínimo 1, máximo 10, alvos próprios definidos no manifest). Confira a configuração e a disponibilidade das métricas:

```bash
kubectl get hpa -n default
kubectl describe hpa api-autoscaling -n default
kubectl top pods -n default
```

Se os valores de uso aparecerem como `<unknown>`, confira se o Metrics Server está instalado e saudável.

## Health checks e rede

- API: readiness em `/read`; liveness em `/health`.
- ALB: health check em `/health`, porta 8080 nos pods.
- MongoDB: startup e liveness executam `db.adminCommand('ping')`; readiness testa a porta TCP 27017.
- NetworkPolicies limitam a entrada da API aos CIDRs das subnets públicas do hub e o acesso ao MongoDB aos pods da API; atualize os CIDRs da política da API se alterar as subnets do hub.

Consulte políticas e endpoints para diagnosticar conectividade:

```bash
kubectl get networkpolicy -n default
kubectl get endpoints api-service mongo-service -n default
kubectl describe networkpolicy allow-ctalogo-mongodb -n default
kubectl describe networkpolicy allow-mongodb-catalogo -n default
```

NetworkPolicies só são aplicadas se o plugin de rede do cluster suportar essa funcionalidade.

## Verificação rápida

```bash
kubectl get deployments,statefulsets,services,hpa,networkpolicies -n default
kubectl get pods -n default
kubectl get service api-service -n default
```

Para chamar a API com requisições GET e gerar tráfego de teste sem gravar produtos, use o script documentado em [`../observability/README.md`](../observability/README.md#gerar-tráfego-de-teste).

## Arquivos

### `cadastro-k8s/`

| Arquivo | Recurso |
|---|---|
| `cadastro.yaml` | Deployment da API |
| `service-cadastro.yaml` | Service `ClusterIP` da API |
| `configmap.yaml` | Configuração da aplicação; credenciais vêm do Secret `mongodb-secret` |
| `hpa-cadastro.yaml` | Autoscaling da API |
| `networkpolicy-cadastro.yaml` | Políticas de tráfego da API |
| `serviceaccount-cadastro.yaml`, `role-cadastro.yaml`, `rolebinding-cadastro.yaml` | RBAC da API |

### `mongodb-k8s/`

| Arquivo | Recurso |
|---|---|
| `mongodb.yaml` | StatefulSet do MongoDB |
| `service-mongodb.yaml` | Service headless do MongoDB |
| `hpa-mongodb.yaml` | Autoscaling do StatefulSet |
| `networkpolicy-mongodb.yaml` | Políticas de tráfego do MongoDB |
| `serviceaccount-mongodb.yaml`, `role-mongodb.yaml`, `rolebinding-mongodb.yaml` | RBAC do MongoDB |

Para a instrumentação e o monitoramento da API, consulte [`../observability/README.md`](../observability/README.md).
