#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

DEFAULT_DRIVER="qemu2"
DEFAULT_PROFILE="minikube"
DEFAULT_MEMORY_MB="6144"
DEFAULT_CPUS="2"
DEFAULT_NAMESPACE="jmix-cluster-tests"
DEFAULT_IMAGE="docker.haulmont.com/platform/jmix-kube-tests/sample-cluster:jmix_2_0"
DEFAULT_K8S_DIR="./k8s"

DRIVER="$DEFAULT_DRIVER"
PROFILE="$DEFAULT_PROFILE"
MEMORY_MB="${MINIKUBE_MEMORY_MB:-$DEFAULT_MEMORY_MB}"
CPUS="${MINIKUBE_CPUS:-$DEFAULT_CPUS}"
NAMESPACE="$DEFAULT_NAMESPACE"
IMAGE="$DEFAULT_IMAGE"
K8S_DIR="$DEFAULT_K8S_DIR"
NETWORK=""
NETWORK_SET="false"

RECREATE="false"
RELOAD="false"
SKIP_DASHBOARD="false"
SKIP_BUILD="false"
GRADLE_CLEAN="true"
SKIP_PUSH="false"
SKIP_LOAD="false"
SKIP_DEPLOY="false"
DRY_RUN="false"
LOG_SEPARATOR="------------------------------------------------------------------------"

usage() {
  cat <<'EOF'
Usage:
  ./minikube_cluster.sh [options]

Default run:
  Running without options starts the minikube profile with driver=qemu2,
  enables ingress, selects kubectl context, opens dashboard, deletes old
  manifests, ensures namespace exists, runs './gradlew clean bootBuildImage',
  pushes the image with docker, loads it into minikube with overwrite=true,
  and applies Kubernetes manifests.

Examples:
  ./minikube_cluster.sh -r
  ./minikube_cluster.sh -r --no-gradle-clean
  ./minikube_cluster.sh --recreate

Options:
  -d, --driver DRIVER       Minikube driver (default: qemu2).
      --vm-driver DRIVER    Compatibility alias for --driver.
  -p, --profile PROFILE     Minikube profile/context (default: minikube).
  -m, --memory MB           Memory for minikube (default: 6144 or MINIKUBE_MEMORY_MB).
  -c, --cpus N              CPU count for minikube (default: 2 or MINIKUBE_CPUS).
      --network NAME|none   Network for minikube start (default: builtin for qemu2, omitted otherwise).
  -r, --reload              Skip cluster start and only redeploy image/configs (default: false).
      --recreate            Delete the minikube profile before starting it (default: false).
      --skip-dashboard      Do not open the minikube dashboard (default: dashboard is opened).
      --skip-build          Do not run Gradle image build (default: build is run).
      --no-gradle-clean     Run bootBuildImage without clean (default: clean is run).
      --skip-push           Do not push the image to the registry (default: docker push is run).
      --skip-load           Do not load the image into minikube (default: image load is run).
      --skip-deploy         Do not delete/apply Kubernetes configs (default: deploy is run).
      --namespace NAME      Kubernetes namespace to create before applying configs (default: jmix-cluster-tests).
      --image IMAGE         App image tag (default: docker.haulmont.com/platform/jmix-kube-tests/sample-cluster:jmix_2_0).
      --k8s-dir DIR         Directory with Kubernetes manifests (default: ./k8s).
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

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -d|--driver|--vm-driver)
        require_value "$1" "${2:-}"
        DRIVER="$2"
        shift 2
        ;;
      --driver=*|--vm-driver=*)
        DRIVER="${1#*=}"
        require_value "${1%%=*}" "$DRIVER"
        shift
        ;;
      -p|--profile)
        require_value "$1" "${2:-}"
        PROFILE="$2"
        shift 2
        ;;
      --profile=*)
        PROFILE="${1#*=}"
        require_value "--profile" "$PROFILE"
        shift
        ;;
      -m|--memory)
        require_value "$1" "${2:-}"
        MEMORY_MB="$2"
        shift 2
        ;;
      --memory=*)
        MEMORY_MB="${1#*=}"
        require_value "--memory" "$MEMORY_MB"
        shift
        ;;
      -c|--cpus)
        require_value "$1" "${2:-}"
        CPUS="$2"
        shift 2
        ;;
      --cpus=*)
        CPUS="${1#*=}"
        require_value "--cpus" "$CPUS"
        shift
        ;;
      --network)
        require_value "$1" "${2:-}"
        NETWORK="$2"
        NETWORK_SET="true"
        shift 2
        ;;
      --network=*)
        NETWORK="${1#*=}"
        require_value "--network" "$NETWORK"
        NETWORK_SET="true"
        shift
        ;;
      --recreate)
        RECREATE="true"
        shift
        ;;
      -r|--reload)
        RELOAD="true"
        shift
        ;;
      --skip-dashboard)
        SKIP_DASHBOARD="true"
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
      --skip-push)
        SKIP_PUSH="true"
        shift
        ;;
      --skip-load)
        SKIP_LOAD="true"
        shift
        ;;
      --skip-deploy)
        SKIP_DEPLOY="true"
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
  [[ "$DRIVER" != "podman" ]] || die "Driver 'podman' is not supported by this script"
  [[ "$RELOAD" != "true" || "$RECREATE" != "true" ]] || die "--recreate cannot be used together with --reload"
  [[ -n "$PROFILE" ]] || die "--profile cannot be empty"
  [[ -n "$MEMORY_MB" ]] || die "--memory cannot be empty"
  [[ -n "$CPUS" ]] || die "--cpus cannot be empty"
  [[ -n "$NAMESPACE" ]] || die "--namespace cannot be empty"
  [[ -n "$IMAGE" ]] || die "--image cannot be empty"
  [[ -n "$K8S_DIR" ]] || die "--k8s-dir cannot be empty"

  if [[ "$NETWORK_SET" != "true" ]]; then
    if [[ "$DRIVER" == "qemu2" ]]; then
      NETWORK="builtin"
    else
      NETWORK="none"
    fi
  fi

  if [[ "$SKIP_DEPLOY" != "true" && ! -d "$K8S_DIR" ]]; then
    die "Kubernetes manifest directory does not exist: $K8S_DIR"
  fi
}

validate_tools() {
  [[ "$DRY_RUN" == "true" ]] && return

  if [[ "$RELOAD" != "true" || "$SKIP_LOAD" != "true" ]]; then
    require_cmd minikube
  fi

  if [[ "$RELOAD" != "true" || "$SKIP_DEPLOY" != "true" ]]; then
    require_cmd kubectl
  fi

  if [[ "$SKIP_BUILD" != "true" && ! -x ./gradlew ]]; then
    die "Gradle wrapper is not executable: ./gradlew"
  fi

  if [[ "$SKIP_PUSH" != "true" ]]; then
    require_cmd docker
  fi
}

start_cluster() {
  if [[ "$RECREATE" == "true" ]]; then
    log_section "Delete minikube profile '$PROFILE'"
    run minikube -p "$PROFILE" delete
  fi

  local start_cmd=(
    minikube -p "$PROFILE" start
    "--driver=$DRIVER"
    "--memory=$MEMORY_MB"
    "--cpus=$CPUS"
  )

  if [[ "$NETWORK" != "none" ]]; then
    start_cmd+=("--network=$NETWORK")
  fi

  log_section "Start minikube profile '$PROFILE' (driver=$DRIVER, memory=$MEMORY_MB, cpus=$CPUS)"
  run "${start_cmd[@]}"

  log_section "Enable ingress addon"
  run minikube -p "$PROFILE" addons enable ingress

  log_section "Use kubectl context '$PROFILE'"
  run kubectl config use-context "$PROFILE"

  if [[ "$SKIP_DASHBOARD" != "true" ]]; then
    log_section "Open dashboard"
    print_shell_cmd "minikube -p $(printf %q "$PROFILE") dashboard >/dev/null 2>&1 &"
    if [[ "$DRY_RUN" == "true" ]]; then
      return
    fi

    minikube -p "$PROFILE" dashboard >/dev/null 2>&1 &
  fi
}

use_context_for_reload() {
  log_section "Use kubectl context '$PROFILE'"
  run kubectl config use-context "$PROFILE"
}

delete_deployment_configs() {
  log_section "Clear deployment configs"
  run kubectl delete -f "$K8S_DIR" --ignore-not-found=true --namespace="$NAMESPACE"
}

ensure_namespace() {
  log_section "Ensure namespace '$NAMESPACE'"
  print_shell_cmd "kubectl create namespace $(printf %q "$NAMESPACE") --dry-run=client -o yaml | kubectl apply -f -"
  if [[ "$DRY_RUN" == "true" ]]; then
    return
  fi

  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
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
  [[ "$SKIP_PUSH" == "true" ]] && return

  log_section "Push image"
  run docker push "$IMAGE"
}

load_image() {
  [[ "$SKIP_LOAD" == "true" ]] && return

  log_section "Load image into minikube"
  run minikube -p "$PROFILE" image load --overwrite=true "$IMAGE"
}

apply_deployment_configs() {
  log_section "Apply configs"
  run kubectl apply -f "$K8S_DIR" --namespace="$NAMESPACE"
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

  if [[ "$RELOAD" != "true" ]]; then
    start_cluster
  elif [[ "$SKIP_DEPLOY" != "true" ]]; then
    use_context_for_reload
  fi

  prepare_deploy
  build_image
  push_image
  load_image
  if [[ "$SKIP_DEPLOY" != "true" ]]; then
    apply_deployment_configs
  fi

  log_done
}

main "$@"
