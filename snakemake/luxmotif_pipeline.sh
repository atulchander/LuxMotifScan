#!/bin/bash
# LuxmotifScan pipeline launcher with user-selected base dir

set -euo pipefail

#############################################
# 1. Get base directory from user or $1
#############################################
if [[ $# -ge 1 ]]; then
  BASE_DIR="$1"
else
  read -rp "Enter BASE directory (e.g. ~/misa_lab/Atul/SOFTWARE_OUTPUTS/metatranscriptomics/20251202_edinburg): " BASE_DIR
fi

# expand leading ~ to $HOME
BASE_DIR="${BASE_DIR/#\~/$HOME}"

# create directory if needed
if [[ ! -d "$BASE_DIR" ]]; then
  echo "Directory '$BASE_DIR' does not exist. Creating it..."
  mkdir -p "$BASE_DIR"
fi

# Export so all child scripts can see it
export LUX_BASE_DIR="$BASE_DIR"

echo ">>> Using LUX_BASE_DIR = $LUX_BASE_DIR"

# Make sure we run from the folder where W0* and W1* live
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

#############################################
# 2. Run the pipeline steps
#############################################

echo ">>> Step 1: Preparing project paths"
bash W0a_prepare_project_paths.sh

echo ">>> Step 2: Preparing GFF/FASTA with consistent contigs"
bash W0b_prepare_gff_fasta_consistent_contigs.sh

echo ">>> Step 3: Building Lux motifs"
python3 W0c_build_lux_motifs.py

echo ">>> Step 4: Generating genome list"
bash W0d_generate_genome_list.sh

#############################################
# 5. Submit FIMO PBS job
#############################################

echo ">>> Step 5: Submitting FIMO PBS job"

# Submit the PBS job that runs W1_run_fimo_parallel.sh
# Pass LUX_BASE_DIR into the job environment so W1 can use it
jobid=$(qsub -v LUX_BASE_DIR="$LUX_BASE_DIR" W1_run_fimo_parallel.pbs)
echo "FIMO PBS job submitted with Job ID: $jobid"

#############################################
# 6. Track job progress (qstat + tail -f)
#############################################

echo ">>> Step 6: Tracking job progress for Job ID $jobid"
echo "    (Press Ctrl-C any time to stop watching; the job keeps running.)"

# Strip host suffix from jobid if present (e.g. 6094659.maple -> 6094659)
jobnum="${jobid%%.*}"

# The output file name follows PBS default: <jobname>.o<jobid>
logfile="lux_fimo.o${jobnum}"

echo "    Expected log file: $logfile"

# Background job: periodically show qstat status
(
  while qstat "$jobid" &>/dev/null; do
    state=$(qstat "$jobid" | awk 'NR==3 {print $5}')
    # Typical states: Q=queued, R=running, C=completed
    echo "[$(date '+%H:%M:%S')] Job $jobid state: $state"
    sleep 60
  done
  echo "[$(date '+%H:%M:%S')] Job $jobid left the queue (finished or error)."
) &

# Wait for the log file to appear, then tail it
while [[ ! -f "$logfile" ]]; do
  echo "    Waiting for $logfile to be created (job may still be queued)..."
  sleep 10
done

echo "    Log file found. Showing live output:"
tail -n 20 -f "$logfile"
