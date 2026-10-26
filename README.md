# TP 10 — Kubernetes avanzado: Helm + Ingress

## Estructura del Chart

devops-portfolio/ 
├── Chart.yaml # metadata del chart 
├── values.yaml # valores por defecto 
├── values-dev.yaml # override para desarrollo 
├── values-prod.yaml # override para producción 
└── templates/ 
├── _helpers.tpl # funciones reutilizables 
├── namespace.yaml 
├── secret.yaml 
├── configmap.yaml 
├── postgres.yaml # PVC + Deployment + Service 
├── backend.yaml # Deployment + HPA + Service 
├── frontend.yaml # Deployment + Service 
├── ingress.yaml # Ingress con rutas 
└── NOTES.txt # mensaje post-instalación

## Comandos principales

Ejecutar en bash
# Validar el chart
helm lint devops-portfolio/

# Ver manifests generados
helm template mi-app devops-portfolio/ --values values-dev.yaml

# Instalar
helm install mi-app devops-portfolio/ --values values-dev.yaml

# Actualizar
helm upgrade mi-app devops-portfolio/ --values values-dev.yaml

# Rollback
helm rollback mi-app 1

# Desinstalar
helm uninstall mi-app
Ingress: routing por paths
Path	Servicio destino
/	frontend-service :80
/api/*	backend-service :5000
/health	backend-service :5000
Multi-entorno
helm install mi-app devops-portfolio/ --values values-dev.yaml   # dev
helm install mi-app devops-portfolio/ --values values-prod.yaml  # prod

# DevOps Portfolio — TP10C: Entrega Continua con Helm Multi-Entorno

![Helm CD Pipeline](https://github.com/melaniedenisemai/devops-TP10/actions/workflows/helm-cd.yml/badge.svg)

Pipeline de Entrega Continua gobernado por **Helm**, aplicando el patrón **Render First, Validate Second** (TP10B), compuertas de aprobación manual y reversión automática ante fallos de despliegue.

## Releases y Entornos
| Release | Namespace | Archivo Values | Réplicas BE | Ingress Host | Aprobación |
|---|---|---|---|---|---|
| `notes-staging` | `staging` | `values-staging.yaml` | 1 | `staging.devops-portfolio.local` | Automática |
| `notes-prod` | `production` | `values-prod.yaml` | 3 (HPA) | `devops-portfolio.com` | Manual Gate |

## Operaciones de Despliegue y Rollback
```bash
# Validar renderizado previo localmente (Técnica TP10B)
bash scripts/render-validate.sh

# Actualizar release manualmente
helm upgrade --install notes-prod ./devops-portfolio -f devops-portfolio/values-prod.yaml -n production

# Historial de versiones del release
helm history notes-prod -n production

# Rollback a la versión anterior inmediata
helm rollback notes-prod 0 -n production

# Auditoría automatizada
bash scripts/verificar-helm-entornos2.sh
