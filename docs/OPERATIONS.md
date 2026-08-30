# Logging, status, resume and cleanup

## One chronological log

All workflow stdout and stderr are tee'd to `OUTDIR/logs/rnaseq2tracks.log`.
Entries state stage start, sample/lane checkpoint skips, warnings and final
completion or failure. A separate `nohup` redirection may contain only launcher
messages; the OUTDIR log is authoritative.

```bash
tail -F /path/to/results/logs/rnaseq2tracks.log
```

## Status

`metadata/run_status.tsv` is rewritten at stage transitions and on a
trapped shell failure. It contains workflow, version, state, stage, message,
timestamp and PID.

```bash
column -t -s $'\t' /path/to/results/metadata/run_status.tsv
```

`metadata/run_provenance.tsv` records the completed release, input paths and
hashes, layout/species and biological/technical counts.

## Resume

Run the identical command again. Existing per-lane and per-sample outputs are
used as checkpoints. The workflow does not require a special resume flag.

```bash
rnaseq2tracks --config /path/to/config.conf
```

Do not change samplesheet membership, reference assembly or strandedness inside
an existing OUTDIR. Start a new OUTDIR when those define a different analysis.
Use `FORCE_RERUN=1` only to deliberately invalidate checkpoints.

## Cleanup

`CLEANUP_INTERMEDIATES=1` removes trimmed FASTQs, unsorted STAR BAM/SJ files,
lane-level BAMs after successful sample merging, raw bedGraphs and uncompressed
condition bedGraphs. It retains original inputs, sample BAMs, counts, QC,
normalized tracks, DE/enrichment and reports.

Cleanup requires the final MultiQC and report, plus enrichment when enabled. Test
first with `CLEANUP_DRYRUN=1`. Deleted intermediates are regenerable, but recovery
requires rerunning their stages from original FASTQs.

## Failure triage

1. Read the last 100 master-log lines.
2. Inspect `run_status.tsv` for the failed stage.
3. Inspect the stage-specific file named in the error.
4. Correct configuration/input/tool problems.
5. Relaunch the same command.

Do not manually create checkpoint outputs; that can make an incomplete stage look
successful.
