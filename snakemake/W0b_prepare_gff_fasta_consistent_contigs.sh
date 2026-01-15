#!/usr/bin/env bash
set -euo pipefail

# === CONFIGURATION ===
# Require that LUX_BASE_DIR comes from the master script
if [[ -z "${LUX_BASE_DIR:-}" ]]; then
  echo "ERROR: LUX_BASE_DIR is not set. Please run via luxmotif_pipeline_a.sh" >&2
  exit 1
fi

ROOT_DIR="$LUX_BASE_DIR"

# Find the first GFFnFASTA directory under the base dir
GFF_DIR=$(find "$ROOT_DIR" -maxdepth 3 -type d -name "GFFnFASTA" | head -n 1)

if [[ -z "$GFF_DIR" ]]; then
  echo "ERROR: Could not find a 'GFFnFASTA' directory under: $ROOT_DIR" >&2
  exit 1
fi

BASE_DIR="$GFF_DIR"
LOG_FILE="$BASE_DIR/master_processing_run_$(date +%Y%m%d_%H%M%S).log"

echo "🚀 Starting unified GFF + FASTA processing pipeline"
echo "📁 Working directory: $BASE_DIR"
echo "🧾 Log file: $LOG_FILE"
echo "=====================================================" | tee "$LOG_FILE"

# === Collect all GFFs ===
mapfile -t gff_files < <(find "$BASE_DIR" -type f -name "*.gff" ! -name "*_oldGFF_One" ! -name "*.OLDgff" ! -name "*_contigRenamed.gff")

if [[ ${#gff_files[@]} -eq 0 ]]; then
  echo "⚠️ No valid GFF files found in $BASE_DIR"
  exit 0
fi

# =====================================================
# === STEP 1 — Extract FASTA sections if embedded ===
# =====================================================
echo -e "\n🧩 STEP 1: Extract FASTA from GFFs (if embedded)" | tee -a "$LOG_FILE"

for ann_gff in "${gff_files[@]}"; do
  fasta_out="${ann_gff%.gff}.fa"
  if grep -qi "^## *fasta" "$ann_gff"; then
    echo "✅ Extracting FASTA from $(basename "$ann_gff")" | tee -a "$LOG_FILE"
    awk '/^## *[Ff][Aa][Ss][Tt][Aa]/{found=1; next} found' "$ann_gff" > "$fasta_out"
    seq_count=$(grep -c "^>" "$fasta_out" || true)
    echo "   → Extracted $seq_count sequences → $(basename "$fasta_out")" | tee -a "$LOG_FILE"
  fi
done

# =====================================================
# === STEP 2 — Remove FASTA sections from GFFs ===
# =====================================================
echo -e "\n🧹 STEP 2: Removing embedded FASTA from GFFs" | tee -a "$LOG_FILE"

for ann_gff in "${gff_files[@]}"; do
  if grep -q "^##FASTA" "$ann_gff"; then
    echo "🧾 Cleaning $(basename "$ann_gff")" | tee -a "$LOG_FILE"
    awk '/^##FASTA/{exit} {print}' "$ann_gff" > "${ann_gff%.gff}_cleaned.gff"
    mv "${ann_gff%.gff}_cleaned.gff" "$ann_gff"
    echo "   ✅ Cleaned FASTA section from $(basename "$ann_gff")" | tee -a "$LOG_FILE"
  fi
done

# =====================================================
# === STEP 3 — Synchronize FASTA + GFF filenames ===
# =====================================================
echo -e "\n🔄 STEP 3: Ensuring FASTA filenames match GFFs" | tee -a "$LOG_FILE"

for gff_file in "${gff_files[@]}"; do
  base_name="$(basename "$gff_file" .gff)"
  fa_guess="$BASE_DIR/${base_name}.fa"

  if [[ ! -f "$fa_guess" ]]; then
    alt_fa=$(find "$BASE_DIR" -type f -regex ".*${base_name}.*\.fa" | head -n1 || true)
    [[ -n "$alt_fa" ]] && mv "$alt_fa" "$fa_guess"
  fi

  if [[ -f "$fa_guess" ]]; then
    echo "✅ $(basename "$gff_file") ↔ $(basename "$fa_guess")" | tee -a "$LOG_FILE"
  else
    echo "⚠️ No matching FASTA for $base_name.gff — skipping sync" | tee -a "$LOG_FILE"
  fi
done

# =====================================================
# === STEP 4 — Contig name synchronization ===
# =====================================================
echo -e "\n🧬 STEP 4: Renaming contigs (contig_1, contig_2, ...) in both GFF + FASTA" | tee -a "$LOG_FILE"

mapfile -t genomes < <(find "$BASE_DIR" -type f -name "*.gff" -exec basename {} .gff \; | sort | uniq)

for genome in "${genomes[@]}"; do
  gff_file="$BASE_DIR/${genome}.gff"
  fa_file="$BASE_DIR/${genome}.fa"

  [[ ! -f "$gff_file" || ! -f "$fa_file" ]] && continue
  [[ "$gff_file" == *"_contigRenamed.gff" ]] && continue

  echo -e "\n🔎 Processing genome: $genome" | tee -a "$LOG_FILE"

  map_out="$BASE_DIR/${genome}_contig_map.tsv"
  gff_out="$BASE_DIR/${genome}_contigRenamed.gff"
  fa_out="$BASE_DIR/${genome}_contigRenamed.fa"

  mapfile -t contigs < <(grep "^>" "$fa_file" | sed 's/^>//; s/\r//')

  if [[ ${#contigs[@]} -eq 0 ]]; then
    echo "⚠️ No FASTA headers found — skipping $genome" | tee -a "$LOG_FILE"
    continue
  fi

  echo "   🔢 Found ${#contigs[@]} contigs" | tee -a "$LOG_FILE"
  rm -f "$map_out"
  i=1
  for old in "${contigs[@]}"; do
    echo -e "${old}\tcontig_${i}" >> "$map_out"
    ((i++))
  done

  # Rename in FASTA
  awk -v map="$map_out" '
    BEGIN{while((getline<map)>0)a[$1]=$2}
    /^>/{sub(/^>/,""); print ">"(a[$1]?a[$1]:$1); next}
    {print}' "$fa_file" > "$fa_out"

  # ✅ Fixed GFF renaming (handles tab- and space-delimited lines)
  awk -v map="$map_out" '
    BEGIN{
      FS=OFS="\t"
      while((getline<map)>0){a[$1]=$2}
    }
    /^##sequence-region/ {
      n=split($0,f," ")
      for (old in a) if (f[2]==old) f[2]=a[old]
      out=f[1]; for(i=2;i<=n;i++) out=out" "f[i]; print out; next
    }
    /^#/ {print; next}
    ($1 in a){$1=a[$1]}
    {print}
  ' "$gff_file" > "$gff_out"

  if [[ -s "$fa_out" && -s "$gff_out" ]]; then
    echo "✅ Synced contigs for $genome" | tee -a "$LOG_FILE"
    mv "$gff_file" "$BASE_DIR/${genome}.OLDgff"
    mv "$fa_file" "$BASE_DIR/${genome}.OLDfa"
    echo "   🌀 Archived originals → .OLDgff / .OLDfa" | tee -a "$LOG_FILE"
  else
    echo "❌ Error generating renamed files for $genome" | tee -a "$LOG_FILE"
    rm -f "$fa_out" "$gff_out"
  fi
done


# =====================================================
# === STEP 5 — Final cleanup: rename updated files ===
# =====================================================
echo -e "\n🧹 STEP 5: Final cleanup — keep only latest renamed files" | tee -a "$LOG_FILE"

# 1️⃣ Convert any remaining old-style files (.fa / .gff) to .OLDfa / .OLDgff
find "$BASE_DIR" -maxdepth 1 -type f -name "*.fa" ! -name "*contigRenamed.fa" | while read -r f; do
  mv "$f" "${f%.fa}.OLDfa"
  echo "   🪶 Archived old FASTA: $(basename "$f") → $(basename "${f%.fa}.OLDfa")" | tee -a "$LOG_FILE"
done

find "$BASE_DIR" -maxdepth 1 -type f -name "*.gff" ! -name "*contigRenamed.gff" | while read -r f; do
  mv "$f" "${f%.gff}.OLDgff"
  echo "   🪶 Archived old GFF: $(basename "$f") → $(basename "${f%.gff}.OLDgff")" | tee -a "$LOG_FILE"
done

# 2️⃣ Rename newest contigRenamed.* to clean simple names
find "$BASE_DIR" -maxdepth 1 -type f -name "*_contigRenamed.fa" | while read -r f; do
  new="${f/_contigRenamed/}"
  mv "$f" "$new"
  echo "   ✨ Updated FASTA name: $(basename "$new")" | tee -a "$LOG_FILE"
done

find "$BASE_DIR" -maxdepth 1 -type f -name "*_contigRenamed.gff" | while read -r f; do
  new="${f/_contigRenamed/}"
  mv "$f" "$new"
  echo "   ✨ Updated GFF name: $(basename "$new")" | tee -a "$LOG_FILE"
done

echo -e "\n🎯 All genomes processed successfully!"
echo "📜 Log saved to: $LOG_FILE"

