#!/bin/bash
#SBATCH -J luxmotifscan
#SBATCH -c 12
#SBATCH --mem=32G
#SBATCH -t 04:00:00
#SBATCH -p compute
#SBATCH -o luxmotifscan.%j.out
#SBATCH -e luxmotifscan.%j.err

set -euo pipefail

# EDIT THESE:
REPO_DIR="/path/to/luxmotifscan"
BASE_DIR="/path/to/base_dir"
RUN_ID="run1"

CORES="${SLURM_CPUS_PER_TASK:-12}"

cd "$REPO_DIR"

# Activate your driver env (created from workflow/envs/driver.yml)
source "$HOME/miniconda3/etc/profile.d/conda.sh"
conda activate lux_smk24

./run.sh run "$BASE_DIR" "$RUN_ID" "$CORES"
