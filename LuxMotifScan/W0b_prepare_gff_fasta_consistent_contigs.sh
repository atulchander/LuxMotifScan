#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# W1b — GFF/FASTA harmonization and contig renaming
#
# Purpose:
#   - Extract embedded FASTA from GFF (if present)
#   - Remove embedded FASTA from GFF
#   - Ensure GFF and FASTA filenames match
#   - Synchronize contig names across GFF and FASTA
#
# Output:
#   - Cleaned *.gff and *.fa files with consistent contig IDs
#   - Original files archived as *.OLDgff / *.OLDfa
#
# Part of: MotifNeighborhoodFramework (MNF)
###############################################################################

usage() {
  cat <<EOF
Usage:
  $(basename "$0") -i <GFF_FASTA_DIR> [-l LOG_FILE]

Required:
  -i   Directory containing paired .gff and .fa files

Optional:
  -l   Log file path (default: <input_dir>/gff_fasta_prepare_<timestamp>.log)

Example:
  $(basename "$0") -i genomes/GFFnFASTA
EOF
  exit 1
}

# -------------------------
# Parse arguments
# -------------------------
INPUT_DIR=""
LOG_FILE=""

while getopts ":i:l:" opt; do
  case $opt in
    i) INPUT_DIR="$OPTARG" ;;
    l) LOG_FILE="$OPTARG" ;;
    *) usage ;;
  esac
done

[[ -z "$INPUT_DIR" ]] && usage
[[ ! -d "$INPUT_DIR" ]] && { echo "❌ Input directory not found: $INPUT_DIR"; exit 1; }

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_FILE:-$INPUT_DIR/gff_fasta_prepare_${TIMESTAMP}.log}"

echo "🚀 Starting GFF + FASTA harmonization"
echo "📁 Input directory: $INPUT_DIR"
echo "📜 Log file: $LOG_FILE"
echo "=====================================================" | tee "$LOG_FILE"

# -------------------------
# Collect GFF files
# -------------------------
mapfile -t gff_files < <(
  find "$INPUT_DIR" -type f -name "*.gff" \
    ! -name "*.OLDgff" \
    ! -name "*_contigRenamed.gff"
)

if [[ ${#gff_files[@]} -eq 0 ]]; then
  echo "⚠️ No valid GFF files found" | tee -a "$LOG_FILE"
  exit 0
fi

# =====================================================
# STEP 1 — Extract embedded FASTA
# =====================================================
echo -e "\n▶ STEP 1: Extract embedded FASTA (if present)" | tee -a "$LOG_FILE"

for gff in "${gff_files[@]}"; do
  fasta_out="${gff%.gff}.fa"
  if grep -qi "^## *fasta" "$gff"; then
    echo "  Extracting FASTA from $(basename "$gff")" | tee -a "$LOG_FILE"
    awk '/^## *[Ff][Aa][Ss][Tt][Aa]/{found=1; next} found' "$gff" > "$fasta_out"
    echo "    → $(grep -c "^>" "$fasta_out") sequences written" | tee -a "$LOG_FILE"
  fi
done

# =====================================================
# STEP 2 — Remove embedded FASTA from GFF
# =====================================================
echo -e "\n▶ STEP 2: Removing embedded FASTA from GFFs" | tee -a "$LOG_FILE"

for gff in "${gff_files[@]}"; do
  if grep -q "^##FASTA" "$gff"; then
    awk '/^##FASTA/{exit} {print}' "$gff" > "${gff%.gff}.tmp"
    mv "${gff%.gff}.tmp" "$gff"
    echo "  Cleaned FASTA from $(basename "$gff")" | tee -a "$LOG_FILE"
  fi
done

# =====================================================
# STEP 3 — Ensure FASTA ↔ GFF filename matching
# =====================================================
echo -e "\n▶ STEP 3: Matching FASTA and GFF filenames" | tee -a "$LOG_FILE"

for gff in "${gff_files[@]}"; do
  base=$(basename "$gff" .gff)
  fa="$INPUT_DIR/${base}.fa"

  if [[ ! -f "$fa" ]]; then
    alt=$(find "$INPUT_DIR" -maxdepth 1 -name "*${base}*.fa" | head -n1 || true)
    [[ -n "$alt" ]] && mv "$alt" "$fa"
  fi

  [[ -f "$fa" ]] \
    && echo "  ✔ $base.gff ↔ $base.fa" | tee -a "$LOG_FILE" \
    || echo "  ⚠ Missing FASTA for $base.gff" | tee -a "$LOG_FILE"
done

# =====================================================
# STEP 4 — Contig renaming (contig_1, contig_2, ...)
# =====================================================
echo -e "\n▶ STEP 4: Synchronizing contig IDs" | tee -a "$LOG_FILE"

mapfile -t genomes < <(
  find "$INPUT_DIR" -type f -name "*.gff" -exec basename {} .gff \; | sort -u
)

for genome in "${genomes[@]}"; do
  gff="$INPUT_DIR/${genome}.gff"
  fa="$INPUT_DIR/${genome}.fa"
  [[ ! -f "$gff" || ! -f "$fa" ]] && continue

  echo "  Processing genome: $genome" | tee -a "$LOG_FILE"

  map="$INPUT_DIR/${genome}_contig_map.tsv"
  gff_new="$INPUT_DIR/${genome}_contigRenamed.gff"
  fa_new="$INPUT_DIR/${genome}_contigRenamed.fa"

  mapfile -t contigs < <(grep "^>" "$fa" | sed 's/^>//')
  [[ ${#contigs[@]} -eq 0 ]] && continue

  rm -f "$map"
  i=1
  for c in "${contigs[@]}"; do
    echo -e "$c\tcontig_$i" >> "$map"
    ((i++))
  done

  # FASTA rename
  awk -v m="$map" '
    BEGIN{while((getline<m)>0)a[$1]=$2}
    /^>/{sub(/^>/,""); print ">"(a[$1]?a[$1]:$1); next} {print}
  ' "$fa" > "$fa_new"

  # GFF rename
  awk -v m="$map" '
    BEGIN{FS=OFS="\t"; while((getline<m)>0)a[$1]=$2}
    /^##sequence-region/{
      split($0,f," "); if(f[2] in a) f[2]=a[f[2]];
      printf "%s",f[1]; for(i=2;i<=NF;i++) printf " %s",f[i]; print ""; next
    }
    /^#/ {print; next}
    ($1 in a){$1=a[$1]} {print}
  ' "$gff" > "$gff_new"

  mv "$gff" "$INPUT_DIR/${genome}.OLDgff"
  mv "$fa" "$INPUT_DIR/${genome}.OLDfa"
  mv "$gff_new" "$gff"
  mv "$fa_new" "$fa"

  echo "    ✔ Contigs synchronized" | tee -a "$LOG_FILE"
done

echo -e "\n🎯 GFF + FASTA preparation complete"
echo "📜 Log saved to: $LOG_FILE"
