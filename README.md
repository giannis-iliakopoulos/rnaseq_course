# RNA-seq: host response to *Toxoplasma gondii* infection in mice

RNA-seq course project (IBU, University of Bern): differential gene expression analysis.

## Data
Subset of Singhania et al. 2019, *Nat. Commun.* (GEO: GSE119855).
Mouse blood, wild-type vs. Ifnar/Ifngr double knockout, infected vs. uninfected (3-5 replicates per group).
Strand-specific paired-end reads, Illumina HiSeq 4000.

## Project layout
- `scripts/`  numbered scripts, in order of execution (`helpers/` = scripts called by other scripts)
- `config/`   settings used by the scripts
- `resources/` sample list and sample metadata
- `data/raw_data` symlink to the course reads (never copied or edited)
- `data/external_data/` reference genome and annotation (Ensembl)
- `data/processed_data/` intermediate files (e.g. BAM)
- `logs/`     SLURM .out/.err files
- `results/`  outputs, one subfolder per step; everything here is rebuilt by a script
- `reports/`  final report and figures

Data, results and logs are not tracked by git (see `.gitignore`).

## Steps
### 01 Link raw reads (login node)
```bash
bash scripts/01_link_reads.sh
```
Links `data/raw_data` to the course reads (blood, 15 paired-end samples),
copies the sample metadata into `resources/` and writes `resources/samples.txt`.
Data source: GEO GSE119855, downloaded by the course with `fasterq-dump --split-files`.

| Group | Samples | n |
|---|---|---|
| WT infected (Case) | SRR7821949-953 | 5 |
| WT uninfected (Control) | SRR7821968-970 | 3 |
| DKO infected (Case) | SRR7821954-957 | 4 |
| DKO uninfected (Control) | SRR7821971-973 | 3 |

### 02 Read quality control (FastQC, SLURM job array)
```bash
sbatch --array=0 scripts/02_run_fastqc.sh      # test on one sample first
sbatch --array=1-14 scripts/02_run_fastqc.sh   # remaining samples after the test succeeded
```
The test task was checked (`sacct`: COMPLETED 0:0, log shows FastQC v0.12.1,
4 output files) before submitting the remaining tasks.
Running `sbatch scripts/02_run_fastqc.sh` without `--array` processes all 15 samples at once.
Output: `results/02_fastqc/<sample>_<1|2>_fastqc.{html,zip}`,
logs: `logs/fastqc_<jobid>_<task>.{out,err}`.

## Software and versions
| Tool | Version | Container | Resources per task |
|---|---|---|---|
| FastQC | 0.12.1 | `/containers/apptainer/fastqc-0.12.1.sif` | 2 CPU, 2 GB, 1 h (partition pshort_el8) |


### 03 Combined QC report (MultiQC)
```bash
sbatch scripts/03_run_multiqc.sh
```
Combines the 30 FastQC reports (15 samples x 2 mates) into one report:
`results/03_multiqc/multiqc_fastqc_raw.html` (+ `multiqc_fastqc_raw_data/` with the tables).
Used to compare read numbers, per-base quality and adapter content across all samples.
Single job (not an array), log: `logs/multiqc_<jobid>.{out,err}`.

## Software and versions
| Tool | Version | Container | Resources |
|---|---|---|---|
| MultiQC | 1.33 | `/containers/apptainer/multiqc-1.33.sif` | 1 CPU, 4 GB, 30 min (partition pshort_el8) |