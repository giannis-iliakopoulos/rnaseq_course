#!/usr/bin/env bash
# 09_summarise_counts.sh
# Turns the featureCounts summary (step 08) into one row per sample.
# Percentages are relative to the number of input read pairs (from the HISAT2
# summary, step 07), because featureCounts counts multimapping pairs once per
# alignment, which inflates the column totals of its own summary.
# Light work - run on the login node:
#   bash scripts/09_summarise_counts.sh 2>&1 | tee logs/summarise_counts.log
set -euo pipefail

# ---- settings: change only here ----
WORKDIR=/data/users/$USER/rnaseq_course
SUMMARY=$WORKDIR/results/08_featurecounts/gene_counts.txt.summary
PAIRS=$WORKDIR/results/06_mapping/alignment_summary.tsv
BAM_DIR=$WORKDIR/data/processed_data/bam
OUT=$WORKDIR/results/08_featurecounts/assignment_summary.tsv

# ---- commands ----
awk -F'\t' -v bd="$BAM_DIR/" '
  # file 1: input read pairs per sample (step 07 table)
  FNR==NR { if (FNR>1) pairs[$1]=$2; next }
  # file 2: featureCounts summary (categories x samples)
  FNR==1 { for (i=2; i<=NF; i++) {n=$i; sub(bd,"",n); sub(/\.sorted\.bam$/,"",n); name[i]=n}; nf=NF; next }
  { for (i=2; i<=NF; i++) v[$1,i]=$i }
  END {
    print "sample\tinput_pairs\tassigned\tassigned_pct\tambiguity\tambiguity_pct\tno_features_pct"
    for (i=2; i<=nf; i++) {
      s=name[i]; t=pairs[s]; a=v["Assigned",i]; amb=v["Unassigned_Ambiguity",i]; nofeat=v["Unassigned_NoFeatures",i]
      printf "%s\t%d\t%d\t%.2f\t%d\t%.2f\t%.2f\n", s, t, a, 100*a/t, amb, 100*amb/t, 100*nofeat/t
      sa+=amb; sp+=100*amb/t; n++
    }
    printf "MEAN_AMBIGUITY\t-\t-\t-\t%.0f\t%.2f\t-\n", sa/n, sp/n
  }' "$PAIRS" "$SUMMARY" > "$OUT"

column -t "$OUT" 2>/dev/null || cat "$OUT"
echo "Written: $OUT"