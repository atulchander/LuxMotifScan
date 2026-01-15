#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage:"
  echo "  $0 prepare-env <base_dir> [run_id]"
  echo "  $0 run        <base_dir> [run_id] [cores]"
  echo "  $0 dry-run    <base_dir> [run_id] [cores]"
  echo
  echo "Notes:"
  echo "  - prepare-env must be run on a node WITH internet (often login node)."
  echo "  - run works on offline compute nodes AFTER prepare-env."
}

[[ $# -ge 2 ]] || { usage; exit 1; }

MODE="$1"
BASE_DIR="${2/#\~/$HOME}"
RUN_ID="${3:-$(date +'%Y-%m-%d_%H-%M-%S')}"
CORES="${4:-12}"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export CONDA_NO_PLUGINS=true
export CONDARC="$REPO_DIR/condarc"

SNAKEFILE="$REPO_DIR/workflow/Snakefile"

common_args=(
  -s "$SNAKEFILE"
  --directory "$REPO_DIR"
  --software-deployment-method conda
  --conda-prefix "$REPO_DIR/.snakemake/conda"
  --latency-wait 60
  --rerun-incomplete
  --printshellcmds
  --show-failed-logs
  --config "base_dir=$BASE_DIR" "run_id=$RUN_ID" "max_jobs=$CORES"
)

case "$MODE" in
  prepare-env)
    rm -rf "$REPO_DIR/.snakemake/conda"
    snakemake "${common_args[@]}" --conda-create-envs-only --cores 1
    echo "OK: rule envs created under $REPO_DIR/.snakemake/conda"
    ;;
  dry-run)
    snakemake -n "${common_args[@]}" --cores "$CORES"
    ;;
  run)
    snakemake "${common_args[@]}" --cores "$CORES"
    ;;
  *)
    usage; exit 2 ;;
esac
