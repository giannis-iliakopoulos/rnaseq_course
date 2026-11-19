#!/usr/bin/env bash
#SBATCH --job-name=featurecounts
#SBATCH --partition=pshort_el8
#SBATCH --account=class-467713-ws-2026
#SBATCH --cpus-per-task=4
#SBATCH --mem=4G
#SBATCH --time=01:30:00
#SBATCH --output=logs/%x_%j.out
#SBATCH --error=logs/%x_%j.err
# 08_count_features.sh
# Counts read pairs per gene for all 15 BAM files (step 06) with featureCounts,
# using the Ensembl 116 GTF. Writes the full featureCounts table, its summary
# (assigned / unassigned reads per sample) and a DESeq2-ready count matrix.
# Course guide: 4 CPU, 1000 MB, 2 h; 4 GB requested as margin.
#   sbatch scripts/08_count_features.sh
set -euo pipefail

# ---- settings: change only here ----
WORKDIR=/data/users/$USER/rnaseq_course
BAM_DIR=$WORKDIR/data/processed_data/bam
SAMPLE_LIST=$WORKDIR/resources/samples.txt
GTF=$WORKDIR/data/external_data/Mus_musculus.GRCm39.116.gtf.gz
OUT_DIR=$WORKDIR/results/08_featurecounts
CONTAINER=/containers/apptainer/subread_2.0.6.sif
THREADS=$SLURM_CPUS_PER_TASK

# ---- commands ----
mkdir -p "$OUT_DIR"

# BAM files in the same order as resources/samples.txt
mapfile -t BAMS < <(sed "s|^|$BAM_DIR/|; s|\$|.sorted.bam|" "$SAMPLE_LIST")
echo "Counting ${#BAMS[@]} BAM files"

# Record the tool version in the log (reproducibility)
apptainer exec --bind /data/ "$CONTAINER" featureCounts -v 2>&1 | grep -i featurecounts || true

# -p --countReadPairs : paired-end; count fragments (read pairs), not single reads
# -s 2               : reversely stranded library (matches HISAT2 --rna-strandness RF)
# -t exon -g gene_id  : count reads on exons, summed per Ensembl gene (featureCounts defaults)
# Multimapping and multi-overlapping reads are not counted (defaults).
apptainer exec --bind /data/ "$CONTAINER" featureCounts \
  -T "$THREADS" \
  -p --countReadPairs \
  -s 2 \
  -t exon -g gene_id \
  -a "$GTF" \
  -o "$OUT_DIR/gene_counts.txt" \
  "${BAMS[@]}"

# DESeq2-ready matrix: drop the command line (line 1) and the columns
# Chr, Start, End, Strand, Length; shorten the sample names in the header
tail -n +2 "$OUT_DIR/gene_counts.txt" \
  | cut -f1,7- \
  | sed "1s|$BAM_DIR/||g; 1s|\.sorted\.bam||g" \
  > "$OUT_DIR/gene_counts_matrix.tsv"

echo "Genes in matrix: $(($(wc -l < "$OUT_DIR/gene_counts_matrix.tsv") - 1))"
echo "Done: $OUT_DIR/gene_counts.txt (+ .summary) and gene_counts_matrix.tsv"