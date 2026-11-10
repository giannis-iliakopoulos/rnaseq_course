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


## QC results and decision
Based on the FastQC and MultiQC reports (`results/03_multiqc/multiqc_fastqc_raw.html`):

- **Reads per sample:** 18.8–34.2 M read pairs (mean 26.4 M, ≈395.7 M in total); mate 1 and mate 2 have identical read counts in all samples.
- **Base quality:** mean Phred score > 30 at all positions in all 30 files (mostly 38–40), slightly lower in the first ~5 bases and the last bases; mates 1 and 2 have nearly identical profiles.
- **Adapters:** < 1% in most files (max ~6% at the last positions); adapter dimers account for ~0.3% of all reads.
- **Expected RNA-seq warnings:** per-base sequence content (random hexamer priming bias) and high duplication (58–92%; blood RNA is dominated by a few highly expressed transcripts). Duplicates were not removed (no UMIs).
- **SRR7821956 (DKO infected)** stands out: two narrow peaks in the GC distribution (45% and 47% GC, ~5% of reads each), the highest duplication (~92%) and the largest fraction of overrepresented sequences (~7–10%). Its overall GC distribution is normal (~50%), so there is no sign of contamination; the peaks come from a few highly repeated sequences.

**Decision (confirmed with the supervisor):** read quality is good and no trimming is needed; the raw reads are used for mapping.
SRR7821956 is kept unchanged and re-checked after mapping (alignment rate, reads assigned to genes, PCA). Trimming or exclusion will only be considered if it performs clearly worse than the other samples.