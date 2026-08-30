# Migration from `rnaseq2tracksP`

The public repository is now:

```text
https://github.com/MichalGd/rnaseq2tracks
```

The executable, installed environment, launcher, documentation, and citation
identity use `rnaseq2tracks`. Old GitHub URLs may redirect, but new scripts and
citations should use the canonical name.

## Update an existing clone

```bash
git remote set-url origin https://github.com/MichalGd/rnaseq2tracks.git
git remote -v
git fetch origin
```

Do not rename a directory containing an active run in place. Repository checkout
paths are not the same as immutable installed release paths.

## Samplesheet migration

An older row represented one sample directly:

```csv
sample_id,fastq_R1,fastq_R2,condition,replicate,strandedness
WT_R1,/reads/WT_R1_1.fq.gz,/reads/WT_R1_2.fq.gz,WT,1,reverse
```

The current PE contract is:

```csv
sample_id,biological_replicate_id,technical_replicate_id,lane_id,fastq_R1,fastq_R2,condition,strandedness,batch,description
WT_R1,R1,T01,L001,/reads/WT_R1_1.fq.gz,/reads/WT_R1_2.fq.gz,WT,reverse,,WT replicate 1
```

For a sample with one library/lane, stable defaults such as `T01` and `L001` are
appropriate. Multiple technical rows from the same biological specimen share
`sample_id`; independent biological specimens never share it.

Read [SAMPLESHEET.md](SAMPLESHEET.md) before migrating multi-lane data.

## Contrast migration

A separate contrast file is no longer required for ordinary runs. The workflow
generates every unique pair of samplesheet conditions in
`metadata/pairwise_contrasts.csv`.

Set optional `CONTRASTS="contrasts.csv"` only when intentionally restricting or
reordering comparisons. Remove stale active `CONTRASTS=` entries when the goal
is automatic all-pairwise testing.

## Launch migration

Old pattern:

```bash
conda activate rnaseq2tracks
bash scripts/rnaseq2tracks.sh config/config.conf
```

Current pattern:

```bash
rnaseq2tracks --config /real/project/path/config/config.conf
```

There is no positional samplesheet or contrasts argument. No Conda activation or
manual `PATH` export is needed after shared installation.

## Output migration

Use a new `OUTDIR` when validating a migrated project. The technical-row and
biological-sample hierarchy changes filenames and statistical columns; mixing
old partial outputs with the new contract can make checkpoints misleading.

After the first migrated run, verify:

- `metadata/validated_lanes.tsv`;
- `metadata/validated_samples.tsv`;
- `metadata/technical_merge_audit.tsv`;
- `metadata/pairwise_contrasts.csv`;
- final BAM/count columns;
- DESeq2 sample metadata and contrasts;
- clean-shell launcher/version provenance.
