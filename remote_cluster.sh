#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

NAMESPACE="jmix-cluster-tests"
IMAGE="docker.haulmont.com/platform/jmix-kube-tests/sample-cluster:jmix_2_0"
IMAGE_PLATFORM="linux/amd64"
BUILD_IMAGE_PULL_POLICY="ALWAYS"
K8S_DIR="./k8s"
APP_DEPLOYMENT="sample-app"

CONTEXT=""
MODE=""
SCALE_REPLICAS=""

SKIP_BUILD="false"
GRADLE_CLEAN="true"
SKIP_PUSH="false"
SKIP_APPLY="false"
SKIP_ROLLOUT="false"
DRY_RUN="false"
IMAGE_PLATFORM_SET="false"
KUBECONFIG_DIR=""
KUBECONFIG_FILE=""
LOG_SEPARATOR="------------------------------------------------------------------------"

usage() {
  cat <<'EOF'
Usage:
  ./remote_cluster.sh --apply [options]
  ./remote_cluster.sh --delete [options]
  ./remote_cluster.sh --scale N [options]

Running without options prints this help.

Before running, put the remote kubeconfig file content into KUBECONFIG_CONTENT.

Options:
      --apply               Build, push, delete/apply Kubernetes configs, patch pull policy, and restart deployment/sample-app.
      --delete              Delete Kubernetes configs from ./k8s and exit.
      --scale N             Scale deployment/sample-app to N replicas and exit (also supports --scale=N).
      --context NAME        Kubernetes context from KUBECONFIG_CONTENT (default: kubeconfig current-context).
      --skip-build          Do not run Gradle image build (default: build is run).
      --no-gradle-clean     Run bootBuildImage without clean (default: clean is run).
      --skip-push           Do not push the image to the registry (default: docker push is run).
      --skip-apply          Do not delete/apply Kubernetes configs (default: configs are redeployed).
      --skip-rollout        Do not patch pull policy or restart deployment/sample-app.
      --image-platform P    Target platform for bootBuildImage (default: linux/amd64).
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

set_mode() {
  local mode="$1"

  [[ -z "$MODE" ]] || die "Only one mode can be selected"
  MODE="$mode"
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

require_kubeconfig_file() {
  [[ "$DRY_RUN" == "true" ]] && return
  [[ -s "$KUBECONFIG_FILE" ]] || die "Temporary kubeconfig is missing or empty: $KUBECONFIG_FILE"
}

kubectl_cmd() {
  require_kubeconfig_file

  local cmd=(kubectl)

  if [[ -n "$CONTEXT" ]]; then
    cmd+=(--context "$CONTEXT")
  fi

  cmd+=("$@")
  run "${cmd[@]}"
}

parse_args() {
  if [[ $# -eq 0 ]]; then
    usage
    exit 0
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --apply)
        set_mode "apply"
        shift
        ;;
      --delete)
        set_mode "delete"
        shift
        ;;
      --scale)
        if [[ $# -lt 2 || -z "${2:-}" ]]; then
          die "--scale requires 0 or a positive integer"
        fi
        set_mode "scale"
        SCALE_REPLICAS="$2"
        shift 2
        ;;
      --scale=*)
        SCALE_REPLICAS="${1#*=}"
        if [[ -z "$SCALE_REPLICAS" ]]; then
          die "--scale requires 0 or a positive integer"
        fi
        set_mode "scale"
        shift
        ;;
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
      --skip-apply)
        SKIP_APPLY="true"
        shift
        ;;
      --skip-rollout)
        SKIP_ROLLOUT="true"
        shift
        ;;
      --image-platform)
        require_value "$1" "${2:-}"
        IMAGE_PLATFORM="$2"
        IMAGE_PLATFORM_SET="true"
        shift 2
        ;;
      --image-platform=*)
        IMAGE_PLATFORM="${1#*=}"
        require_value "--image-platform" "$IMAGE_PLATFORM"
        IMAGE_PLATFORM_SET="true"
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
  [[ -n "$MODE" ]] || die "One mode is required: --apply, --delete, or --scale"

  if [[ "$MODE" != "apply" ]]; then
    [[ "$SKIP_BUILD" == "false" ]] || die "--skip-build can only be used with --apply"
    [[ "$GRADLE_CLEAN" == "true" ]] || die "--no-gradle-clean can only be used with --apply"
    [[ "$SKIP_PUSH" == "false" ]] || die "--skip-push can only be used with --apply"
    [[ "$SKIP_APPLY" == "false" ]] || die "--skip-apply can only be used with --apply"
    [[ "$SKIP_ROLLOUT" == "false" ]] || die "--skip-rollout can only be used with --apply"
    [[ "$IMAGE_PLATFORM_SET" == "false" ]] || die "--image-platform can only be used with --apply"
  fi

  if [[ "$MODE" == "scale" ]]; then
    [[ "$SCALE_REPLICAS" =~ ^[0-9]+$ ]] || die "--scale requires 0 or a positive integer"
  fi

  [[ -n "$IMAGE_PLATFORM" ]] || die "--image-platform cannot be empty"
  [[ -n "${KUBECONFIG_CONTENT:-}" ]] || die "KUBECONFIG_CONTENT env variable is required"

  if [[ ( "$MODE" == "delete" || ( "$MODE" == "apply" && "$SKIP_APPLY" != "true" ) ) && ! -d "$K8S_DIR" ]]; then
    die "Kubernetes manifest directory does not exist: $K8S_DIR"
  fi
}

validate_tools() {
  [[ "$DRY_RUN" == "true" ]] && return

  require_cmd kubectl

  if [[ "$MODE" == "apply" ]]; then
    if [[ "$SKIP_BUILD" != "true" && ! -x ./gradlew ]]; then
      die "Gradle wrapper is not executable: ./gradlew"
    fi

    if [[ "$SKIP_BUILD" != "true" || "$SKIP_PUSH" != "true" ]]; then
      require_cmd docker
    fi
  fi
}

cleanup_kubeconfig() {
  if [[ "$DRY_RUN" == "true" ]]; then
    return
  fi

  if [[ -n "$KUBECONFIG_DIR" && "$KUBECONFIG_DIR" == "$SCRIPT_DIR/.remote_cluster_tmp."* ]]; then
    rm -rf "$KUBECONFIG_DIR"
  elif [[ -n "$KUBECONFIG_FILE" ]]; then
    rm -f "$KUBECONFIG_FILE"
  fi
}

prepare_kubeconfig() {
  log_section "Prepare kubeconfig"

  if [[ "$DRY_RUN" == "true" ]]; then
    KUBECONFIG_DIR="$SCRIPT_DIR/.remote_cluster_tmp.dry_run"
    KUBECONFIG_FILE="$KUBECONFIG_DIR/config"
    export KUBECONFIG="$KUBECONFIG_FILE"
    print_shell_cmd "create protected temporary directory $(printf %q "$KUBECONFIG_DIR")"
    print_shell_cmd "write KUBECONFIG_CONTENT to $(printf %q "$KUBECONFIG_FILE")"
    return
  fi

  KUBECONFIG_DIR="$(mktemp -d "$SCRIPT_DIR/.remote_cluster_tmp.XXXXXX")"
  chmod 700 "$KUBECONFIG_DIR"
  KUBECONFIG_FILE="$KUBECONFIG_DIR/config"
  ( umask 077 && printf '%s\n' "$KUBECONFIG_CONTENT" > "$KUBECONFIG_FILE" )
  chmod 600 "$KUBECONFIG_FILE"
  export KUBECONFIG="$KUBECONFIG_FILE"
}

delete_configs() {
  [[ "$SKIP_APPLY" == "true" ]] && return

  log_section "Clear deployment configs"
  kubectl_cmd delete -f "$K8S_DIR" --ignore-not-found=true
}

ensure_namespace() {
  log_section "Ensure namespace '$NAMESPACE'"
  require_kubeconfig_file

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

  local boot_build_image_args=(
    bootBuildImage
    "--imagePlatform=$IMAGE_PLATFORM"
    "--pullPolicy=$BUILD_IMAGE_PULL_POLICY"
  )

  log_section "Build app image for $IMAGE_PLATFORM"
  if [[ "$GRADLE_CLEAN" == "true" ]]; then
    run ./gradlew clean "${boot_build_image_args[@]}"
  else
    run ./gradlew "${boot_build_image_args[@]}"
  fi

}

push_image() {
  [[ "$SKIP_PUSH" == "true" ]] && return

  log_section "Push image"
  run docker push "$IMAGE"
}

apply_configs() {
  [[ "$SKIP_APPLY" == "true" ]] && return

  log_section "Apply configs"
  kubectl_cmd apply -f "$K8S_DIR"
}

restart_app() {
  [[ "$SKIP_ROLLOUT" == "true" ]] && return

  log_section "Force image pull policy"
  kubectl_cmd patch deployment "$APP_DEPLOYMENT" --namespace="$NAMESPACE" --type=strategic --patch '{"spec":{"template":{"spec":{"containers":[{"name":"sample-app","imagePullPolicy":"Always"}]}}}}'

  log_section "Restart app deployment"
  kubectl_cmd rollout restart "deployment/$APP_DEPLOYMENT" --namespace="$NAMESPACE"
}

scale_app() {
  log_section "Scale app deployment"
  kubectl_cmd scale "deployment/$APP_DEPLOYMENT" "--replicas=$SCALE_REPLICAS" --namespace="$NAMESPACE"
}

main() {
  parse_args "$@"
  validate_config
  validate_tools
  trap cleanup_kubeconfig EXIT

  prepare_kubeconfig

  case "$MODE" in
    apply)
      delete_configs
      ensure_namespace
      build_image
      push_image
      apply_configs
      restart_app
      ;;
    delete)
      delete_configs
      ;;
    scale)
      scale_app
      ;;
    *)
      die "Unknown mode: $MODE"
      ;;
  esac

  log_done
}

main "$@"
