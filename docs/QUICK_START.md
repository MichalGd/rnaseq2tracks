# Shared-server quick start

This page is for an ordinary human or mouse bulk RNA-seq project using an
installed shared release. The launcher selects its immutable environment
internally. Do not activate Conda and do not export Python, R, or bioinformatics
tool paths.

## 1. Confirm the launcher

```bash
command -v rnaseq2tracks
rnaseq2tracks --version
rnaseq2tracks --help
```

For the current validated deployment, the expected version is:

```text
6.0.0-alpha.1.post1
```

Use the configuration and samplesheet templates from the same installed release
as the launcher.

## 2. Create the two project input files

```bash
PROJECT="$HOME/Analysis/my_rnaseq_project"
CONFIG_DIR="$PROJECT/config"
RELEASE_ENV="/opt/conda_envs/rnaseq2tracks-6.0.0a1.post1"

mkdir -p "$CONFIG_DIR"
cp "$RELEASE_ENV/share/rnaseq2tracks/config/config_template.conf" \
  "$CONFIG_DIR/config.conf"
cp "$RELEASE_ENV/share/rnaseq2tracks/config/samplesheet_template_PE.csv" \
  "$CONFIG_DIR/samplesheet.csv"
```

For a single-end project, copy `samplesheet_template_SE.csv` instead. These are
the only required project-configuration files. Shared genome references, RSeQC
BED files, FastQ Screen databases, and Kent utilities remain site resources
referenced by `config.conf`.

## 3. Prepare `samplesheet.csv`

Keep the template header unchanged. One row represents one technical
library/lane FASTQ unit.

- Use a unique combination of `sample_id`, `technical_replicate_id`, and
  `lane_id` for every row.
- Rows from the same biological specimen must use the same `sample_id`.
- Independent biological specimens must use different `sample_id` values.
- For PE data, provide both `fastq_R1` and `fastq_R2`; for SE data, use the SE
  template and provide `fastq_R1`.
- Set `strandedness` to `unstranded`, `forward`, or `reverse` according to the
  library protocol.
- Keep `condition`, `batch`, `description`, biological replicate ID, and
  strandedness consistent among rows sharing a `sample_id`.
- FASTQ paths may be absolute or relative to the samplesheet directory.
- Do not list one FASTQ path more than once.

Read the [samplesheet contract](SAMPLESHEET.md) before encoding multiple lanes
or technical libraries.

## 4. Edit `config.conf`

At minimum, set the project, layout, samplesheet, output directory, and the
assembly-matched resource block:

```bash
PROJECT_ID="my_rnaseq_project"
SPECIES="mouse"
GENOME_ASSEMBLY="GRCm39"
LIBRARY_LAYOUT="PE"
SAMPLESHEET="samplesheet.csv"
OUTDIR="../results"

STAR_INDEX_MOUSE="/shared/references/GRCm39/STAR"
GTF_MOUSE="/shared/references/GRCm39/annotation.gtf"
CHROM_SIZES_MOUSE="/shared/references/GRCm39/chrom.sizes"
RSEQC_BED_MOUSE="/shared/references/GRCm39/annotation.bed12"

KENTUTILS_DIR="/shared/tools/kent"
FASTQSCREEN_CONF="/shared/fastq_screen/fastq_screen.conf"
```

Relative `SAMPLESHEET`, `OUTDIR`, `CONTRASTS`, and FastQ Screen configuration
paths are resolved from the directory containing `config.conf`.

Every unique pair of conditions is compared automatically. For `A`, `B`, and
`C`, the workflow writes three comparisons to
`OUTDIR/metadata/pairwise_contrasts.csv`. A separate `contrasts.csv` is required
only when an expert intentionally restricts or reorders comparisons.

Review the CPU and memory implications of `MAX_JOBS * STAR_THREADS` before a
large run. See the [configuration guide](CONFIGURATION.md).

## 5. Perform a manual pre-launch review

The current CLI starts processing after its internal preflight; it does not have
a validate-only or dry-run option. Before launch, verify the most consequential
paths directly:

```bash
CONFIG="$CONFIG_DIR/config.conf"
SAMPLESHEET="$CONFIG_DIR/samplesheet.csv"

test -r "$CONFIG" && echo "Config readable: PASS"
test -r "$SAMPLESHEET" && echo "Samplesheet readable: PASS"
head -n 3 "$SAMPLESHEET"
df -h "$PROJECT"
```

Then review `config.conf` for:

- correct `SPECIES`, `GENOME_ASSEMBLY`, and `LIBRARY_LAYOUT`;
- matching STAR index, GTF, chromosome sizes, and RSeQC BED;
- a real FastQ Screen configuration when `RUN_FASTQSCREEN=true`;
- a writable, new `OUTDIR` for a new scientific analysis;
- resource settings within server capacity;
- intended DE design and thresholds.

## 6. Launch the workflow

Foreground launch:

```bash
rnaseq2tracks --config "$CONFIG"
```

Detached launch that survives SSH disconnection:

```bash
RUN_LOG="$PROJECT/rnaseq2tracks.launch.log"
PID_FILE="$PROJECT/rnaseq2tracks.pid"

nohup rnaseq2tracks --config "$CONFIG" \
  > "$RUN_LOG" 2>&1 &

RUN_PID=$!
echo "$RUN_PID" > "$PID_FILE"
disown "$RUN_PID"

echo "PID: $RUN_PID"
echo "Launcher log: $RUN_LOG"
```

## 7. Monitor progress

Assuming `OUTDIR="$PROJECT/results"`:

```bash
OUTDIR="$PROJECT/results"

tail -F "$OUTDIR/logs/rnaseq2tracks.log"
```

In a second terminal:

```bash
column -t -s $'\t' "$OUTDIR/metadata/run_status.tsv"
```

To refresh every minute:

```bash
watch -n 60 "column -t -s $'\\t' '$OUTDIR/metadata/run_status.tsv'"
```

The master log is chronological and identifies stage starts, skips, failures,
and successful completion. `run_status.tsv` records the latest state, stage,
message, update time, and PID. There is no `rnaseq2tracks status` command in the
current release.

## 8. Verify completion

Require both of the following:

```bash
grep -F $'status\tcompleted' "$OUTDIR/metadata/run_status.tsv"
tail -n 5 "$OUTDIR/logs/rnaseq2tracks.log"
```

The final master-log line should contain `rnaseq2tracks ... COMPLETE`. Then
inspect:

```text
reports/pipeline_report.html
multiQC/final/multiQC_final.html
07_qc/star/star_alignment_summary.tsv
07_qc/rseqc/
analysis/figures/
analysis/DE/
analysis/enrichment/
bigwig/
metadata/run_provenance.tsv
```

Do not interpret DE or enrichment before reviewing read quality, species screen,
alignment, strandedness, gene-body coverage, sample relationships, and the
technical merge audit.

## If the run stops

Read the final status and log entries:

```bash
column -t -s $'\t' "$OUTDIR/metadata/run_status.tsv"
tail -n 100 "$OUTDIR/logs/rnaseq2tracks.log"
```

Correct the cause, then rerun the same command:

```bash
rnaseq2tracks --config "$CONFIG"
```

Existing checkpoints reuse completed work. Do not create outputs or checkpoint
files manually. Use a new `OUTDIR` after changing samples, reference assembly,
layout, or strandedness. See [operations](OPERATIONS.md).
