#!/bin/bash
# ==============================================================================
# render-validate.sh — Implementación del patrón "Render First, Validate Second"
# Audita Staging y Producción evaluando sintaxis YAML y esquemas oficiales de K8s.
# ==============================================================================
set -euo pipefail

ok()   { echo -e "  \033[0;32m[PASS]\033[0m $1"; }
fail() { echo -e " \033[0;31m[FAIL]\033[0m $1"; }
info() { echo -e "\n\033[1;34m=== $1 ===\033[0m"; }

CHART_DIR="./devops-portfolio"
TMP_DIR="/tmp/helm-render-test"
mkdir -p "$TMP_DIR"

info "1. Verificando estructura del Chart (Helm Lint)"
if helm lint "$CHART_DIR" > /dev/null 2>&1; then
    ok "Estructura semántica del Chart válida."
else
    fail "Errores detectados por helm lint."
    exit 1
fi

info "2. Procesando Renderizado Previo para STAGING y PRODUCCIÓN"
helm template test-staging "$CHART_DIR" -f "$CHART_DIR/values-staging.yaml" > "$TMP_DIR/staging-rendered.yaml"
ok "Renderizado exitoso de Staging -> $TMP_DIR/staging-rendered.yaml"

helm template test-prod "$CHART_DIR" -f "$CHART_DIR/values-prod.yaml" > "$TMP_DIR/prod-rendered.yaml"
ok "Renderizado exitoso de Producción -> $TMP_DIR/prod-rendered.yaml"

info "3. Validación de Sintaxis YAML sobre Manifiestos Procesados"
for env in staging prod; do
    python3 -c "
import yaml
with open('$TMP_DIR/${env}-rendered.yaml') as f:
    docs = list(yaml.safe_load_all(f))
    print('  [OK] ${env}: procesados ' + str(len(docs)) + ' objetos de Kubernetes sin errores.')
"
done

info "4. Validación de Esquema con Kubernetes API (kubectl dry-run)"
if kubectl apply --dry-run=client -f "$TMP_DIR/staging-rendered.yaml" > /dev/null 2>&1 && \
   kubectl apply --dry-run=client -f "$TMP_DIR/prod-rendered.yaml" > /dev/null 2>&1; then
    ok "Todos los objetos renderizados cumplen con los esquemas de la API de Kubernetes."
else
    fail "El API Server de Kubernetes rechazó las especificaciones renderizadas."
    exit 1
fi

echo -e "\n\033[1;32mPatrón 'Render First, Validate Second' completado con éxito para ambos entornos.\033[0m\n"
