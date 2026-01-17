#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Defaults (can be overridden by env vars)
MEME_ENV="${LUX_MEME_ENV:-luxmotifscan_meme}"
DRIVER_ENV="${LUX_DRIVER_ENV:-lux_smk24}"
BASE_DIR_DEFAULT="${LUX_BASE_DIR_DEFAULT:-$REPO_ROOT}"
RUN_ID_DEFAULT="${LUX_RUN_ID_DEFAULT:-run1}"

# Use repo channel policy (prevents repo.anaconda.com issues)
[[ -f "$SCRIPT_DIR/condarc" ]] && export CONDARC="$SCRIPT_DIR/condarc"

# Avoid conda plugin chaos on some clusters
export CONDA_NO_PLUGINS=true
CONDA_FLAGS=(--no-plugins)

usage() {
  cat <<EOF
setup_hpc.sh - LuxMotifScan HPC bootstrap

Usage:
  $0                     # (default) setup MEME env only
  $0 meme                # create/check MEME/FIMO env (${MEME_ENV})
  $0 driver              # create/check Snakemake driver env (${DRIVER_ENV})
  $0 all [BASE] [RUNID]  # meme + driver + (optional) rule-envs precreate
  $0 rule-envs [BASE] [RUNID]  # precreate snakemake rule envs into snakemake/.snakemake/conda

Notes:
  - Anything that creates environments needs internet (or a local conda mirror).
  - After envs exist, PBS compute nodes can run offline.

Defaults:
  BASE_DIR default: ${BASE_DIR_DEFAULT}
  RUN_ID   default: ${RUN_ID_DEFAULT}

EOF
}

find_conda() {
  # 1) conda on PATH
  if command -v conda >/dev/null 2>&1; then
    echo "$(command -v conda)"
    return 0
  fi

  # 2) common locations
  for p in \
    "$HOME/miniconda3/bin/conda" \
    "$HOME/anaconda3/bin/conda" \
    "$HOME/Softwares/miniconda3/bin/conda" \
    "/opt/conda/bin/conda"
  do
    [[ -x "$p" ]] && { echo "$p"; return 0; }
  done

  # 3) try modules
  if command -v module >/dev/null 2>&1; then
    module --silent load miniconda 2>/dev/null || true
    module --silent load anaconda 2>/dev/null || true
    command -v conda >/dev/null 2>&1 && { echo "$(command -v conda)"; return 0; }
  fi

  return 1
}

ensure_conda() {
  CONDA_EXE="$(find_conda || true)"
  if [[ -z "${CONDA_EXE:-}" ]]; then
    echo "ERROR: conda not found."
    echo "Fix: load a conda/miniconda module OR install miniconda/miniforge in your home."
    echo "Then re-run: $0 meme"
    exit 2
  fi
  echo "$CONDA_EXE"
}

env_exists() {
  local conda_exe="$1"
  local env_name="$2"
  "$conda_exe" "${CONDA_FLAGS[@]}" env list | awk '{print $1}' | grep -qx "$env_name"
}

setup_meme() {
  local conda_exe="$1"
  if env_exists "$conda_exe" "$MEME_ENV"; then
    echo "OK: MEME env exists: $MEME_ENV"
  else
    echo "Creating MEME/FIMO env: $MEME_ENV (needs internet)"
    "$conda_exe" "${CONDA_FLAGS[@]}" create -y -n "$MEME_ENV" -c conda-forge -c bioconda meme
  fi

  echo "Verifying fimo..."
  "$conda_exe" "${CONDA_FLAGS[@]}" run -n "$MEME_ENV" fimo --version >/dev/null
  echo "SUCCESS: fimo is available via conda env '$MEME_ENV'"
  echo "Tip: PBS will use this by default, or set: export LUX_MEME_ENV=$MEME_ENV"
}

setup_driver() {
  local conda_exe="$1"
  if env_exists "$conda_exe" "$DRIVER_ENV"; then
    echo "OK: driver env exists: $DRIVER_ENV"
  else
    echo "Creating Snakemake driver env: $DRIVER_ENV (needs internet)"
    "$conda_exe" "${CONDA_FLAGS[@]}" create -y -n "$DRIVER_ENV" -c conda-forge -c bioconda \
      "python=3.12" "snakemake=9.14.6" "conda>=24.7.1,<25"
  fi
  "$conda_exe" "${CONDA_FLAGS[@]}" run -n "$DRIVER_ENV" snakemake --version >/dev/null
  echo "SUCCESS: snakemake is available via driver env '$DRIVER_ENV'"
}

setup_rule_envs() {
  local conda_exe="$1"
  local base="${2:-$BASE_DIR_DEFAULT}"
  local runid="${3:-$RUN_ID_DEFAULT}"

  echo "Pre-creating Snakemake rule envs into: $SCRIPT_DIR/.snakemake/conda"
  mkdir -p "$SCRIPT_DIR/.snakemake"

  "$conda_exe" "${CONDA_FLAGS[@]}" run -n "$DRIVER_ENV" snakemake \
    -s "$SCRIPT_DIR/workflow/Snakefile" \
    --directory "$SCRIPT_DIR" \
    --software-deployment-method conda \
    --conda-prefix "$SCRIPT_DIR/.snakemake/conda" \
    --conda-create-envs-only \
    --cores 1 \
    --config "base_dir=$base" "run_id=$runid" "max_jobs=1"

  echo "OK: rule envs created under $SCRIPT_DIR/.snakemake/conda"
}

main() {
  local cmd="${1:-meme}"
  local conda_exe
  conda_exe="$(ensure_conda)"

  case "$cmd" in
    -h|--help|help) usage ;;
    meme) setup_meme "$conda_exe" ;;
    driver) setup_driver "$conda_exe" ;;
    rule-envs)
      setup_driver "$conda_exe"
      setup_rule_envs "$conda_exe" "${2:-$BASE_DIR_DEFAULT}" "${3:-$RUN_ID_DEFAULT}"
      ;;
    all)
      setup_meme "$conda_exe"
      setup_driver "$conda_exe"
      setup_rule_envs "$conda_exe" "${2:-$BASE_DIR_DEFAULT}" "${3:-$RUN_ID_DEFAULT}"
      ;;
    *)
      usage; exit 2 ;;
  esac
}

main "$@"

