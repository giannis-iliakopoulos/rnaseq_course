#!/usr/bin/env bash
#SBATCH --job-name=hisat2_index
#SBATCH --partition=pibu_el8
#SBATCH --account=class-467713-ws-2026
#SBATCH --cpus-per-task=1
#SBATCH --mem=10G
#SBATCH --time=04:00:00
#SBATCH --output=logs/%x_%j.out
#SBATCH --error=logs/%x_%j.err
# 05_build_hisat2_index.sh
# Builds the HISAT2 genome index from the GRCm39 primary assembly (step 04).
# Course guide: 1 CPU, 8000 MB, 3 h; a little extra memory/time as margin.
#   sbatch scripts/05_build_hisat2_index.sh
set -euo pipefail

# ---- settings: change only here ----
WORKDIR=/data/users/$USER/rnaseq_course
GENOME=$WORKDIR/data/external_data/Mus_musculus.GRCm39.dna.primary_assembly.fa
INDEX_DIR=$WORKDIR/data/external_data/hisat2_index
INDEX_BASENAME=$INDEX_DIR/GRCm39
CONTAINER=/containers/apptainer/hisat2_samtools_408dfd02f175cd88.sif
THREADS=$SLURM_CPUS_PER_TASK

# ---- commands ----
mkdir -p "$INDEX_DIR"

# Record the tool version in the log (reproducibility)
apptainer exec --bind /data/ "$CONTAINER" hisat2-build --version | head -1

apptainer exec --bind /data/ "$CONTAINER" hisat2-build \
  -p "$THREADS" \
  "$GENOME" \
  "$INDEX_BASENAME"

ls -lh "$INDEX_DIR"
echo "Done: index basename $INDEX_BASENAME"