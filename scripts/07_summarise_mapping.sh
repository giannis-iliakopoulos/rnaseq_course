#!/usr/bin/env bash
# 07_summarise_mapping.sh
# Collects the HISAT2 alignment summaries of all samples (step 06) into one
# table for the report: total read pairs, % concordant unique, % concordant
# multimapped, overall alignment rate.
# Light work - run on the login node:  bash scripts/07_summarise_mapping.sh
set -euo pipefail

# ---- settings: change only here ----
WORKDIR=/data/users/$USER/rnaseq_course
SUMMARY_DIR=$WORKDIR/results/06_mapping
OUT=$SUMMARY_DIR/alignment_summary.tsv

# ---- commands ----
echo -e "sample\ttotal_pairs\tconc_1x_pct\tconc_multi_pct\toverall_pct" > "$OUT"
for f in "$SUMMARY_DIR"/*.hisat2.summary.txt; do
  s=$(basename "$f" .hisat2.summary.txt)
  awk -v s="$s" '
    /reads; of these/                     {tot=$1}
    /aligned concordantly exactly 1 time/ {c1=$2}
    /aligned concordantly >1 times/       {cm=$2}
    /overall alignment rate/              {ov=$1}
    END {gsub(/[()%]/,"",c1); gsub(/[()%]/,"",cm); gsub(/%/,"",ov);
         print s"\t"tot"\t"c1"\t"cm"\t"ov}' "$f"
done >> "$OUT"

column -t "$OUT" 2>/dev/null || cat "$OUT"
echo "Written: $OUT"