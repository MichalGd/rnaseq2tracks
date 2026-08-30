# Output reference

```text
OUTDIR/
├── metadata/
│   ├── validated_lanes.tsv
│   ├── validated_samples.tsv
│   ├── analysis_samplesheet.csv
│   ├── technical_merge_audit.tsv
│   ├── run_status.tsv
│   └── run_provenance.tsv
├── logs/rnaseq2tracks.log
├── fastQC/{raw,trimmed}/
├── fastQScreen/
├── trimmedFastq/
├── STARalignments/
├── STARlogs/lanes/
├── STARgeneCounts/
│   └── lanes/
├── bams/
│   └── lanes/
├── 07_qc/
│   ├── star/
│   ├── rseqc/
│   └── multiqc/
├── multiQC/{raw,trimmed,alignments,final}/
├── bedGraph/{raw,normalized,merged}/
├── bigwig/
├── analysis/
│   ├── counts/
│   ├── DE/
│   ├── tables/
│   ├── figures/
│   └── enrichment/
└── reports/
    ├── pipeline_report.html
    ├── ucsc_tracks.txt
    └── bigwig_summary.txt
```

## Lane-level versus sample-level files

Files under `STARlogs/lanes`, `STARgeneCounts/lanes` and `bams/lanes` correspond
to technical processing units. Top-level `STARgeneCounts/<sample>...` and
`bams/<sample>_sortedS.bam` represent biological samples after consolidation.
Downstream statistics and tracks use the sample-level files.

## Durable deliverables

Keep metadata, logs, lane STAR logs, sample-level STAR counts, final sample BAMs,
normalized bedGraphs, BigWigs, analysis, MultiQC, RSeQC and reports. Original
FASTQs live outside OUTDIR and are never touched.

## UCSC descriptors

`reports/ucsc_tracks.txt` is produced only when `UCSC_TRACKS=true` and
`UCSC_BASE_URL` is a non-empty real URL. BigWig files must actually be published
at those URLs. The descriptor does not upload files.
