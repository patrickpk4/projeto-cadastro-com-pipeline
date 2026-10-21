# Observabilidade

[![.NET 8](https://img.shields.io/badge/.NET-8.0-512BD4?logo=dotnet&logoColor=white)](https://dotnet.microsoft.com/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-EKS-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![Helm chart](https://img.shields.io/badge/Helm-kube--prometheus--stack%2092.3.0-0F1689?logo=helm&logoColor=white)](https://github.com/prometheus-community/helm-charts)
[![Prometheus](https://img.shields.io/badge/Prometheus-metrics-E6522C?logo=prometheus&logoColor=white)](https://prometheus.io/)
[![Grafana](https://img.shields.io/badge/Grafana-13.2.3-F46800?logo=grafana&logoColor=white)](https://grafana.com/)
[![OpenTelemetry](https://img.shields.io/badge/OpenTelemetry-Collector%200.160.0-000000?logo=opentelemetry&logoColor=white)](https://opentelemetry.io/)

Este diretório contém os manifests e configurações de observabilidade. A stack coleta as métricas HTTP da API de catálogo via OpenTelemetry e as armazena no Prometheus para consulta e visualização no Grafana.

## Componentes usados

| Componente | Versão/configuração | Responsabilidade |
|---|---|---|
| API PedeLogo Catálogo | .NET 8 | Aplicação instrumentada automaticamente pelo Operator |
| cert-manager | 1.21.2 (manifest incluído) | Certificados usados pelo webhook do OpenTelemetry Operator |
| OpenTelemetry Operator | Manifest Kubernetes incluído | Injeta a instrumentação .NET e gerencia o Collector |
| OpenTelemetry Collector Contrib | 0.160.0 | Recebe OTLP e expõe métricas Prometheus na porta 8889 |
| Prometheus Operator / Prometheus / Grafana | `kube-prometheus-stack` chart 92.3.0 | Scrape de `ServiceMonitor`, armazenamento e dashboards |

O número do chart acima corresponde à instalação usada neste projeto. Para verificar versões e revisão no cluster:

```bash
helm list -n monitoring
kubectl get pods -n monitoring
```

## Fluxo de métricas

```text
API .NET 8
  -> instrumentação automática OpenTelemetry
  -> OTLP HTTP :4318
  -> OpenTelemetry Collector
  -> exporter Prometheus :8889
  -> ServiceMonitor
  -> Prometheus
  -> dashboard Grafana
```

## Pré-requisitos

- Acesso ao cluster EKS com `kubectl` configurado para o contexto desejado.
- Helm 3 e acesso ao repositório `prometheus-community`.
- Executar os comandos abaixo a partir da raiz do repositório.
- A API e o OpenTelemetry Collector estão no namespace `default`; Prometheus e Grafana ficam no namespace `monitoring`.

## Implantação da stack

### 1. Instalar Prometheus, Operator e Grafana

O arquivo `prometheus-values.yaml` é um arquivo de valores Helm; **não** o aplique com `kubectl`. O chart instala os recursos do Prometheus Operator, incluindo a CRD `ServiceMonitor`. Grafana obtém o datasource Prometheus do próprio chart; não defina outro datasource padrão.

```bash
helm repo add prometheus-community \
  https://prometheus-community.github.io/helm-charts \
  --force-update
helm repo update

helm upgrade --install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --version 92.3.0 \
  --namespace monitoring \
  --create-namespace \
  --reset-values \
  --values observability/prometheus-values.yaml
```

Espere a CRD do `ServiceMonitor`, instalada pelo chart, ficar pronta:

```bash
kubectl wait --for=condition=Established \
  crd/servicemonitors.monitoring.coreos.com \
  --timeout=180s
```

> Se o release já existir, `helm upgrade --install` atualiza o mesmo release. Preserve o nome e namespace do release existente. `--reset-values` evita reaproveitar valores antigos, como um segundo datasource Grafana marcado como padrão.

### 2. Instalar cert-manager e OpenTelemetry Operator

O cert-manager incluído nos manifests é a versão 1.21.2. Ele precisa estar pronto antes do webhook do OpenTelemetry Operator:

```bash
kubectl apply -f observability/cert-manager.yaml
kubectl rollout status deployment/cert-manager -n cert-manager --timeout=180s
kubectl rollout status deployment/cert-manager-cainjector -n cert-manager --timeout=180s
kubectl rollout status deployment/cert-manager-webhook -n cert-manager --timeout=180s

kubectl apply -f observability/opentelemetry-operator.yaml
kubectl rollout status deployment/opentelemetry-operator-controller-manager \
  -n opentelemetry-operator-system --timeout=180s
kubectl wait --for=condition=Established \
  crd/instrumentations.opentelemetry.io \
  --timeout=180s
kubectl wait --for=condition=Established \
  crd/opentelemetrycollectors.opentelemetry.io \
  --timeout=180s
```

### 3. Instalar Collector, Instrumentation e ServiceMonitor

```bash
kubectl apply -f observability/opentelemetry-collector.yaml
kubectl apply -f observability/instrumentador.yaml
kubectl apply -f observability/serviceMonitor.yaml
```

O Collector recebe OTLP nas portas 4317 (gRPC) e 4318 (HTTP), exportando métricas Prometheus na porta 8889. O `ServiceMonitor` seleciona o Service criado pelo Operator. Confirme que o selector corresponde aos labels reais do Service:

```bash
kubectl get svc opentelemetry-collector-collector \
  -n default --show-labels
kubectl get endpoints opentelemetry-collector-collector -n default
kubectl get servicemonitor opentelemetry-service-monitor -n default -o yaml
```

### 4. Habilitar instrumentação na API

A Deployment precisa usar a anotação `instrumentation.opentelemetry.io/inject-dotnet: "instrumentador"` (já definida em `k8s/cadastro-k8s/cadastro.yaml`). Publique a alteração da Deployment pelo fluxo de CD do projeto ou aplique o manifesto com uma tag de imagem válida — não aplique a imagem placeholder `IMAGE_TAG`. Depois, reinicie os pods para a injeção ocorrer:

```bash
kubectl apply -f observability/instrumentador.yaml
kubectl rollout restart deployment/api-deployment -n default
kubectl rollout status deployment/api-deployment -n default --timeout=180s
```

Confira os pods e logs:

```bash
kubectl get pods -n default -l app=api
kubectl describe pods -n default -l app=api
kubectl logs -n default deployment/opentelemetry-collector-collector --tail=100
```

### 5. Carregar o dashboard

O ConfigMap contém o dashboard Catálogo - Observabilidade. O sidecar do Grafana o importa porque o ConfigMap tem o label `grafana_dashboard: "1"`. Aplique-o no mesmo namespace do Grafana:

```bash
kubectl apply --namespace monitoring \
  -f observability/grafana-dashboard.yaml
```

O dashboard oferece painéis de taxa de requisições, latência p95 e média, respostas HTTP 5xx, percentual de erros e taxa por rota. As consultas usam a métrica OpenTelemetry `http_server_request_duration_seconds`.

## Gerar tráfego de teste

Sem tráfego, os painéis da API podem não exibir séries. O script faz apenas requisições `GET` para `/Produto`, `/health` e `/swagger/index.html`; não cria nem altera produtos. O padrão é 60 requisições com intervalo de 1 segundo:

```bash
./observability/generate-api-traffic.sh
```

Personalize quantidade, intervalo e URL:

```bash
REQUESTS=120 INTERVAL_SECONDS=0.5 \
  API_BASE_URL=http://<load-balancer> \
  ./observability/generate-api-traffic.sh
```

## Acessar Grafana e Prometheus

Os serviços ficam como `ClusterIP`, acessíveis localmente via port-forward:

```bash
kubectl port-forward -n monitoring \
  svc/kube-prometheus-stack-grafana 3000:80
```

Abra <http://localhost:3000>. O usuário padrão do chart é `admin`; para consultar a senha gerada:

```bash
kubectl get secret -n monitoring kube-prometheus-stack-grafana \
  -o jsonpath='{.data.admin-password}' | base64 --decode
echo
```

Em outro terminal, acesse o Prometheus:

```bash
kubectl port-forward -n monitoring \
  svc/kube-prometheus-stack-prometheus 9090:9090
```

Abra <http://localhost:9090>.

## Validar coleta e diagnosticar ausência de métricas

1. No Prometheus, abra **Status → Targets** e confira o target do `ServiceMonitor` `opentelemetry-service-monitor` como `UP`.
2. Execute no Prometheus a consulta `up{service="opentelemetry-collector-collector"}`. O resultado deve ser `1`.
3. Gere tráfego para a API e consulte `http_server_request_duration_seconds_count`.
4. Se o target não aparecer, confira se a CRD está instalada, se o `ServiceMonitor` existe e se seus labels/namespace selecionam o Service do Collector:

   ```bash
   kubectl get crd servicemonitors.monitoring.coreos.com
   kubectl get servicemonitor -A
   kubectl get svc opentelemetry-collector-collector -n default --show-labels
   kubectl get endpoints opentelemetry-collector-collector -n default
   ```

5. Se o target estiver `UP`, mas a métrica da API não existir, verifique a anotação da Deployment, se os pods foram recriados após instalar a instrumentação e os logs do Collector.

## Arquivos desta pasta

| Arquivo | Conteúdo |
|---|---|
| `cert-manager.yaml` | cert-manager e CRDs |
| `opentelemetry-operator.yaml` | CRDs, RBAC e Operator |
| `opentelemetry-collector.yaml` | Collector com receptor OTLP e exporter Prometheus |
| `instrumentador.yaml` | Configuração da instrumentação automática .NET |
| `serviceMonitor.yaml` | Descoberta do endpoint de métricas pelo Prometheus |
| `prometheus-values.yaml` | Valores Helm para Prometheus/Grafana |
| `grafana-dashboard.yaml` | Dashboard provisionado por ConfigMap |
| `generate-api-traffic.sh` | Geração limitada de tráfego HTTP GET |
