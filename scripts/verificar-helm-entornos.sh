#!/bin/bash
set -euo pipefail

TOTAL=0
PASSED=0

ok()   { echo -e "  \033[0;32m[PASS]\033[0m $1"; PASSED=$((PASSED+1)); }
fail() { echo -e "  \033[0;31m[FAIL]\033[0m $1"; }
info() { echo -e "\n\033[1;34m=== $1 ===\033[0m"; }
eval_check() { TOTAL=$((TOTAL+1)); }

echo -e "\033[1;36m"
echo "=============================================================="
echo "    AUDITORÍA MULTI-ENTORNO CON HELM & INGRESS (TP10C)"
echo "=============================================================="
echo -e "\033[0m"

info "1. Verificación de Releases de Helm Activos"
for rel in "notes-staging:staging" "notes-prod:production"; do
    NAME=$(echo "$rel" | cut -d':' -f1)
    NS=$(echo "$rel" | cut -d':' -f2)
    eval_check
    STATUS=$(helm status "$NAME" -n "$NS" 2>/dev/null | grep STATUS | awk '{print $2}' || echo "NOT_FOUND")
    if [ "$STATUS" = "deployed" ]; then
        ok "Release '$NAME' en namespace '$NS' -> $STATUS"
    else
        fail "Release '$NAME' en namespace '$NS' -> $STATUS"
    fi
done

info "2. Verificación de Réplicas y Recursos por Entorno"
eval_check
STAGING_REPLICAS=$(kubectl get deployment backend -n staging -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
if [ "$STAGING_REPLICAS" -eq 1 ]; then
    ok "Staging configurado correctamente con $STAGING_REPLICAS réplica."
else
    fail "Staging tiene $STAGING_REPLICAS réplicas (esperado: 1)."
fi

eval_check
PROD_REPLICAS=$(kubectl get deployment backend -n production -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
if [ "$PROD_REPLICAS" -ge 2 ]; then
    ok "Producción configurado con Alta Disponibilidad: $PROD_REPLICAS réplicas."
else
    fail "Producción tiene $PROD_REPLICAS réplicas (esperado: >= 2)."
fi

info "3. Verificación de Enrutamiento Ingress (Capa 7)"
eval_check
HOST_STAGING=$(kubectl get ingress -n staging -o jsonpath='{.items[0].spec.rules[0].host}' 2>/dev/null || echo "")
if [ "$HOST_STAGING" = "staging.devops-portfolio.local" ]; then
    ok "Ingress de Staging apuntando a host: $HOST_STAGING"
else
    fail "Host de Ingress en Staging inesperado: '$HOST_STAGING'"
fi

eval_check
HOST_PROD=$(kubectl get ingress -n production -o jsonpath='{.items[0].spec.rules[0].host}' 2>/dev/null || echo "")
if [ "$HOST_PROD" = "devops-portfolio.com" ]; then
    ok "Ingress de Producción apuntando a host: $HOST_PROD"
else
    fail "Host de Ingress en Producción inesperado: '$HOST_PROD'"
fi

info "4. Auditoría de Historial de Helm (Capacidad de Rollback)"
eval_check
REVS=$(helm history notes-prod -n production 2>/dev/null | wc -l || echo "0")
if [ "$REVS" -ge 2 ]; then
    ok "Historial de Helm preservado en Producción (Revisión actual registrada)."
else
    fail "No se registra historial suficiente para ejecutar rollback en Producción."
fi

echo -e "\n\033[1;35m==============================================================\033[0m"
echo -e " Resultado: \033[1;32m$PASSED de $TOTAL pruebas superadas\033[0m"
if [ "$PASSED" -eq "$TOTAL" ]; then
    echo -e " Estado: \033[1;32m¡APROBADO CON ÉXITO!\033[0m Entornos Helm 100% operativos."
else
    echo -e " Estado: \033[1;31mREQUIERE AJUSTES\033[0m"
fi
echo ""
