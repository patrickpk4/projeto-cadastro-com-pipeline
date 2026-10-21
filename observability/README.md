# Observabilidade



## Fluxo de métricas

```text
API .NET (OpenTelemetry)
        -> OpenTelemetry Collector
        -> Prometheus
        -> Grafana
```

O `prometheus-values.yaml` habilita o Grafana no chart `kube-prometheus-stack`, provisiona o datasource Prometheus (`prometheus-operated:9090`) e configura o sidecar para importar dashboards de ConfigMaps rotulados com `grafana_dashboard: "1"`.

## Dashboard do catálogo

O arquivo `grafana-dashboard.yaml` contém o dashboard Catálogo - Observabilidade, com painéis para taxa de requisições HTTP, latência p95 e média, respostas HTTP 5xx, percentual de erros e taxa por rota.

1. Atualize a instalação existente do chart `kube-prometheus-stack` com `prometheus-values.yaml`, mantendo o mesmo release e namespace usados pelo Prometheus:

   ```bash
   helm upgrade <release> prometheus-community/kube-prometheus-stack \
     --namespace <namespace> \
     --reuse-values \
     --values observability/prometheus-values.yaml
   ```

2. Aplique o ConfigMap no namespace onde o Grafana está instalado. Por padrão, o dashboard aponta para o serviço `prometheus-operated` no mesmo namespace:

   ```bash
   kubectl apply --namespace <namespace> -f observability/grafana-dashboard.yaml
   ```

O dashboard é importado automaticamente pelo sidecar do Grafana. Os painéis de métricas da API usam a métrica OpenTelemetry `http_server_request_duration_seconds`; se aparecerem sem dados, confirme no Prometheus se essa métrica e as métricas `otelcol_*` estão sendo coletadas.
