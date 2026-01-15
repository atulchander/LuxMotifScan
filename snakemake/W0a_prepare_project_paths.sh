#!/bin/bash
set -euo pipefail

# === Configuration ===
# LUX_BASE_DIR is set by luxmotif_pipeline_a.sh
BASE_DIR="${LUX_BASE_DIR:?LUX_BASE_DIR is not set. Run via luxmotif_pipeline_a.sh.}"
TARGET_DIR="$BASE_DIR/GFFnFASTA"

mkdir -p "$TARGET_DIR"
cd "$BASE_DIR" || exit

echo "📦 Unzipping all .zip files..."
for zip in *.zip; do
    [ -f "$zip" ] || continue
    unzip -o "$zip" -d "${zip%.zip}"
done

echo "📁 Collecting files from subdirectories..."
# Loop over each subfolder (e.g., BL16A, GV4, K61, Y88A)
for dir in */; do
    # Skip special folders
    [[ "$dir" == "GFFnFASTA/" ]] && continue
    [[ "$dir" == "__MACOSX/" ]] && continue

    echo "🔍 Entering folder: $dir"

    # Search recursively for .fa, .fna, .gff, .gtf
    while IFS= read -r -d '' f; do
        fname=$(basename "$f")
        [[ "$fname" == "._"* ]] && continue  # skip Mac junk
        dest="$TARGET_DIR/$fname"

        echo "📄 Moving: $f → $dest"
        mv -f "$f" "$dest"
    done < <(find "$dir" -type f \( -iname "*.fa" -o -iname "*.fna" -o -iname "*.gff" -o -iname "*.gtf" \) -print0)
done

echo "🧹 Cleaning up MacOSX metadata and empty dirs..."
find "$BASE_DIR" -type d -name "__MACOSX" -exec rm -rf {} +
find "$BASE_DIR" -type d -empty -delete

echo "✅ All files organized in:"
echo "   → $TARGET_DIR"
echo "   (FASTA + GFF/ GTF files together)"

