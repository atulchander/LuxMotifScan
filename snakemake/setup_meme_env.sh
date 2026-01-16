#!/usr/bin/env bash
set -euo pipefail

ENV_NAME="${1:-luxmotifscan_meme}"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$REPO_DIR/condarc" ]] && export CONDARC="$REPO_DIR/condarc"

CONDA_NO_PLUGINS_FLAG="--no-plugins"

find_conda_sh() {
  # If conda exists, get its base and use conda.sh from there
  if command -v conda >/dev/null 2>&1; then
    local base
    base="$(conda $CONDA_NO_PLUGINS_FLAG info --base 2>/dev/null || true)"
    [[ -n "$base" && -f "$base/etc/profile.d/conda.sh" ]] && { echo "$base/etc/profile.d/conda.sh"; return 0; }
  fi

  # User override
  [[ -n "${CONDA_SH:-}" && -f "$CONDA_SH" ]] && { echo "$CONDA_SH"; return 0; }

  # Common locations
  for p in \
    "$HOME/miniconda3/etc/profile.d/conda.sh" \
    "$HOME/anaconda3/etc/profile.d/conda.sh" \
    "$HOME/Softwares/miniconda3/etc/profile.d/conda.sh" \
    "/opt/conda/etc/profile.d/conda.sh"
  do
    [[ -f "$p" ]] && { echo "$p"; return 0; }
  done

  # Optional module fallback
  if command -v module >/dev/null 2>&1; then
    module --silent load miniconda 2>/dev/null || true
    module --silent load anaconda 2>/dev/null || true
    if command -v conda >/dev/null 2>&1; then
      local base
      base="$(conda $CONDA_NO_PLUGINS_FLAG info --base 2>/dev/null || true)"
      [[ -n "$base" && -f "$base/etc/profile.d/conda.sh" ]] && { echo "$base/etc/profile.d/conda.sh"; return 0; }
    fi
  fi

  return 1
}

CONDA_PROFILE="$(find_conda_sh)" || {
  echo "ERROR: conda not found. Load a conda/miniconda module or set CONDA_SH=/path/to/conda.sh" >&2
  exit 2
}

set +u
source "$CONDA_PROFILE"
set -u

if conda $CONDA_NO_PLUGINS_FLAG env list | awk '{print $1}' | grep -qx "$ENV_NAME"; then
  echo "OK: env exists: $ENV_NAME"
else
  echo "Creating conda env: $ENV_NAME (needs internet)"
  conda $CONDA_NO_PLUGINS_FLAG create -y -n "$ENV_NAME" -c conda-forge -c bioconda meme
fi

conda $CONDA_NO_PLUGINS_FLAG run -n "$ENV_NAME" fimo --version >/dev/null
echo "SUCCESS: fimo is available in env '$ENV_NAME'"
echo "Tip: your PBS jobs will use this env by default, or set: export LUX_MEME_ENV=$ENV_NAME"
