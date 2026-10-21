
# Manifestos Kubernetes

Os manifestos estão organizados por responsabilidade:

```text
k8s/
├── cadastro-k8s/   # API de catálogo
├── mongodb-k8s/    # Banco de dados MongoDB
└── README.md
```

Os diretórios `cadastro-k8s` e `mongodb-k8s` contêm os recursos da aplicação e do banco, incluindo Services, Secrets, RBAC, autoscaling e Network Policies.

As configurações de OpenTelemetry, Prometheus e Grafana foram separadas em `../observability/`.

Os testes auxiliares do cluster ficam em `../testeEks/` e são executados pelo workflow de teste do cluster.
