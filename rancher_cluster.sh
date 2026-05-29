#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

DEFAULT_CONTEXT="rancher-desktop"
DEFAULT_NAMESPACE="jmix-cluster-tests"
DEFAULT_IMAGE="docker.haulmont.com/platform/jmix-kube-tests/sample-cluster:jmix_2_0"
DEFAULT_K8S_DIR="./k8s"
DEFAULT_APP_DEPLOYMENT="sample-app"
DEFAULT_PULL_POLICY="IfNotPresent"

CONTEXT="$DEFAULT_CONTEXT"
NAMESPACE="$DEFAULT_NAMESPACE"
IMAGE="$DEFAULT_IMAGE"
K8S_DIR="$DEFAULT_K8S_DIR"
APP_DEPLOYMENT="$DEFAULT_APP_DEPLOYMENT"
PULL_POLICY="$DEFAULT_PULL_POLICY"

SKIP_BUILD="false"
GRADLE_CLEAN="true"
PUSH="false"
SKIP_DEPLOY="false"
SKIP_ROLLOUT="false"
DRY_RUN="false"
LOG_SEPARATOR="------------------------------------------------------------------------"

usage() {
  cat <<'EOF'
Usage:
  ./rancher_cluster.sh [options]

Default run:
  Selects the 'rancher-desktop' kubectl context, deletes old manifests, ensures
  the namespace exists, runs './gradlew clean bootBuildImage', applies the
  Kubernetes manifests, patches the deployment's imagePullPolicy to
  IfNotPresent, and restarts the deployment so it picks up the freshly built
  local image. The image is NOT pushed to the registry by default — Rancher
  Desktop's dockerd is shared with k3s, so locally built images are pulled
  directly.

Examples:
  ./rancher_cluster.sh
  ./rancher_cluster.sh --no-gradle-clean
  ./rancher_cluster.sh --skip-build --skip-deploy   # only restart deployment

Options:
      --context NAME        Kubernetes context to use (default: rancher-desktop).
      --namespace NAME      Kubernetes namespace (default: jmix-cluster-tests).
      --image IMAGE         App image tag to build (default: docker.haulmont.com/platform/jmix-kube-tests/sample-cluster:jmix_2_0).
      --k8s-dir DIR         Directory with Kubernetes manifests (default: ./k8s).
      --pull-policy POLICY  imagePullPolicy patched onto the deployment (default: IfNotPresent).
      --skip-build          Do not run Gradle image build (default: build is run).
      --no-gradle-clean     Run bootBuildImage without clean (default: clean is run).
      --push                Push the image to the registry after building (default: no push).
      --skip-deploy         Do not delete/apply Kubernetes configs (default: deploy is run).
      --skip-rollout        Do not patch pull policy or restart the deployment.
      --dry-run             Print commands without executing them (default: false).
  -h, --help                Show this help.
EOF
}

die() {
  log_error "$*"
  exit 1
}

supports_color() {
  [[ -t 1 && -z "${NO_COLOR:-}" && "${TERM:-}" != "dumb" ]]
}

supports_error_color() {
  [[ -t 2 && -z "${NO_COLOR:-}" && "${TERM:-}" != "dumb" ]]
}

log_section() {
  local title="$1"

  if supports_color; then
    printf '\n\033[36m%s\033[0m\n' "$LOG_SEPARATOR"
    printf '\033[1;36m%s\033[0m\n' "$title"
    printf '\033[36m%s\033[0m\n' "$LOG_SEPARATOR"
  else
    printf '\n%s\n%s\n%s\n' "$LOG_SEPARATOR" "$title" "$LOG_SEPARATOR"
  fi
}

log_done() {
  log_section "Done"
}

log_error() {
  if supports_error_color; then
    printf '\033[31mERROR: %s\033[0m\n' "$*" >&2
  else
    printf 'ERROR: %s\n' "$*" >&2
  fi
}

require_value() {
  local option="$1"
  local value="${2:-}"

  if [[ -z "$value" || "$value" == -* ]]; then
    die "$option requires a value"
  fi
}

print_cmd() {
  printf '+'
  printf ' %q' "$@"
  printf '\n'
}

print_shell_cmd() {
  printf '+ %s\n' "$*"
}

run() {
  print_cmd "$@"

  if [[ "$DRY_RUN" == "true" ]]; then
    return
  fi

  "$@"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command is not available: $1"
}

kubectl_cmd() {
  local cmd=(kubectl)

  if [[ -n "$CONTEXT" ]]; then
    cmd+=(--context "$CONTEXT")
  fi

  cmd+=("$@")
  run "${cmd[@]}"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --context)
        require_value "$1" "${2:-}"
        CONTEXT="$2"
        shift 2
        ;;
      --context=*)
        CONTEXT="${1#*=}"
        require_value "--context" "$CONTEXT"
        shift
        ;;
      --namespace)
        require_value "$1" "${2:-}"
        NAMESPACE="$2"
        shift 2
        ;;
      --namespace=*)
        NAMESPACE="${1#*=}"
        require_value "--namespace" "$NAMESPACE"
        shift
        ;;
      --image)
        require_value "$1" "${2:-}"
        IMAGE="$2"
        shift 2
        ;;
      --image=*)
        IMAGE="${1#*=}"
        require_value "--image" "$IMAGE"
        shift
        ;;
      --k8s-dir)
        require_value "$1" "${2:-}"
        K8S_DIR="$2"
        shift 2
        ;;
      --k8s-dir=*)
        K8S_DIR="${1#*=}"
        require_value "--k8s-dir" "$K8S_DIR"
        shift
        ;;
      --pull-policy)
        require_value "$1" "${2:-}"
        PULL_POLICY="$2"
        shift 2
        ;;
      --pull-policy=*)
        PULL_POLICY="${1#*=}"
        require_value "--pull-policy" "$PULL_POLICY"
        shift
        ;;
      --skip-build)
        SKIP_BUILD="true"
        shift
        ;;
      --no-gradle-clean)
        GRADLE_CLEAN="false"
        shift
        ;;
      --push)
        PUSH="true"
        shift
        ;;
      --skip-deploy)
        SKIP_DEPLOY="true"
        shift
        ;;
      --skip-rollout)
        SKIP_ROLLOUT="true"
        shift
        ;;
      --dry-run)
        DRY_RUN="true"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      --)
        shift
        [[ $# -eq 0 ]] || die "Unexpected positional arguments: $*"
        ;;
      *)
        die "Unknown option: $1"
        ;;
    esac
  done
}

validate_config() {
  [[ -n "$CONTEXT" ]] || die "--context cannot be empty"
  [[ -n "$NAMESPACE" ]] || die "--namespace cannot be empty"
  [[ -n "$IMAGE" ]] || die "--image cannot be empty"
  [[ -n "$K8S_DIR" ]] || die "--k8s-dir cannot be empty"
  [[ -n "$PULL_POLICY" ]] || die "--pull-policy cannot be empty"

  case "$PULL_POLICY" in
    Always|IfNotPresent|Never) ;;
    *) die "--pull-policy must be one of: Always, IfNotPresent, Never" ;;
  esac

  if [[ "$SKIP_DEPLOY" != "true" && ! -d "$K8S_DIR" ]]; then
    die "Kubernetes manifest directory does not exist: $K8S_DIR"
  fi
}

validate_tools() {
  [[ "$DRY_RUN" == "true" ]] && return

  if [[ "$SKIP_DEPLOY" != "true" || "$SKIP_ROLLOUT" != "true" ]]; then
    require_cmd kubectl
  fi

  if [[ "$SKIP_BUILD" != "true" && ! -x ./gradlew ]]; then
    die "Gradle wrapper is not executable: ./gradlew"
  fi

  if [[ "$PUSH" == "true" ]]; then
    require_cmd docker
  fi
}

verify_context() {
  [[ "$DRY_RUN" == "true" ]] && return

  if ! kubectl config get-contexts -o name 2>/dev/null | grep -qx "$CONTEXT"; then
    die "kubectl context '$CONTEXT' not found. Make sure Rancher Desktop is running."
  fi
}

use_context() {
  log_section "Use kubectl context '$CONTEXT'"
  run kubectl config use-context "$CONTEXT"
}

delete_deployment_configs() {
  log_section "Clear deployment configs"
  kubectl_cmd delete -f "$K8S_DIR" --ignore-not-found=true --namespace="$NAMESPACE"
}

ensure_namespace() {
  log_section "Ensure namespace '$NAMESPACE'"

  if [[ -n "$CONTEXT" ]]; then
    print_shell_cmd "kubectl --context $(printf %q "$CONTEXT") create namespace $(printf %q "$NAMESPACE") --dry-run=client -o yaml | kubectl --context $(printf %q "$CONTEXT") apply -f -"
  else
    print_shell_cmd "kubectl create namespace $(printf %q "$NAMESPACE") --dry-run=client -o yaml | kubectl apply -f -"
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    return
  fi

  if [[ -n "$CONTEXT" ]]; then
    kubectl --context "$CONTEXT" create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl --context "$CONTEXT" apply -f -
  else
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
  fi
}

build_image() {
  [[ "$SKIP_BUILD" == "true" ]] && return

  log_section "Build app image"
  if [[ "$GRADLE_CLEAN" == "true" ]]; then
    run ./gradlew clean bootBuildImage
  else
    run ./gradlew bootBuildImage
  fi
}

push_image() {
  [[ "$PUSH" != "true" ]] && return

  log_section "Push image"
  run docker push "$IMAGE"
}

apply_deployment_configs() {
  log_section "Apply configs"
  kubectl_cmd apply -f "$K8S_DIR" --namespace="$NAMESPACE"
}

patch_pull_policy() {
  log_section "Patch imagePullPolicy to '$PULL_POLICY'"
  kubectl_cmd patch deployment "$APP_DEPLOYMENT" --namespace="$NAMESPACE" \
    --type=strategic \
    --patch "{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"$APP_DEPLOYMENT\",\"imagePullPolicy\":\"$PULL_POLICY\"}]}}}}"
}

restart_app() {
  log_section "Restart app deployment"
  kubectl_cmd rollout restart "deployment/$APP_DEPLOYMENT" --namespace="$NAMESPACE"
}

prepare_deploy() {
  [[ "$SKIP_DEPLOY" == "true" ]] && return

  delete_deployment_configs
  ensure_namespace
}

main() {
  parse_args "$@"
  validate_config
  validate_tools
  verify_context

  use_context

  prepare_deploy
  build_image
  push_image

  if [[ "$SKIP_DEPLOY" != "true" ]]; then
    apply_deployment_configs
  fi

  if [[ "$SKIP_ROLLOUT" != "true" ]]; then
    patch_pull_policy
    restart_app
  fi

  log_done
}

main "$@"
