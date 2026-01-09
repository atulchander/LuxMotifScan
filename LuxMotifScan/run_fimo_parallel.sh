#!/bin/bash

#  -- CONFIGURATION --
FASTA_LIST="$HOME/misa_lab/Atul/LUX_christy_exobiology/reference_genomes.list"
MOTIF_FILE="$HOME/misa_lab/Atul/LUX_christy_exobiology/lux_motifs.meme"

# Output root path - new timestamped directory under desired location
timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
OUTDIR_BASE="$HOME/misa_lab/Atul/LUX_christy_exobiology/fimo_output/fimo_run_$timestamp"
LOG_DIR="$OUTDIR_BASE/logs"
SUMMARY_CSV="$OUTDIR_BASE/fimo_summary.csv"
RUN_LOG="$OUTDIR_BASE/fimo_run.log"

mkdir -p "$LOG_DIR"
echo "Genome,Sequences Scanned,Matches Found" > "$SUMMARY_CSV"
echo "===== FIMO Lux-box Scan Run Log =====" > "$RUN_LOG"
echo "Run started at: $(date)" >> "$RUN_LOG"

# Parallel config
MAX_JOBS=60
CURRENT_JOBS=0
i=0

# -- EXECUTION --
while IFS= read -r FASTA; do
  BASENAME=$(basename "$FASTA" .fa)
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
      echo "⚠️ No fimo.tsv output for $BASENAME" | tee -a "$RUN_LOG"
    fi

    SEQ_COUNT=$(grep -c '^>' "$FASTA")
    echo "$BASENAME,$SEQ_COUNT,$MATCHES" >> "$SUMMARY_CSV"
  ) &

  ((CURRENT_JOBS++))
  ((i++))

  # Wait for batch to finish
  if [[ $CURRENT_JOBS -ge $MAX_JOBS ]]; then
    wait
    CURRENT_JOBS=0
  fi

done < "$FASTA_LIST"

# Wait for remaining
wait


# -- WRAP UP --
echo "\nRun completed at: $(date)" >> "$RUN_LOG"
echo "🎯 Output saved in: $OUTDIR_BASE" | tee -a "$RUN_LOG"

