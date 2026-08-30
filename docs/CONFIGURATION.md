# Configuration

`config.conf` is the only launch input. It uses shell-compatible `KEY=value`
assignments. Keep it under project control and do not place commands in it.
Relative paths are interpreted relative to the config file.

## Project and inputs

`PROJECT_ID`, `SPECIES`, `GENOME_ASSEMBLY`, `LIBRARY_LAYOUT`, `SAMPLESHEET`,
`CONTRASTS` and `OUTDIR` define the project. `SPECIES` is `human` or `mouse`;
layout is `SE` or `PE`.

## Reference resources

Set the STAR index, GTF, chromosome sizes and RSeQC BED for the selected species.
All must represent the same assembly and chromosome naming convention. A mismatch
can yield failed alignments, empty BigWigs or misleading RSeQC summaries.

## Resource controls

| Key | Scope |
|---|---|
| `MAX_JOBS` | maximum concurrent per-lane/per-sample shell jobs |
| `STAR_THREADS` | threads in each STAR job |
| `SAMTOOLS_THREADS` | sort, merge and index threads |
| `FASTQC_THREADS` | threads per FastQC job |
| `FASTQSCREEN_THREADS` | threads per FastQ Screen job |
| `FASTQSCREEN_SUBSET` | reads sampled per technical row |

Budget for `MAX_JOBS × threads per job`, not just one job. STAR also requires
substantial memory per concurrent process.

## Module switches

- `RUN_FASTQSCREEN=true`
- `RUN_RSEQC=true`
- `RUN_DE=true`
- `RUN_ENRICHMENT=true`
- `MERGE_CONDITION_TRACKS=true`
- `UCSC_TRACKS=true`

Technical-lane consolidation is mandatory and is not disabled by
`MERGE_CONDITION_TRACKS`; that switch controls only condition-level browser
tracks.

## Differential analysis

`DESIGN_FORMULA` is passed to DESeq2. The standard design is `~ condition`.
Batch-aware studies may use `~ batch + condition` when `batch` is represented in
the internal sample metadata and the model is full-rank. Thresholds control
reported significant lists; they do not replace biological replication.

## UCSC and cleanup

Set `UCSC_BASE_URL` only after BigWigs have a real HTTP(S) location. An empty
value skips descriptors. `CLEANUP_INTERMEDIATES=1` removes only documented,
regenerable intermediates after report, MultiQC and enrichment sentinels exist.
Use `CLEANUP_DRYRUN=1` to audit targets first.
