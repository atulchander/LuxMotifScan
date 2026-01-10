#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# W1 — Parallel genome-wide motif scanning using MEME-FIMO
#
# Purpose:
#   - Run FIMO against a list of genome FASTA files
#   - Execute scans in parallel on HPC systems
#   - Collect per-genome hit counts and summary statistics
#
# Inputs:
#   - Genome FASTA list file
#   - MEME-formatted motif file
#
# Outputs:
#   - Timestamped fimo_run_<timestamp>/ directory
#   - Per-genome FIMO outputs
#   - fimo_summary.csv
#   - Execution log
#
# Part of: MotifNeighborhoodFramework (MNF)
###############################################################################

usage() {
  cat <<EOF
Usage:
  $(basename "$0") -g <genome_list.txt> -m <motifs.meme> -o <output_dir> [-j JOBS]

Required:
  -g   File containing list of genome FASTA paths (one per line)
  -m   MEME motif file
  -o   Output directory (timestamped subfolder will be created)

Optional:
  -j   Max parallel jobs (default: 60)

Example:
  $(basename "$0") \\
    -g reference_genomes.list \\
    -m lux_motifs.meme \\
    -o fimo_output \\
    -j 48
EOF
  exit 1
}

# -------------------------
# Parse arguments
# -------------------------
GENOME_LIST=""
MOTIF_FILE=""
OUTROOT=""
MAX_JOBS=60

while getopts ":g:m:o:j:" opt; do
  case $opt in
    g) GENOME_LIST="$OPTARG" ;;
    m) MOTIF_FILE="$OPTARG" ;;
    o) OUTROOT="$OPTARG" ;;
    j) MAX_JOBS="$OPTARG" ;;
    *) usage ;;
  esac
done

[[ -z "$GENOME_LIST" || -z "$MOTIF_FILE" || -z "$OUTROOT" ]] && usage
[[ ! -f "$GENOME_LIST" ]] && { echo "❌ Genome list not found: $GENOME_LIST"; exit 1; }
[[ ! -f "$MOTIF_FILE" ]] && { echo "❌ Motif file not found: $MOTIF_FILE"; exit 1; }

command -v fimo >/dev/null 2>&1 || { echo "❌ fimo not found in PATH"; exit 1; }

# -------------------------
# Setup output structure
# -------------------------
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
OUTDIR_BASE="$OUTROOT/fimo_run_${TIMESTAMP}"
LOG_DIR="$OUTDIR_BASE/logs"
SUMMARY_CSV="$OUTDIR_BASE/fimo_summary.csv"
RUN_LOG="$OUTDIR_BASE/fimo_run.log"

mkdir -p "$LOG_DIR"

echo "Genome,Sequences_Scanned,Matches_Found" > "$SUMMARY_CSV"
{
  echo "===== FIMO Motif Scan Run ====="
  echo "Started at: $(date)"
  echo "Genome list: $GENOME_LIST"
  echo "Motif file:  $MOTIF_FILE"
  echo "Max jobs:    $MAX_JOBS"
} > "$RUN_LOG"

# -------------------------
# Parallel execution
# -------------------------
CURRENT_JOBS=0
i=0

while IFS= read -r FASTA; do
  [[ -z "$FASTA" ]] && continue
  [[ ! -f "$FASTA" ]] && { echo "⚠️ FASTA not found: $FASTA" | tee -a "$RUN_LOG"; continue; }

  BASENAME=$(basename "$FASTA")
  BASENAME="${BASENAME%%.*}"

  OUTDIR="$OUTDIR_BASE/$BASENAME"
  LOGFILE="$LOG_DIR/$BASENAME.fimo.log"

  echo -e "\n🔍 [$i] Running FIMO on: $BASENAME" | tee -a "$RUN_LOG"
  mkdir -p "$OUTDIR"

  (
    fimo --oc "$OUTDIR" "$MOTIF_FILE" "$FASTA" > "$LOGFILE" 2>&1

    if [[ -s "$OUTDIR/fimo.tsv" ]]; then
      MATCHES=$(grep -vc '^#' "$OUTDIR/fimo.tsv")
    else
      MATCHES=0
    fi

    SEQ_COUNT=$(grep -c '^>' "$FASTA" || true)
    echo "$BASENAME,$SEQ_COUNT,$MATCHES" >> "$SUMMARY_CSV"
    echo "  ✔ $BASENAME → $MATCHES hits" >> "$RUN_LOG"
  ) &

  ((CURRENT_JOBS++))
  ((i++))

  if [[ $CURRENT_JOBS -ge $MAX_JOBS ]]; then
    wait
    CURRENT_JOBS=0
  fi

done < "$GENOME_LIST"

wait

# -------------------------
# Wrap-up
# -------------------------
{
  echo ""
  echo "Completed at: $(date)"
  echo "Output directory: $OUTDIR_BASE"
} >> "$RUN_LOG"

echo "🎯 FIMO run completed"
echo "📂 Results: $OUTDIR_BASE"
