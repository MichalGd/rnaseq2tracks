# Quick start

## 1. Create a project

```bash
PROJECT=/home/user/Analysis/my_rnaseq_project
mkdir -p "$PROJECT/config"
```

Copy `config_template.conf` and one SE/PE samplesheet template into that
directory. Edit the copies, not the installed release.

## 2. Check the two input files

- `config.conf` contains `SAMPLESHEET="samplesheet.csv"` and all reference paths.
- Each samplesheet row identifies one technical library/lane and one unique FASTQ
  pair (PE) or FASTQ (SE).
- Rows representing the same biological specimen use the same `sample_id`.
- Every unique pair of conditions is compared automatically; no separate
  contrasts file is needed.

## 3. Launch

```bash
rnaseq2tracks --config "$PROJECT/config/config.conf"
```

No `conda activate`, environment path or positional samplesheet argument is
needed. To detach from SSH:

```bash
nohup rnaseq2tracks --config "$PROJECT/config/config.conf" \
  > "$PROJECT/rnaseq2tracks.launch.log" 2>&1 &
echo $! > "$PROJECT/rnaseq2tracks.pid"
```

## 4. Monitor

Assuming `OUTDIR="$PROJECT/results"`:

```bash
tail -F "$PROJECT/results/logs/rnaseq2tracks.log"
column -t -s $'\t' "$PROJECT/results/metadata/run_status.tsv"
```

## 5. Review

Open, in this order:

1. `reports/pipeline_report.html`
2. `multiQC/final/multiQC_final.html`
3. `07_qc/rseqc/genebody/`
4. `analysis/DE/`
5. `analysis/enrichment/`

Rerunning the same command resumes from completed outputs. Set `FORCE_RERUN=1`
only when you intentionally want to recompute checkpointed stages.
