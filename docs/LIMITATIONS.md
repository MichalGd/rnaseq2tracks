# Limitations

- The workflow supports conventional human/mouse bulk RNA-seq, not single-cell,
  spatial, long-read, small-RNA or dedicated 3'-end APA assays.
- Technical merging assumes all rows with one `sample_id` are the same biological
  specimen and compatible library protocol/strandedness. The workflow cannot
  infer a mistaken assignment.
- Differential expression requires independent biological replication. Technical
  lanes do not add degrees of freedom.
- Complex paired/repeated-measure, interaction or random-effect designs require
  expert review; the default design is `~ condition`.
- Reference indices and annotations are external site resources. Assembly and
  chromosome-style consistency remain the operator's responsibility.
- FastQ Screen interpretation depends on the configured database set and index
  versions.
- RSeQC gene-body bias varies by protocol and RNA quality; it has no universal
  pass threshold.
- KEGG metadata access may depend on external availability.
- UCSC descriptors describe URLs but do not publish BigWigs.
- Output-existence checkpoints are practical resume guards, not content-addressed
  workflow caching. A materially changed project must use a new OUTDIR.
- The release installer provides reproducibility for software packages, but
  reference snapshots must also be versioned/audited by the site.
