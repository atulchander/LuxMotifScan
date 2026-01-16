#!/bin/bash
set -euo pipefail

if [[ -z "${LUX_BASE_DIR:-}" ]]; then
  echo "ERROR: LUX_BASE_DIR is not set. Run via luxmotif_pipeline_c.sh or pass with qsub -v LUX_BASE_DIR=..." >&2
  exit 1
fi

BASE_DIR="$LUX_BASE_DIR"
BASE_DIR="${BASE_DIR/#\~/$HOME}"

FASTA_LIST="$BASE_DIR/reference_genomes.list"
MOTIF_FILE="$BASE_DIR/lux_motifs.meme"

# Fallback: search within BASE_DIR only (fast + safe)
if [[ ! -s "$FASTA_LIST" ]]; then
  FASTA_LIST=$(find "$BASE_DIR" -maxdepth 3 -type f -name "reference_genomes.list" -printf '%T@ %p\n' 2>/dev/null \
    | sort -nr | awk 'NR==1{print $2}')
fi

if [[ ! -s "$MOTIF_FILE" ]]; then
  MOTIF_FILE=$(find "$BASE_DIR" -maxdepth 3 -type f -name "lux_motifs.meme" -printf '%T@ %p\n' 2>/dev/null \
    | sort -nr | awk 'NR==1{print $2}')
fi

# --- sanity checks ---
echo "BASE_DIR     = $BASE_DIR"
echo "FASTA_LIST   = ${FASTA_LIST:-<not found>}"
echo "MOTIF_FILE   = ${MOTIF_FILE:-<not found>}"

[[ -n "${FASTA_LIST:-}" && -s "$FASTA_LIST" ]] || { echo "ERROR: FASTA list missing/empty under: $BASE_DIR" >&2; exit 2; }
[[ -n "${MOTIF_FILE:-}" && -s "$MOTIF_FILE" ]] || { echo "ERROR: Motif file missing/empty under: $BASE_DIR" >&2; exit 2; }
command -v fimo >/dev/null 2>&1 || { echo "ERROR: fimo not in PATH (module not loaded?)" >&2; exit 2; }

run_id="${RUN_ID:-$(date +'%Y-%m-%d_%H-%M-%S')}"
OUTDIR_BASE="$BASE_DIR/fimo_output/fimo_run_${run_id}"
LOG_DIR="$OUTDIR_BASE/logs"
SUMMARY_CSV="$OUTDIR_BASE/fimo_summary.csv"
RUN_LOG="$OUTDIR_BASE/fimo_run.log"

mkdir -p "$LOG_DIR"
echo "Genome,Sequences Scanned,Matches Found" > "$SUMMARY_CSV"
{
  echo "===== FIMO Lux-box Scan Run Log ====="
  echo "Run started at: $(date)"
  echo "Motif file: $MOTIF_FILE"
  echo "Fasta list: $FASTA_LIST"
} > "$RUN_LOG"

MAX_JOBS="${MAX_JOBS:-${PBS_NCPUS:-12}}"
CURRENT_JOBS=0
i=0

while IFS= read -r FASTA; do
  # strip CR if file was edited on Windows
  FASTA="${FASTA//$'\r'/}"
  [[ -z "$FASTA" ]] && continue

  BASENAME=$(basename "$FASTA")
  OUTDIR="$OUTDIR_BASE/$BASENAME"
  LOGFILE="$LOG_DIR/$BASENAME.fimo.log"

  echo -e "\n🔍 [$i] Running FIMO on: $BASENAME" | tee -a "$RUN_LOG"
  mkdir -p "$OUTDIR"

  (
    fimo --oc "$OUTDIR" "$MOTIF_FILE" "$FASTA" > "$LOGFILE" 2>&1

    if [[ -f "$OUTDIR/fimo.tsv" ]]; then
      MATCHES=$(grep -v '^#' "$OUTDIR/fimo.tsv" | wc -l)
      echo "✅ Found $MATCHES matches in $BASENAME" | tee -a "$RUN_LOG"
    else
      MATCHES=0
      echo "⚠️ No fimo.tsv output for $BASENAME (see $LOGFILE)" | tee -a "$RUN_LOG"
    fi

    SEQ_COUNT=$(grep -c '^>' "$FASTA" || true)
    echo "$BASENAME,$SEQ_COUNT,$MATCHES" >> "$SUMMARY_CSV"
  ) &

  # SAFE increments with set -e:
  CURRENT_JOBS=$((CURRENT_JOBS + 1))
  i=$((i + 1))

  if [[ $CURRENT_JOBS -ge $MAX_JOBS ]]; then
    wait
    CURRENT_JOBS=0
  fi

done < "$FASTA_LIST"

wait

echo "Run completed at: $(date)" >> "$RUN_LOG"
echo "🎯 Output saved in: $OUTDIR_BASE" | tee -a "$RUN_LOG"

