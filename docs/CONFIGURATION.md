# Configuration guide

`config.conf` is the only launch argument. It stores the samplesheet path,
reference assets, module switches, thresholds, resources, track behavior, and
cleanup policy.

The file is sourced as shell-compatible `KEY=value` assignments. Treat it as a
trusted project file: do not put commands, substitutions, aliases, or unrelated
shell logic in it. Quoted values are recommended. Relative `SAMPLESHEET`,
optional `CONTRASTS`, `OUTDIR`, and `FASTQSCREEN_CONF` paths are resolved from
the directory containing `config.conf`.

## Project and input settings

| Key | Allowed/example | Meaning |
|---|---|---|
| `PROJECT_ID` | `my_rnaseq_project` | Human-readable project identifier recorded in configuration/report context. |
| `SPECIES` | `human` or `mouse` | Selects the corresponding reference block and enrichment organism. |
| `GENOME_ASSEMBLY` | `GRCh38`, `GRCm39` | Descriptive assembly metadata; resource consistency remains the operator's responsibility. |
| `LIBRARY_LAYOUT` | `SE` or `PE` | Project-wide read layout. Mixed layouts in one run are unsupported. |
| `SAMPLESHEET` | `samplesheet.csv` | Required lane-level metadata; relative to the config directory. |
| `CONTRASTS` | usually unset | Optional expert CSV restricting or reordering contrasts. |
| `OUTDIR` | `../results` | Output directory. Use a new path for a materially changed analysis. |

When `CONTRASTS` is unset, unique conditions are retained in first-appearance
order and every unordered pair is generated. For conditions `A`, `B`, and `C`,
the comparisons are `B_vs_A`, `C_vs_A`, and `C_vs_B`. The generated file is
`OUTDIR/metadata/pairwise_contrasts.csv`.

An optional explicit contrast CSV has this header:

```csv
contrast_id,numerator,denominator
treatment_vs_control,treatment,control
```

Numerator and denominator must exactly match samplesheet condition values.

## Reference resources

Fill the block for the selected species:

| Key family | Required asset |
|---|---|
| `STAR_INDEX_HUMAN` / `STAR_INDEX_MOUSE` | STAR genome-index directory |
| `GTF_HUMAN` / `GTF_MOUSE` | Gene annotation used for STAR count interpretation and annotated DE tables |
| `CHROM_SIZES_HUMAN` / `CHROM_SIZES_MOUSE` | Contig lengths used by `bedGraphToBigWig` |
| `RSEQC_BED_HUMAN` / `RSEQC_BED_MOUSE` | BED12 transcript annotation for RSeQC |

All four resources must describe the same assembly and chromosome naming style.
The workflow does not infer or liftover incompatible references.

Track/reference controls:

| Key | Meaning |
|---|---|
| `REGULAR_CHROMS_ONLY` | When `true`, BigWigs retain canonical autosomes, sex chromosomes, and mitochondrial chromosome according to species/naming policy. |
| `CHROMOSOME_NAMING` | `ucsc` (`chr1`) or `ensembl` (`1`) canonical-contig patterns. |
| `KENTUTILS_DIR` | Directory containing executable `bedGraphToBigWig`. |
| `TMPDIR` | Temporary directory used by STAR helpers. |

## Resource controls

| Key | Scope |
|---|---|
| `MAX_JOBS` | Maximum concurrent jobs in lane-, sample-, and condition-level shell pools. |
| `STAR_THREADS` | Threads in each STAR alignment. |
| `SAMTOOLS_THREADS` | Threads for sorting, merging, and indexing. |
| `FASTQC_THREADS` | Threads in each FastQC process. |
| `FASTQSCREEN_THREADS` | Threads in each FastQ Screen process. |
| `FASTQSCREEN_SUBSET` | Number of R1 reads sampled from each technical row. |

`MAX_JOBS` is not a total CPU cap. Approximate STAR demand is
`MAX_JOBS * STAR_THREADS`; approximate FastQ Screen demand is
`MAX_JOBS * FASTQSCREEN_THREADS`. Concurrent STAR jobs also multiply memory use.

## Trimming and QC

| Key | Default | Meaning |
|---|---:|---|
| `TRIM_QUALITY` | `20` | Trim Galore quality cutoff. |
| `TRIM_MIN_LENGTH` | `20` | Minimum retained read length. |
| `RUN_FASTQSCREEN` | `true` | Enable R1 species/contamination screening per technical row. |
| `FASTQSCREEN_CONF` | site path | FastQ Screen database configuration. All declared Bowtie2 indexes must exist. |
| `RUN_RSEQC` | `true` | Enable sample-level RSeQC. Requires the selected species BED12 file. |
| `RSEQC_BIN_DIR` | empty | Optional directory containing RSeQC executables; empty uses launcher `PATH`. |
| `STRAND_TOLERANCE_PCT` | `5` | Allowed disagreement in the workflow's strand-consistency check. |

FastQ Screen and RSeQC are production defaults. Disabling them removes evidence
from final QC and should be recorded in downstream reporting.

## Differential expression

| Key | Default | Meaning |
|---|---:|---|
| `RUN_DE` | `true` | Run DESeq2 contrasts and expression QC plots. Requires at least two conditions. |
| `DESIGN_FORMULA` | `~ condition` | Formula used to construct the DESeq2 data set. |
| `DE_PADJ_THRESHOLD` | `0.05` | Adjusted-p-value cutoff for `*_significant.tsv`. |
| `DE_LFC_THRESHOLD` | `1` | Absolute shrunken log2-fold-change cutoff for significant tables. |

The internal sample metadata contains `condition`, `replicate`, and non-empty
`biological_replicate_id`/`batch` fields. A batch-aware formula such as
`~ batch + condition` is valid only when the design is full-rank and batch is
not confounded with condition. Technical lanes never create DESeq2 replicates.

The current pairwise DE script specifically tests the `condition` factor. More
complex interactions, paired/repeated measures, or non-condition coefficients
require expert validation and may need code changes; do not assume that changing
`DESIGN_FORMULA` alone implements every statistical design.

## Enrichment

| Key | Default | Meaning |
|---|---:|---|
| `RUN_ENRICHMENT` | `true` | Run enrichment after successful DE when `RUN_DE=true`. |
| `PADJ_THRESHOLD` | `0.05` | DE adjusted-p-value cutoff used to select ORA genes. |
| `LFC_THRESHOLD` | `1` | Absolute DE log2-fold-change cutoff used to select ORA genes. |
| `ENRICHMENT_MINGS` | `10` | Minimum gene-set size. |
| `ENRICHMENT_MAXGS` | `500` | Maximum gene-set size. |

ORA and GSEA are attempted for GO, KEGG, Reactome, and Hallmarks. KEGG may
require upstream network availability. Database-specific failures are logged;
do not interpret a missing result file as biological absence without checking
the master log.

## Tracks and UCSC descriptors

| Key | Default | Meaning |
|---|---:|---|
| `MERGE_CONDITION_TRACKS` | `true` | Average normalized biological-sample tracks within each condition. |
| `UCSC_TRACKS` | `true` | Request UCSC descriptor generation. |
| `UCSC_BASE_URL` | empty | Public HTTP(S) directory containing the BigWig basenames. Empty skips descriptors. |

Condition tracks are visualization summaries, not count matrices and not
statistical replicates. The descriptor generator writes one physical line per
BigWig and adds `negateValues=on` for names containing `Rev`/`rev`.

`UCSC_BASE_URL` must be plain URL text, for example:

```bash
UCSC_BASE_URL="http://example.org/project/bigwig"
```

Do not paste a Markdown-formatted link; provide only the plain URL.

## Resume and cleanup

| Key | Default | Meaning |
|---|---:|---|
| `FORCE_RERUN` | `0` | Ignore most output-existence checkpoints. Use only deliberately. |
| `CLEANUP_INTERMEDIATES` | `0` | Remove allow-listed regenerable intermediates after completion checks. |
| `CLEANUP_DRYRUN` | `0` | Print cleanup targets without deleting when cleanup is enabled. |
| `CLEANUP_ALLCHR_BEDGRAPH` | `0` | Also remove optional all-chromosome bedGraph archives. |

Cleanup requires the final MultiQC report, pipeline report, at least one BigWig,
and the enrichment sentinel when DE enrichment is enabled. Original FASTQs are
never cleanup targets.

## Tool overrides

`PYTHON_BIN`, `FASTQC_BIN`, `MULTIQC_BIN`, and `RSCRIPT_BIN` normally require no
editing in an installed release. The self-contained launcher prepares the
correct environment. Overrides are intended for development/debugging, not
routine project configuration.

## Configuration checklist

Before launching, confirm:

1. layout and samplesheet columns agree;
2. all FASTQs exist and are assigned once;
3. species, assembly, STAR index, GTF, chromosome sizes, and RSeQC BED match;
4. strand labels match the library protocol;
5. FastQ Screen indexes are readable when enabled;
6. `MAX_JOBS * STAR_THREADS` and concurrent memory fit the server;
7. the DE design is appropriate and has biological replication;
8. `OUTDIR` represents one stable scientific input/reference universe;
9. cleanup and UCSC publication choices are intentional.
