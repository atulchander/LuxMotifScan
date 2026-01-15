#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# W0d — Generate genome FASTA list for motif scanning
#
# Now:
#   - Uses LUX_BASE_DIR as the base for everything
#   - Reads FASTA files from: $LUX_BASE_DIR/GFFnFASTA
#   - Writes reference_genomes.list to: $LUX_BASE_DIR/reference_genomes.list
###############################################################################

usage() {
  cat <<EOF
Usage:
  $(basename "$0") [-i <genome_dir>] [-o <output_list>]

Defaults (when LUX_BASE_DIR is set):
  genome_dir   = \$LUX_BASE_DIR/GFFnFASTA
  output_list  = \$LUX_BASE_DIR/reference_genomes.list

Examples:
  # In pipeline (LUX_BASE_DIR already set):
  $(basename "$0")

  # Override manually:
  $(basename "$0") -i /path/to/fastas -o /path/to/reference_genomes.list
EOF
  exit 1
}

# ---- Defaults from LUX_BASE_DIR, if present ----
GENOME_DIR="${GENOME_DIR:-}"
OUTFILE="${OUTFILE:-}"

if [[ -n "${LUX_BASE_DIR:-}" ]]; then
  GENOME_DIR="${GENOME_DIR:-"$LUX_BASE_DIR/GFFnFASTA"}"
  OUTFILE="${OUTFILE:-"$LUX_BASE_DIR/reference_genomes.list"}"
fi

# ---- Parse CLI overrides (optional) ----
while getopts ":i:o:h" opt; do
  case "$opt" in
    i) GENOME_DIR="$OPTARG" ;;
    o) OUTFILE="$OPTARG" ;;
    h) usage ;;
    *) usage ;;
  esac
done

# ---- Validate ----
if [[ -z "${GENOME_DIR:-}" || -z "${OUTFILE:-}" ]]; then
  echo "ERROR: GENOME_DIR and OUTFILE must be set (via LUX_BASE_DIR or -i/-o)." >&2
  usage
fi

if [[ ! -d "$GENOME_DIR" ]]; then
  echo "❌ Directory not found: $GENOME_DIR" >&2
  exit 1
fi

echo "📂 Scanning genome directory: $GENOME_DIR"
echo "📝 Writing genome list to: $OUTFILE"

find "$GENOME_DIR" \
  -type f \( -name "*.fa" -o -name "*.fna" \) \
  | sort > "$OUTFILE"

COUNT=$(wc -l < "$OUTFILE" || echo 0)
echo "✅ Found $COUNT genome FASTA files"
