# Architecture comparison and backport rationale

This revision compared the earlier `rnaseq2tracksP` implementation with the more
recent `rna_ends2tracks` workflow. The two projects analyze different assays, so
assay-specific PAS logic was not copied. Operational contracts that improve a
general server workflow were adopted.

| Area | Earlier rnaseq2tracksP | rna_ends2tracks practice | rnaseq2tracks revision |
|---|---|---|---|
| Metadata unit | one row implicitly equaled one sample | explicit biological, technical and lane IDs | backported with lane-level validation and sample aggregation |
| Launch | repository script and activated environment | stable self-contained launcher plus config | backported as `rnaseq2tracks --config FILE` |
| Samplesheet path | stored in config but launch/docs were inconsistent | config is sole launch contract | standardized |
| Installation | mutable named Conda environment | immutable versioned environments and rollback launchers | backported release installer |
| Logging | terminal/stdout only | chronological master log and structured status | backported |
| Resume | broad output-existence checks | granular checkpoints and explicit state | improved to lane/sample checkpoints plus status |
| Provenance | partial session information | version/input receipts and hashes | backported run provenance |
| Documentation | many historical pages with stale behavior | task-oriented pages tied to current outputs | replaced with indexed, current documentation |
| Final report | useful QC summary rendered before enrichment | integrated end-of-run report | moved after enrichment and expanded |

## Capabilities retained from the older workflow

The earlier repository was already mature for conventional RNA-seq analysis. Its
SE/PE support, FastQ Screen, RSeQC, DESeq2, strand-aware browser tracks, GO/KEGG/
Reactome/Hallmark enrichment and report remain. These are not replacements for
the 3'-end PAS stages in `rna_ends2tracks`; they are assay-appropriate features of
this workflow.

## Deliberately not copied

- PAS calling, exact-end extraction, APA-A/APA-B and PAS atlases are specific to
  3'-end RNA-seq.
- The `rna_ends2tracks` sample schema contains protocol-specific fields not needed
  for conventional bulk RNA-seq.
- Statistical assumptions were not changed merely to make the repositories look
  identical.

The shared pattern is therefore operational consistency, not forced biological
method equivalence.
