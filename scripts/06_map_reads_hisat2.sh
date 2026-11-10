#!/usr/bin/env bash
#SBATCH --job-name=hisat2_map
#SBATCH --partition=pibu_el8
#SBATCH --account=class-467713-ws-2026
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=04:00:00
#SBATCH --array=0-14
#SBATCH --output=logs/%x_%A_%a.out
#SBATCH --error=logs/%x_%A_%a.err
# 06_map_reads_hisat2.sh
# Maps each sample to GRCm39 with HISAT2 (reverse-stranded library: RF) and
# pipes the output directly into samtools sort, writing a coordinate-sorted
# BAM + index. No SAM or unsorted BAM is stored.
# One array task per line of resources/samples.txt (15 samples -> tasks 0-14).
# Resources: 4 threads for HISAT2 and samtools (= --cpus-per-task);
# samtools sort uses up to THREADS x SORT_MEM (4 x 4G = 16G) + HISAT2 (~5-8G)
# -> 32G requested (course guide: samtools sort 4 CPU / 25000 MB).
#   sbatch --array=0 scripts/06_map_reads_hisat2.sh      # test one sample first
#   sbatch --array=1-14 scripts/06_map_reads_hisat2.sh   # then the rest
set -euo pipefail

# ---- settings: change only here ----
WORKDIR=/data/users/$USER/rnaseq_course
READS_DIR=$WORKDIR/data/raw_data
SAMPLE_LIST=$WORKDIR/resources/samples.txt
INDEX_BASENAME=$WORKDIR/data/external_data/hisat2_index/GRCm39
BAM_DIR=$WORKDIR/data/processed_data/bam
SUMMARY_DIR=$WORKDIR/results/06_mapping
CONTAINER=/containers/apptainer/hisat2_samtools_408dfd02f175cd88.sif
THREADS=$SLURM_CPUS_PER_TASK
SORT_MEM=4G
TMP_DIR=${SCRATCH:-/tmp}

# ---- this task's sample ----
mapfile -t SAMPLES < "$SAMPLE_LIST"
SAMPLE=${SAMPLES[$SLURM_ARRAY_TASK_ID]}
BAM=$BAM_DIR/${SAMPLE}.sorted.bam

# ---- commands ----
mkdir -p "$BAM_DIR" "$SUMMARY_DIR"
echo "Task $SLURM_ARRAY_TASK_ID: mapping $SAMPLE"

# Record the tool versions in the log (reproducibility)
apptainer exec --bind /data/ "$CONTAINER" hisat2 --version | head -1
apptainer exec --bind /data/ "$CONTAINER" samtools --version | head -1

# Map -> sort -> index in one pipe. HISAT2's alignment summary (stderr) is saved
# per sample for the report (alignment rate, concordant pairs, multimappers).
apptainer exec --bind /data/ --bind "$TMP_DIR" "$CONTAINER" /bin/bash -c "
  set -o pipefail
  hisat2 -p $THREADS \
    -x $INDEX_BASENAME \
    -1 $READS_DIR/${SAMPLE}_1.fastq.gz \
    -2 $READS_DIR/${SAMPLE}_2.fastq.gz \
    --rna-strandness RF \
    2> $SUMMARY_DIR/${SAMPLE}.hisat2.summary.txt \
  | samtools sort -m $SORT_MEM -@ $THREADS -T $TMP_DIR/${SAMPLE} \
      -o ${BAM}##idx##${BAM}.bai --write-index -
"

# Quick integrity check of the BAM file
apptainer exec --bind /data/ "$CONTAINER" samtools quickcheck "$BAM"
echo "BAM OK: $BAM"

echo "--- HISAT2 alignment summary ---"
cat "$SUMMARY_DIR/${SAMPLE}.hisat2.summary.txt"
echo "Done: $SAMPLE"