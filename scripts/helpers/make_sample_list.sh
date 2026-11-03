#!/usr/bin/env bash
# make_sample_list.sh  (helper, called by 01_link_reads.sh)
# Writes one sample ID per line, taken from the mate-1 FASTQ names,
# and warns if a sample has no mate-2 file.
# Usage: bash make_sample_list.sh <reads_dir> <output_file>
set -euo pipefail

READS_DIR=$1
OUT_FILE=$2

# SRRxxxx_1.fastq.gz -> SRRxxxx
ls "$READS_DIR"/*_1.fastq.gz | xargs -n1 basename | sed 's/_1.fastq.gz$//' > "$OUT_FILE"

# Paired-end check: every sample needs a _2 file
while read -r s; do
  [ -e "$READS_DIR/${s}_2.fastq.gz" ] || echo "WARNING: $s has no mate-2 file"
done < "$OUT_FILE"