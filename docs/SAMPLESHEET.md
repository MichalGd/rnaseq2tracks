# Samplesheet and replicate hierarchy

## Unit definitions

- **Biological sample**: the independent experimental unit used by DESeq2. Its
  stable identifier is `sample_id`.
- **Biological replicate ID**: an explanatory replicate label within a condition,
  stored in `biological_replicate_id`.
- **Technical replicate**: an independently prepared or sequenced library from
  the same biological sample, identified by `technical_replicate_id`.
- **Lane**: one FASTQ-producing sequencing lane, identified by `lane_id`.

The unique processing key is
`sample_id + technical_replicate_id + lane_id`. The workflow derives a safe
`library_id` by joining these values with `__`.

## Required columns

| Column | SE | PE | Meaning |
|---|---:|---:|---|
| `sample_id` | yes | yes | biological sample and downstream column name |
| `biological_replicate_id` | yes | yes | replicate label, e.g. `R1` |
| `technical_replicate_id` | yes | yes | technical library, e.g. `T01` |
| `lane_id` | yes | yes | lane, e.g. `L001` |
| `fastq_R1` | yes | yes | R1 or single-end FASTQ |
| `fastq_R2` | no | yes | R2 FASTQ |
| `condition` | yes | yes | DESeq2 condition |
| `strandedness` | yes | yes | `unstranded`, `forward` or `reverse` |

Optional columns are `batch` and `description`. Values of biological ID,
condition, batch, description and strandedness must be identical across rows with
the same `sample_id`.

## Example

```csv
sample_id,biological_replicate_id,technical_replicate_id,lane_id,fastq_R1,fastq_R2,condition,strandedness,batch,description
WT_R1,R1,T01,L001,/reads/WT_R1_L001_R1.fq.gz,/reads/WT_R1_L001_R2.fq.gz,WT,reverse,b1,WT replicate 1
WT_R1,R1,T01,L002,/reads/WT_R1_L002_R1.fq.gz,/reads/WT_R1_L002_R2.fq.gz,WT,reverse,b1,WT replicate 1
WT_R2,R2,T01,L001,/reads/WT_R2_L001_R1.fq.gz,/reads/WT_R2_L001_R2.fq.gz,WT,reverse,b1,WT replicate 2
```

The first two rows align separately. Their sorted BAMs are merged and their three
STAR gene-count columns are summed into sample `WT_R1`. They never become two
DESeq2 replicates. The third row is a separate biological sample.

## Validation rules

The preflight rejects duplicate processing keys, FASTQ reuse, missing PE mates,
invalid identifiers, missing FASTQs, invalid strandedness and inconsistent
metadata within a sample. Relative FASTQ paths are resolved from the samplesheet
directory. Input FASTQs are read-only and are never modified.

## Generated metadata

- `metadata/validated_lanes.tsv`: one normalized row per technical unit.
- `metadata/validated_samples.tsv`: one row per biological sample.
- `metadata/analysis_samplesheet.csv`: internal sample-level view for legacy R
  components.
- `metadata/pairwise_contrasts.csv`: automatically generated all-pairwise
  condition comparisons.
- `metadata/technical_merge_audit.tsv`: final sample BAM and number of lane rows.
