# Architecture and documentation comparison

This revision compared the current `rnaseq2tracks` implementation and
documentation with `rna_ends2tracks`. The workflows analyze different assays:
operational patterns can be shared, but PAS/APA biology must not be copied into a
conventional bulk RNA-seq workflow.

## Operational architecture

| Area | `rna_ends2tracks` pattern | Current `rnaseq2tracks` behavior |
|---|---|---|
| Project inputs | Config plus lane-level samplesheet | Matched: `config.conf` is the only CLI input and points to `samplesheet.csv`. |
| Replicate hierarchy | Biological sample, technical replicate, lane | Matched: explicit IDs; lane BAMs/counts are consolidated by `sample_id`. |
| Launch | Stable self-contained installed command | Matched: `rnaseq2tracks --config FILE`; no environment activation. |
| Contrasts | Derived from project metadata with explicit designs | Simplified: every condition pair is generated automatically; optional CSV selects a subset/order. |
| Logging | Chronological master log plus structured status/events | Partially matched: master log and `run_status.tsv`; no status subcommand or event JSONL. |
| Resume | Content/signature-aware receipts and stage controls | Simpler output checkpoints; identical command resumes, with broad `FORCE_RERUN`. |
| Parallel work | Resource-planned bounded pools, overlapping modules | Bounded `MAX_JOBS` pools; RSeQC overlaps downstream work, but no aggregate RAM planner. |
| Provenance | Detailed receipts, environment/reference/output dashboard | Basic run provenance with version, paths, counts, and config/samplesheet hashes. |
| Final report | Extensive cross-module summaries and inventories | Self-contained QC/DE/enrichment summary; native full outputs remain separate. |
| Cleanup | Receipt-protected allow list and manifest | Completion-sentinel and BigWig checks; no content-aware cleanup receipt. |

## Documentation structure

The `rna_ends2tracks` documentation is organized around user tasks, scientific
methods, QC/output interpretation, and administrator/method-development
references. The earlier `rnaseq2tracks` documentation contained the right broad
topics but was substantially shorter and omitted several implementation details.

This docs-only revision adds or expands the equivalent coverage:

| `rna_ends2tracks` documentation concern | `rnaseq2tracks` equivalent |
|---|---|
| Shared-server quick start | `QUICK_START.md` |
| Workflow stages and dependency graph | `WORKFLOW.md` |
| Full configuration reference | `CONFIGURATION.md` |
| Replicate/lane contract | `SAMPLESHEET.md` |
| Methods and count/normalization universes | `METHODS.md` |
| FastQ Screen | `FASTQ_SCREEN.md` |
| RSeQC | `RSEQC.md` |
| Differential analyses/enrichment/reporting | `ANALYSIS.md` and `OUTPUTS.md` |
| Tracks/UCSC outputs | `METHODS.md` and `OUTPUTS.md` |
| Recovery/troubleshooting | `OPERATIONS.md` |
| Server installation | `INSTALLATION.md` |
| Scientific/implementation limits | `LIMITATIONS.md` |

The pages explicitly document where functionality differs. In particular, they
do not advertise `rna_ends2tracks` commands such as `status`, `--dry-run`,
`--from-step`, or `--stop-after` for `rnaseq2tracks`.

## Capabilities retained from the older RNA-seq workflow

The conventional RNA-seq workflow already had assay-appropriate capabilities:

- SE and PE alignment;
- FastQC, FastQ Screen, STAR QC, MultiQC, and RSeQC;
- gene-level STAR counting and DESeq2;
- strand-aware browser coverage;
- GO, KEGG, Reactome, and Hallmark enrichment;
- sample relationship, MA, volcano, and enrichment plots.

The modernization wrapped these in clearer metadata, launch, logging, resume,
provenance, and documentation contracts rather than replacing the scientific
core with a 3'-end method.

## Deliberately not copied

- Exact transcript-end extraction, internal-priming filters, PAS discovery,
  C0-C5 count universes, APA-A/APA-B, PAS atlases, and PCPA interpretation are
  specific to `rna_ends2tracks`.
- The 3'-end workflow's assembly/protocol acceptance manifests have no meaning
  for conventional RNA-seq.
- Complex resource planning and receipt machinery are not claimed where the
  simpler executable does not implement them.
- Documentation depth and organization are matched; unsupported functionality
  is not invented to make the repositories look identical.

## Remaining structural opportunities

Future code releases could add a validate-only/dry-run mode, a `status` command,
content-aware receipts, stage-specific resume/force controls, aggregate CPU/RAM
planning, and a more detailed provenance dashboard. They are documented here as
potential work, not current behavior. This documentation revision intentionally
does not modify executable files.
