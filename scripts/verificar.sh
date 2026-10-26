#!/bin/bash
set -uo pipefail

NS="devops-portfolio"
ERRORS=0

ok()   { echo "  [OK]   $1"; }
fail() { echo "  [FAIL] $1"; ERRORS=$((ERRORS+1)); }

echo "================================================="
echo "  VERIFICACIÓN HELM & INGRESS (TP10B - RENDER)"
echo "================================================="
echo ""

echo "--- 1. Validación de Renderizado (Render First) ---"
VALUES_FILE="values-prod.yaml"
[ -f "devops-portfolio/values-prod.yaml" ] && VALUES_FILE="devops-portfolio/values-prod.yaml"

if helm template test-release ./devops-portfolio -f "$VALUES_FILE" > /tmp/test-rendered.yaml 2>/dev/null; then
  ok "Renderizado de plantillas Go completado exitosamente"
  if python3 -c "import yaml; list(yaml.safe_load_all(open('/tmp/test-rendered.yaml')))" 2>/dev/null; then
    ok "Sintaxis YAML del manifiesto renderizado correcta (sin falsos positivos)"
  else
    fail "Error de sintaxis en el YAML renderizado"
  fi
else
  fail "Error al ejecutar helm template"
fi

echo ""
echo "--- 2. Estado del Release de Helm ---"
if helm status mi-app -n $NS &>/dev/null; then
  STATUS=$(helm status mi-app -n $NS | grep STATUS | awk '{print $2}')
  [ "$STATUS" = "deployed" ] && ok "Release 'mi-app' -> $STATUS" || fail "Release 'mi-app' -> $STATUS"
else
  fail "Release 'mi-app' no encontrado en el namespace $NS"
fi

echo ""
echo "--- 3. Pods en Kubernetes ---"
kubectl get pods -n $NS --no-headers 2>/dev/null |
while read line; do
  NAME=$(echo $line   | awk '{print $1}')
  STATUS=$(echo $line | awk '{print $3}')
  READY=$(echo $line  | awk '{print $2}')
  [ "$STATUS" = "Running" ] && ok "$NAME -> $STATUS ($READY)" || fail "$NAME -> $STATUS"
done

echo ""
echo "--- 4. Ingress y Enrutamiento Capa 7 ---"
kubectl get ingress -n $NS --no-headers 2>/dev/null |
while read line; do
  NAME=$(echo $line | awk '{print $1}')
  HOST=$(echo $line | awk '{print $3}')
  ok "Ingress '$NAME' configurado para host: $HOST"
done

echo ""
echo "--- 5. Pruebas de Salud HTTP vía Ingress ---"
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}' 2>/dev/null || echo "127.0.0.1")
for path in "/" "/health" "/api/notes"; do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: devops-portfolio.dev" --max-time 5 "http://$NODE_IP:30080$path" 2>/dev/null || echo "000")
  [ "$CODE" = "200" ] && ok "Endpoint $path -> HTTP $CODE" || fail "Endpoint $path -> HTTP $CODE"
done

echo ""
if [ "$ERRORS" -eq 0 ]; then
  echo "=== TP10B OK: Todos los checks de renderizado y despliegue pasaron ==="
else
  echo "=== ATENCIÓN: $ERRORS checks fallaron ==="
fi
