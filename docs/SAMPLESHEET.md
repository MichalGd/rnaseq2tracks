# Samplesheet contract and replicate hierarchy

The samplesheet describes both biological experimental units and the technical
FASTQ units that produced their data. Correctly distinguishing them is essential
for valid differential expression.

## Unit definitions

- **Biological sample (`sample_id`)**: one independent experimental unit and one
  downstream BAM/count-matrix column.
- **Biological replicate ID (`biological_replicate_id`)**: a descriptive label
  for the independent replicate, such as `R1` or `mouse_03`.
- **Technical replicate (`technical_replicate_id`)**: an independently prepared
  or sequenced library from the same biological sample.
- **Lane (`lane_id`)**: one FASTQ-producing sequencing lane.
- **Library ID**: a workflow-derived processing identifier formed as
  `sample_id__technical_replicate_id__lane_id`.

The unique row key is the combination of `sample_id`,
`technical_replicate_id`, and `lane_id`.

## Required and optional columns

| Column | SE | PE | Meaning |
|---|---:|---:|---|
| `sample_id` | required | required | Biological sample; final BAM/count column name. |
| `biological_replicate_id` | required | required | Independent replicate label. |
| `technical_replicate_id` | required | required | Technical library identifier. |
| `lane_id` | required | required | FASTQ-producing lane identifier. |
| `fastq_R1` | required | required | Single-end FASTQ or read 1. |
| `fastq_R2` | absent/ignored | required | Read 2 for PE data. |
| `condition` | required | required | Level used for automatic pairwise DE contrasts. |
| `strandedness` | required | required | `unstranded`, `forward`, or `reverse`. |
| `batch` | optional | optional | Batch covariate available to the DESeq2 design when non-empty. |
| `description` | optional | optional | Human-readable sample description. |

Identifiers may contain letters, numbers, `.`, `_`, and `-`, and must begin
with a letter or number. Avoid spaces and shell punctuation in identifiers.
Condition text is not restricted by the identifier rule, but simple stable
labels make filenames and contrasts easier to interpret.

## Paired-end example with two lanes

```csv
sample_id,biological_replicate_id,technical_replicate_id,lane_id,fastq_R1,fastq_R2,condition,strandedness,batch,description
WT_R1,R1,T01,L001,/reads/WT_R1_L001_R1.fastq.gz,/reads/WT_R1_L001_R2.fastq.gz,WT,reverse,b1,WT replicate 1
WT_R1,R1,T01,L002,/reads/WT_R1_L002_R1.fastq.gz,/reads/WT_R1_L002_R2.fastq.gz,WT,reverse,b1,WT replicate 1
WT_R2,R2,T01,L001,/reads/WT_R2_L001_R1.fastq.gz,/reads/WT_R2_L001_R2.fastq.gz,WT,reverse,b1,WT replicate 2
KO_R1,R1,T01,L001,/reads/KO_R1_L001_R1.fastq.gz,/reads/KO_R1_L001_R2.fastq.gz,KO,reverse,b1,KO replicate 1
KO_R2,R2,T01,L001,/reads/KO_R2_L001_R1.fastq.gz,/reads/KO_R2_L001_R2.fastq.gz,KO,reverse,b1,KO replicate 2
```

The two `WT_R1` rows are processed separately through STAR. Their BAMs and all
three STAR gene-count columns are then consolidated into one `WT_R1` biological
sample. They do not contribute two degrees of freedom to DESeq2.

## Single-end example

```csv
sample_id,biological_replicate_id,technical_replicate_id,lane_id,fastq_R1,condition,strandedness,batch,description
WT_R1,R1,T01,L001,/reads/WT_R1.fastq.gz,WT,reverse,b1,WT replicate 1
WT_R2,R2,T01,L001,/reads/WT_R2.fastq.gz,WT,reverse,b1,WT replicate 2
KO_R1,R1,T01,L001,/reads/KO_R1.fastq.gz,KO,reverse,b1,KO replicate 1
KO_R2,R2,T01,L001,/reads/KO_R2.fastq.gz,KO,reverse,b1,KO replicate 2
```

## Technical replicate patterns

Two lanes from one library:

```text
sample_id=S1, technical_replicate_id=T01, lane_id=L001
sample_id=S1, technical_replicate_id=T01, lane_id=L002
```

Two technical libraries from one biological specimen:

```text
sample_id=S1, technical_replicate_id=T01, lane_id=L001
sample_id=S1, technical_replicate_id=T02, lane_id=L001
```

Both patterns produce one final sample `S1`. If the specimens are biologically
independent, they must use different `sample_id` values even when they share a
condition.

## Validation rules

The workflow rejects:

- missing required columns or values;
- invalid identifiers;
- duplicate row keys;
- reuse of any resolved FASTQ path;
- missing PE mates;
- FASTQ paths that do not exist;
- strandedness outside the three supported values;
- changes in biological replicate ID, condition, batch, description, or
  strandedness among rows sharing one `sample_id`.

Blank lines and lines beginning with `#` are ignored. CSV quoting follows normal
CSV rules. Relative FASTQ paths are resolved from the samplesheet directory.
Original FASTQs are read-only inputs and are never modified or deleted.

## Generated metadata

| Output | Unit and purpose |
|---|---|
| `metadata/validated_lanes.tsv` | One normalized row per technical unit, including derived `library_id` and resolved FASTQ paths. |
| `metadata/validated_samples.tsv` | One row per biological sample with technical-library and lane counts. |
| `metadata/analysis_samplesheet.csv` | Internal biological-sample view consumed by downstream R/shell modules. |
| `metadata/pairwise_contrasts.csv` | Automatically generated all-pairwise condition comparisons. |
| `metadata/technical_merge_audit.tsv` | Final sample BAM path and number of merged lane rows. |

Review these files early in a new project. They are the authoritative record of
how samples were interpreted.

## Statistical implications

Technical replication increases sequencing depth or protects against technical
failure. It does not estimate biological variability. DESeq2 dispersion and
hypothesis tests operate on unique biological `sample_id` columns. At least two,
and preferably three or more, independent biological samples per condition are
normally needed for interpretable differential expression.
