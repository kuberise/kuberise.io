#!/bin/bash

set -euo pipefail

# Script to check if Promtail is working correctly across clusters via ClusterMesh

echo "=========================================="
echo "Promtail ClusterMesh Connectivity Check"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check 1: Promtail pod status
echo "1. Checking Promtail pod status..."
PROMTAIL_POD=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=promtail -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -z "$PROMTAIL_POD" ]; then
    echo -e "${RED}✗ Promtail pod not found${NC}"
    exit 1
fi

PROMTAIL_STATUS=$(kubectl get pod -n monitoring "$PROMTAIL_POD" -o jsonpath='{.status.phase}')
READY=$(kubectl get pod -n monitoring "$PROMTAIL_POD" -o jsonpath='{.status.containerStatuses[0].ready}')
if [ "$PROMTAIL_STATUS" = "Running" ] && [ "$READY" = "true" ]; then
    echo -e "${GREEN}✓ Promtail pod is running and ready${NC} (pod: $PROMTAIL_POD)"
else
    echo -e "${RED}✗ Promtail pod is not ready${NC} (status: $PROMTAIL_STATUS, ready: $READY)"
fi
echo ""

# Check 2: Global Service configuration
echo "2. Checking Loki Global Service configuration..."
SVC_GLOBAL=$(kubectl get svc -n monitoring loki-loki-distributed-gateway -o jsonpath='{.metadata.annotations.service\.cilium\.io/global}' 2>/dev/null || echo "")
SVC_SHARED=$(kubectl get svc -n monitoring loki-loki-distributed-gateway -o jsonpath='{.metadata.annotations.service\.cilium\.io/shared}' 2>/dev/null || echo "")

if [ "$SVC_GLOBAL" = "true" ]; then
    echo -e "${GREEN}✓ Global service annotation is set${NC}"
else
    echo -e "${RED}✗ Global service annotation is missing or false${NC}"
fi

if [ "$SVC_SHARED" = "true" ]; then
    echo -e "${GREEN}✓ Shared service annotation is set${NC}"
else
    echo -e "${YELLOW}⚠ Shared service annotation is false (should be true for ClusterMesh)${NC}"
fi
echo ""

# Check 3: Service endpoints
echo "3. Checking service endpoints..."
ENDPOINTS=$(kubectl get endpoints -n monitoring loki-loki-distributed-gateway -o jsonpath='{.subsets[0].addresses[*].ip}' 2>/dev/null || echo "")
if [ -n "$ENDPOINTS" ]; then
    echo -e "${GREEN}✓ Service has endpoints:${NC} $ENDPOINTS"
    # Check if endpoints are from remote cluster
    for ip in $ENDPOINTS; do
        POD_NAME=$(kubectl get pods -n monitoring --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.podIP}{"\n"}{end}' 2>/dev/null | grep -w "$ip" | awk '{print $1}' || echo "")
        if [ -z "$POD_NAME" ]; then
            echo -e "  ${GREEN}  → Endpoint $ip appears to be from remote cluster (ClusterMesh)${NC}"
        else
            echo -e "  → Endpoint $ip is local pod: $POD_NAME"
        fi
    done
else
    echo -e "${RED}✗ Service has no endpoints${NC}"
    echo "  This means ClusterMesh is not syncing endpoints from the shared cluster"
fi
echo ""

# Check 4: Promtail logs - connection errors
echo "4. Checking Promtail logs for connection errors..."
RECENT_ERRORS=$(kubectl logs -n monitoring "$PROMTAIL_POD" --tail=50 2>/dev/null | grep -i "error\|connection refused\|dial tcp" | tail -5 || echo "")
if [ -z "$RECENT_ERRORS" ]; then
    echo -e "${GREEN}✓ No recent connection errors in Promtail logs${NC}"
else
    echo -e "${RED}✗ Recent connection errors found:${NC}"
    echo "$RECENT_ERRORS" | sed 's/^/  /'
fi
echo ""

# Check 5: Promtail logs - successful pushes
echo "5. Checking for successful log pushes..."
RECENT_SUCCESS=$(kubectl logs -n monitoring "$PROMTAIL_POD" --tail=100 2>/dev/null | grep -i "success\|pushed\|sent" | tail -3 || echo "")
if [ -n "$RECENT_SUCCESS" ]; then
    echo -e "${GREEN}✓ Found successful log pushes:${NC}"
    echo "$RECENT_SUCCESS" | sed 's/^/  /'
else
    echo -e "${YELLOW}⚠ No recent successful log pushes found${NC}"
fi
echo ""

# Check 6: Test connectivity from Promtail pod
echo "6. Testing connectivity to Loki service from Promtail pod..."
# Try to connect to the service
CONNECT_TEST=$(kubectl exec -n monitoring "$PROMTAIL_POD" -- sh -c 'timeout 3 sh -c "echo > /dev/tcp/loki-loki-distributed-gateway.monitoring.svc.cluster.local/80" 2>&1' || echo "failed")
if echo "$CONNECT_TEST" | grep -q "failed\|timeout\|refused"; then
    echo -e "${RED}✗ Cannot connect to Loki service${NC}"
    echo "  This indicates ClusterMesh connectivity issue"
else
    echo -e "${GREEN}✓ Can connect to Loki service${NC}"
fi
echo ""

# Check 7: ClusterMesh status
echo "7. Checking ClusterMesh connectivity..."
CLUSTERMESH_POD=$(kubectl get pods -n kube-system -l k8s-app=clustermesh-apiserver -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$CLUSTERMESH_POD" ]; then
    CLUSTERMESH_STATUS=$(kubectl get pod -n kube-system "$CLUSTERMESH_POD" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
    if [ "$CLUSTERMESH_STATUS" = "Running" ]; then
        echo -e "${GREEN}✓ ClusterMesh API server is running${NC} (pod: $CLUSTERMESH_POD)"
    else
        echo -e "${RED}✗ ClusterMesh API server is not running${NC} (status: $CLUSTERMESH_STATUS)"
    fi
else
    echo -e "${RED}✗ ClusterMesh API server pod not found${NC}"
fi
echo ""

# Check 8: Verify Loki is accessible in shared cluster
echo "8. Checking if Loki is accessible in shared cluster..."
SHARED_CONTEXT=$(kubectl config view -o jsonpath='{.contexts[?(@.name == "k3d-dev-shared-onprem")].name}' 2>/dev/null || echo "")
if [ -n "$SHARED_CONTEXT" ]; then
    LOKI_PODS=$(kubectl get pods -n monitoring --context "$SHARED_CONTEXT" -l app.kubernetes.io/name=loki-distributed --no-headers 2>/dev/null | wc -l || echo "0")
    if [ "$LOKI_PODS" -gt 0 ]; then
        echo -e "${GREEN}✓ Loki is running in shared cluster${NC} ($LOKI_PODS pods)"
    else
        echo -e "${RED}✗ Loki is not running in shared cluster${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Cannot check shared cluster (context not found)${NC}"
fi
echo ""

# Summary
echo "=========================================="
echo "Summary"
echo "=========================================="
if [ "$SVC_GLOBAL" = "true" ] && [ "$SVC_SHARED" = "true" ] && [ -n "$ENDPOINTS" ] && [ -z "$RECENT_ERRORS" ]; then
    echo -e "${GREEN}✓ Promtail appears to be working correctly across clusters${NC}"
    echo ""
    echo "To verify logs are being ingested, check Loki:"
    echo "  kubectl port-forward -n monitoring --context k3d-dev-shared-onprem svc/loki-loki-distributed-gateway 3100:80"
    echo "  Then query: curl http://localhost:3100/loki/api/v1/label/__name__/values"
else
    echo -e "${YELLOW}⚠ Promtail may not be working correctly${NC}"
    echo ""
    echo "Common issues:"
    echo "  1. Service annotations not synced (wait for ArgoCD sync)"
    echo "  2. ClusterMesh not properly connected"
    echo "  3. Service endpoints not synced from remote cluster"
    echo ""
    echo "To fix:"
    echo "  1. Ensure service has: service.cilium.io/global: \"true\""
    echo "  2. Ensure service has: service.cilium.io/shared: \"true\""
    echo "  3. Verify ClusterMesh connectivity between clusters"
fi
