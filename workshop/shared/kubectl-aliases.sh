# 5-Spot workshop — canonical kubectl aliases + completion.
#
# SINGLE SOURCE OF TRUTH. Installed by every tier's pre-bake
# (workshop/*/setup-background.sh copies this to /etc/profile.d/ and sources it
# from the shell rc files) and safe to `source` directly in any shell:
#
#     source workshop/shared/kubectl-aliases.sh      # load in the current shell
#
# If a pre-bake ran in a shell you already had open, just `exec bash` (or open a
# new terminal) to pick these up.
#
# Not executed — meant to be SOURCED. No shebang on purpose.

# kubectl bash-completion, and make `k` complete just like kubectl.
# Interactive bash only — guarded so sourcing in a script/zsh is harmless.
if command -v kubectl >/dev/null 2>&1 && [ -n "${BASH_VERSION:-}" ]; then
  source <(kubectl completion bash) 2>/dev/null || true
  complete -o default -F __start_kubectl k 2>/dev/null || true
fi

alias k='kubectl'
alias kg='kubectl get'
alias kp='kubectl get pods'
alias kgp='kubectl get pods'
alias kgpa='kubectl get pods -A'
alias kgpo='kubectl get pods -o wide'
alias kgpw='kubectl get pods -w'
alias kgs='kubectl get svc'
alias kgn='kubectl get nodes'
alias kgno='kubectl get nodes -o wide'
alias kgd='kubectl get deploy'
alias kga='kubectl get all'
alias kgaa='kubectl get all -A'
alias kge='kubectl get events --sort-by=.lastTimestamp'
alias kd='kubectl describe'
alias kdp='kubectl describe pod'
alias kdn='kubectl describe node'
alias kl='kubectl logs'
alias klf='kubectl logs -f'
alias ke='kubectl exec -it'
alias kaf='kubectl apply -f'
alias kdel='kubectl delete'
alias kdelf='kubectl delete -f'
alias kx='kubectl config use-context'
alias kctx='kubectl config get-contexts'
alias kns='kubectl config set-context --current --namespace'
alias kcd='kubectl config set-context --current --namespace'

# 5-Spot specifics: the ScheduledMachine CRD, the mgmt context, the workload cluster.
alias ksm='kubectl get sm -A'
alias kdsm='kubectl describe sm'
alias kmgmt='kubectl --context kind-5spot-mgmt'
alias kwl='kubectl --kubeconfig $HOME/dev-cluster.kubeconfig'
