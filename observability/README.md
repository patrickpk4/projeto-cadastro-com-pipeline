# Observabilidade



## Fluxo de métricas

```text
API .NET (OpenTelemetry)
        -> OpenTelemetry Collector
        -> Prometheus
        -> Grafana
```

O `prometheus-values.yaml` habilita o Grafana no chart `kube-prometheus-stack` e configura o sidecar para importar dashboards de ConfigMaps rotulados com `grafana_dashboard: "1"`. O chart provisiona o datasource Prometheus padrão; não adicione um segundo datasource padrão, pois isso impede o Grafana de iniciar.

## Instalação

`prometheus-values.yaml` é um arquivo de valores do Helm, não um manifesto Kubernetes. Não use `kubectl apply` nele. O recurso `ServiceMonitor` também não pode ser aplicado antes da instalação do Prometheus Operator, pois o chart instala a CRD `servicemonitors.monitoring.coreos.com`.

Execute os comandos a partir da raiz do repositório. Para instalar o Prometheus Operator, o Prometheus e o Grafana (ou atualizar uma instalação com o mesmo release e namespace):

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --reset-values \
  --values observability/prometheus-values.yaml
```

Espere a CRD do ServiceMonitor estar disponível e então aplique os recursos:

```bash
kubectl wait --for=condition=Established \
  crd/servicemonitors.monitoring.coreos.com \
  --timeout=120s
kubectl apply -f observability/serviceMonitor.yaml
kubectl apply --namespace monitoring -f observability/grafana-dashboard.yaml
```

Se o chart já estiver instalado com outro nome de release ou namespace, use esses valores no comando do Helm. O chart configura o datasource Prometheus para a instalação do próprio stack.

## Instrumentação da API

A Deployment da API referencia o recurso `Instrumentation` chamado `instrumentador`. Depois de aplicar/atualizar esse recurso e a Deployment, os pods existentes precisam ser recriados para receber a instrumentação automática:

```bash
kubectl apply -f observability/instrumentador.yaml
kubectl rollout restart deployment/api-deployment -n default
kubectl rollout status deployment/api-deployment -n default --timeout=180s
```

Gere tráfego para a API e confirme que a métrica `http_server_request_duration_seconds_count` aparece no Prometheus. Se não aparecer, confira os logs do Collector e a instrumentação no pod novo:

```bash
kubectl logs -n default deployment/opentelemetry-collector-collector --tail=100
kubectl describe pod -n default -l app=api
```

Para gerar tráfego de teste sem criar ou alterar produtos, execute o script abaixo. Ele envia 60 requisições GET, uma por segundo, para a API, health check e Swagger:

```bash
./observability/generate-api-traffic.sh
```

Ao executá-lo a partir deste diretório, use `./generate-api-traffic.sh`. Personalize a quantidade, intervalo ou URL base com variáveis de ambiente:

```bash
REQUESTS=120 INTERVAL_SECONDS=0.5 \
  API_BASE_URL=http://<load-balancer> \
  ./observability/generate-api-traffic.sh
```

## Dashboard do catálogo

O arquivo `grafana-dashboard.yaml` contém o dashboard Catálogo - Observabilidade, com painéis para taxa de requisições HTTP, latência p95 e média, respostas HTTP 5xx, percentual de erros e taxa por rota.

O dashboard é importado automaticamente pelo sidecar do Grafana. Os painéis de métricas da API usam a métrica OpenTelemetry `http_server_request_duration_seconds`; se aparecerem sem dados, confirme no Prometheus se essa métrica está sendo coletada e se o `ServiceMonitor` seleciona o Service do Collector.
