# Migration to the new contract and name

## Repository rename

The intended public identity is `rnaseq2tracks`, replacing `rnaseq2tracksP`.

1. In GitHub open **Settings → General → Repository name**.
2. Rename `rnaseq2tracksP` to `rnaseq2tracks`.
3. Update a local clone:

```bash
git remote set-url origin https://github.com/MichalGd/rnaseq2tracks.git
git remote -v
```

GitHub normally redirects old URLs, but scripts, badges, citations and examples
should use the canonical new URL. The executable, environment, installer,
documentation and citation metadata now use `rnaseq2tracks`.

## Samplesheet migration

Old rows had `sample_id,fastq_R1[,fastq_R2],condition,replicate,strandedness`.
Convert `replicate` to `biological_replicate_id`; add
`technical_replicate_id` and `lane_id`. For a sample with only one library/lane,
use stable defaults such as `T01` and `L001`.

Old PE:

```csv
WT_R1,/reads/WT_R1_1.fq.gz,/reads/WT_R1_2.fq.gz,WT,1,reverse
```

New PE:

```csv
WT_R1,R1,T01,L001,/reads/WT_R1_1.fq.gz,/reads/WT_R1_2.fq.gz,WT,reverse,,WT replicate 1
```

Do not make lane IDs into biological sample IDs. Multiple lane rows share the
same `sample_id`.

## Launch migration

Old:

```bash
conda activate rnaseq2tracks
bash scripts/rnaseq2tracks.sh config/config.conf
```

New:

```bash
rnaseq2tracks --config /absolute/path/to/config.conf
```

`SAMPLESHEET` remains inside config; there is no positional samplesheet argument.
Use a new OUTDIR when validating a migrated project.
