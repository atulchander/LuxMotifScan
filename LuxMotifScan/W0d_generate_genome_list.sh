#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# W0d — Generate genome FASTA list for motif scanning
#
# Purpose:
#   - Collect all genome FASTA files (*.fa, *.fna) from a reference directory
#   - Write a newline-delimited list for downstream MEME/FIMO scanning
#
# Output:
#   - reference_genomes.list
#
# Part of: MotifNeighborhoodProfiler (MNP)
###############################################################################

usage() {
  cat <<EOF
Usage:
  $(basename "$0") -i <genome_dir> -o <output_list>

Required:
  -i   Directory containing reference genome FASTA files
  -o   Output file (e.g., reference_genomes.list)

Example:
  $(basename "$0") \\
    -i Exobiology_metaT_reference_genomes \\
    -o reference_genomes.list
EOF
  exit 1
}

GENOME_DIR=""
OUTFILE=""

while getopts ":i:o:" opt; do
  case $opt in
    i) GENOME_DIR="$OPTARG" ;;
    o) OUTFILE="$OPTARG" ;;
    *) usage ;;
  esac
done

[[ -z "$GENOME_DIR" || -z "$OUTFILE" ]] && usage
[[ ! -d "$GENOME_DIR" ]] && { echo "❌ Directory not found: $GENOME_DIR"; exit 1; }

echo "📂 Scanning genome directory: $GENOME_DIR"
echo "📝 Writing genome list to: $OUTFILE"

find "$GENOME_DIR" \
  -type f \( -name "*.fa" -o -name "*.fna" \) \
  | sort > "$OUTFILE"

COUNT=$(wc -l < "$OUTFILE" || echo 0)
echo "✅ Found $COUNT genome FASTA files"
