#!/usr/bin/env bash
# ============================================================================
# Diagnose why 5-Spot's kube-rs/rustls child client cannot connect to the
# k0smotron HOSTED control plane, while curl (OpenSSL) and client-go (kubelet /
# kubectl) connect to the same endpoint fine.
#
# Symptom: child-client GET/PATCH to the workload API hangs ~30s then fails with
#   "client error (Connect) -> ... -> deadline has elapsed"
# so the spot taint is never applied (k0smotron-tier Flag 2 stays red), even
# though the endpoint answers a plain curl in ~15ms.
#
# Run this ON node-01 inside the k0smotron workshop playground, AFTER the
# ScheduledMachine is applied and the worker has joined (SM phase=Active).
#
#   bash diagnose-rustls-k0s.sh [endpoint]
#   endpoint defaults to the externalAddress 172.16.0.2:30443; pass
#   kmc-dev-cluster-nodeport.default.svc:30443 to probe the in-cluster path.
#
# The key trick: 5-Spot's MANAGEMENT client (to the kind API) uses the SAME
# rustls and SUCCEEDS, while the CHILD client (to the k0s CP) FAILS — so the
# single rustls=trace stream below contains one complete handshake and one
# stalled one. Diffing them shows exactly which message the child never gets.
# ============================================================================
set -uo pipefail
CTX=kind-5spot-mgmt
NS=5spot-system
EP="${1:-172.16.0.2:30443}"

echo "════════════════════════════════════════════════════════════════════════"
echo "1. Server TLS profile (OpenSSL — the client that WORKS)"
echo "════════════════════════════════════════════════════════════════════════"
echo | timeout 8 openssl s_client -connect "$EP" 2>/dev/null \
  | grep -E "Protocol|Cipher|Peer signature|Server Temp Key|Acceptable client"
echo "-- TLS1.3 only --"; echo | timeout 8 openssl s_client -connect "$EP" -tls1_3 2>&1 \
  | grep -iE "Protocol|Cipher|handshake failure|no peer" | head -2
echo "-- TLS1.2 only (does the server even offer 1.2 as a fallback?) --"
echo | timeout 8 openssl s_client -connect "$EP" -tls1_2 2>&1 \
  | grep -iE "Protocol|Cipher|handshake failure|no protocols" | head -2
echo "-- Does the server REQUEST a client cert (mTLS / CertificateRequest)? --"
echo | timeout 8 openssl s_client -connect "$EP" 2>/dev/null \
  | grep -iE "Acceptable client certificate CA names|No client certificate CA names" | head -1

echo
echo "════════════════════════════════════════════════════════════════════════"
echo "2. Enable rustls=trace on 5-Spot and restart"
echo "════════════════════════════════════════════════════════════════════════"
kubectl --context $CTX -n $NS set env deploy/5spot-controller \
  RUST_LOG="warn,rustls=trace,five_spot=info" >/dev/null
kubectl --context $CTX -n $NS rollout status deploy/5spot-controller --timeout=120s >/dev/null
echo "restarted — waiting ~50s for the mgmt handshake (kind API, succeeds) AND a"
echo "child-client connection attempt ($EP, fails) to both appear in the trace..."
sleep 50

echo
echo "════════════════════════════════════════════════════════════════════════"
echo "3. rustls handshake trace (message + target, in order)"
echo "   Compare the COMPLETE handshake (to the kind API) against the one that"
echo "   STALLS (to the k0s CP). The last message the stalled side logs is the"
echo "   point of failure (e.g. stuck after 'Sending ClientHello' = no"
echo "   ServerHello back; stuck after a CertificateRequest = client-cert flow)."
echo "════════════════════════════════════════════════════════════════════════"
kubectl --context $CTX -n $NS logs deploy/5spot-controller --since=55s 2>&1 \
  | grep '"target":"rustls' \
  | sed -E 's/.*"message":"([^"]*)".*"target":"(rustls[^"]*)".*/[\2] \1/' \
  | tail -80

echo
echo "════════════════════════════════════════════════════════════════════════"
echo "4. The child-client failure line (for time-correlation with the trace)"
echo "════════════════════════════════════════════════════════════════════════"
kubectl --context $CTX -n $NS logs deploy/5spot-controller --since=55s 2>&1 \
  | grep -iE "Failed to GET Node for taint|cause=|deadline|$EP" | tail -3

echo
echo "════════════════════════════════════════════════════════════════════════"
echo "5. Revert log level"
echo "════════════════════════════════════════════════════════════════════════"
kubectl --context $CTX -n $NS set env deploy/5spot-controller RUST_LOG- >/dev/null
kubectl --context $CTX -n $NS rollout status deploy/5spot-controller --timeout=120s >/dev/null
echo "done."
