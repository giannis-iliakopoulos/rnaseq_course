#!/usr/bin/env bash
#SBATCH --job-name=fastqc
#SBATCH --partition=pshort_el8
#SBATCH --account=class-467713-ws-2026
#SBATCH --cpus-per-task=2
#SBATCH --mem=2G
#SBATCH --time=01:00:00
#SBATCH --array=0-14
#SBATCH --output=logs/%x_%A_%a.out
#SBATCH --error=logs/%x_%A_%a.err
# 02_run_fastqc.sh
# Read quality control with FastQC (container), one array task per sample.
# Task i processes line i of resources/samples.txt (15 samples -> tasks 0-14).
# Resources: course guide = 1 CPU / 1000 MB / 1 h per FASTQ file; each task
# runs both mates in parallel, so 2 CPUs / 2 GB.
# Submit from the project folder:  sbatch scripts/02_run_fastqc.sh
set -euo pipefail

# ---- settings: change only here ----
WORKDIR=/data/users/$USER/rnaseq_course
READS_DIR=$WORKDIR/data/raw_data
OUT_DIR=$WORKDIR/results/02_fastqc
SAMPLE_LIST=$WORKDIR/resources/samples.txt
CONTAINER=/containers/apptainer/fastqc-0.12.1.sif
THREADS=$SLURM_CPUS_PER_TASK

# ---- this task's sample ----
mapfile -t SAMPLES < "$SAMPLE_LIST"
SAMPLE=${SAMPLES[$SLURM_ARRAY_TASK_ID]}

# ---- commands ----
mkdir -p "$OUT_DIR"
echo "Task $SLURM_ARRAY_TASK_ID: FastQC on $SAMPLE"

# Record the tool version in the log (reproducibility)
apptainer exec --bind /data/ "$CONTAINER" fastqc --version

apptainer exec --bind /data/ "$CONTAINER" fastqc \
  --threads "$THREADS" \
  --outdir "$OUT_DIR" \
  "$READS_DIR/${SAMPLE}_1.fastq.gz" "$READS_DIR/${SAMPLE}_2.fastq.gz"

echo "Done: $SAMPLE" 