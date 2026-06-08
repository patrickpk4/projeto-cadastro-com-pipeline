
# Kubernetes Catálogo App - MongoDB & .NET Core

Uma aplicação completa de catálogo implementada em **Kubernetes** com **MongoDB** e **.NET Core**, demonstrando boas práticas de orquestração de containers, auto-escalonamento e persistência de dados.

---

## Arquitetura

![Diagrama da Arquitetura](A_diagram_displays_the_architecture_of_a_Kubernete.png)

A aplicação é dividida em dois namespaces:

- **api-app**: Contém a API .NET Core, seus Secrets, ServiceAccount, Role, RoleBinding e HPA.
- **data-base**: Contém o MongoDB como StatefulSet, seu Secret, Headless Service, Role, RoleBinding e HPA.

A comunicação entre os namespaces é controlada por uma **NetworkPolicy**.

---

## Estrutura do Projeto

```
catalogo-kubernetes/
├── api-app/
│   ├── catalogo.yaml
│   ├── service-catalogo.yaml
│   ├── secret-catalogo.yaml
│   ├── serviceaccount-catalogo.yaml
│   ├── role-catalogo.yaml
│   ├── rolebinding-catalogo.yaml
│   ├── hpa-catalogo.yaml
│   └── networkpolicy-catalogo.yaml
├── data-base/
│   ├── mongodb.yaml
│   ├── service-mongodb.yaml
│   ├── secret-mongodb.yaml
│   ├── serviceaccount-mongodb.yaml
│   ├── role-mongodb.yaml
│   ├── rolebinding-mongodb.yaml
│   ├── hpa-mongodb.yaml
│   └── networkpolicy-mongodb.yaml
├── storage/
│   └── storage-class-mongodb.yaml
└── README.md
```

---

## Componentes Principais

| Componente | Tecnologia | Função |
|-------------|-------------|--------|
| **API Backend** | .NET Core 6.0 | API REST do catálogo |
| **Database** | MongoDB 4.4 | Armazenamento de dados |
| **Orquestração** | Kubernetes | Orquestração de containers |
| **Armazenamento** | NFS | Persistência de dados |
| **Networking** | Calico | Network policies |

---

## Serviços

| Serviço | Tipo | Porta | Descrição |
|----------|------|-------|------------|
| **api-service** | NodePort | 80/443 | Exposição externa da aplicação |
| **mongo-service** | Headless | 27017 | Comunicação interna MongoDB |

---

## Deploy Passo a Passo

### 1. Criar Namespaces
```bash
kubectl create namespace api-app
kubectl create namespace data-base
```

### 2. Deploy do MongoDB
```bash
kubectl apply -f data-base/secret-mongodb.yaml
kubectl apply -f storage/storage-class-mongodb.yaml
kubectl apply -f data-base/mongodb.yaml
kubectl apply -f data-base/service-mongodb.yaml
kubectl apply -f data-base/serviceaccount-mongodb.yaml
kubectl apply -f data-base/role-mongodb.yaml
kubectl apply -f data-base/rolebinding-mongodb.yaml
```

### 3. Deploy da API Catálogo
```bash
kubectl apply -f api-app/secret-catalogo.yaml
kubectl apply -f api-app/catalogo.yaml
kubectl apply -f api-app/service-catalogo.yaml
kubectl apply -f api-app/serviceaccount-catalogo.yaml
kubectl apply -f api-app/role-catalogo.yaml
kubectl apply -f api-app/rolebinding-catalogo.yaml
```

### 4. Configurar Auto-scaling
```bash
kubectl apply -f api-app/hpa-catalogo.yaml
kubectl apply -f data-base/hpa-mongodb.yaml
```

### 5. Aplicar Network Policies
```bash
kubectl apply -f api-app/networkpolicy-catalogo.yaml
kubectl apply -f data-base/networkpolicy-mongodb.yaml
```

---

## Variáveis de Ambiente

**Secret do MongoDB:**
```yaml
MONGO_INITDB_ROOT_USERNAME: mongouser
MONGO_INITDB_ROOT_PASSWORD: mongopwd
```

**Secret da Aplicação:**
```yaml
Mongo__host: mongo-service.data-base.svc.cluster.local
Mongo__port: 27017
Mongo__DataBase: admin
```

---

## Resource Limits

```yaml
# API
requests:
  memory: 128Mi
  cpu: 50m
limits:
  memory: 128Mi
  cpu: 70m

# MongoDB
requests:
  memory: 180Mi
  cpu: 150m
limits:
  memory: 256Mi
  cpu: 250m
```

---

## Health Checks

**MongoDB**
- Startup: `mongo --eval "db.adminCommand('ping')"`
- Readiness: TCP socket 27017
- Liveness: `mongo --eval "db.adminCommand('ping')"`

**API**
- Readiness: HTTP GET `/read`
- Liveness: HTTP GET `/health`

---

## Segurança

**RBAC**
- Service Accounts específicos por namespace  
- Roles com princípio do menor privilégio  
- ClusterRoles para acesso cross-namespace  

**Network Policies**
- Isolamento entre namespaces  
- Acesso restrito à porta do MongoDB  
- Permissão para DNS resolution  

**Secrets**
- Credenciais em Base64  
- Namespace isolation  
- Controle de acesso via RBAC  

---

## Persistência

**StorageClass NFS**
```yaml
provisioner: cluster.local/nfs-subdir-external-provisioner
server: 192.168.1.21
path: /export
reclaimPolicy: Retain
```

---

## Monitoramento

```bash
kubectl get pods -n api-app
kubectl get pods -n data-base
kubectl logs -n api-app -l app=api
kubectl logs -n data-base -l app=mongodb
kubectl get hpa -A
```

---

## Troubleshooting

```bash
kubectl get events -A --sort-by='.lastTimestamp'
kubectl run test-connection -n api-app --image=busybox --rm -it -- sh
kubectl auth can-i get secrets --as=system:serviceaccount:api-app:catalogo-service-account
kubectl rollout restart deployment/api-deployment -n api-app
```

---

## Boas Práticas Implementadas

✅ Multi-namespace para isolamento  
✅ RBAC com princípio do menor privilégio  
✅ Health checks completos  
✅ Auto-scaling horizontal  
✅ Persistência com NFS  
✅ Network policies para segurança  
✅ Resource limits definidos  
✅ Secrets management adequado  
✅ StatefulSet para banco de dados  
✅ Probes para resiliência  

---

## Autor

**Patrick Amorim**  
Projeto de estudo em Kubernetes, MongoDB e .NET Core  
GitHub: [@patrickpk4](https://github.com/patrickpk4)

---

## Licença
Projeto de estudo e uso educacional.
