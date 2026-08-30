# Logging, monitoring, restart, cleanup, and troubleshooting

## Authoritative logs

The launcher redirects workflow stdout and stderr through `tee` into one
chronological file:

```text
OUTDIR/logs/rnaseq2tracks.log
```

It records release/start information, config/samplesheet/output paths, stage
starts, sample/lane skips, warnings, failures, and final completion. Follow it
with:

```bash
tail -F /path/to/OUTDIR/logs/rnaseq2tracks.log
```

An external `nohup` log is still useful for shell/launcher failures before
`OUTDIR` is initialized, but the master log is authoritative once created.

## Current state

`metadata/run_status.tsv` is rewritten at initialization, major stage changes,
trapped failure, and completion. It contains:

```text
workflow
version
status
stage
message
updated_at
pid
```

Inspect it with:

```bash
column -t -s $'\t' /path/to/OUTDIR/metadata/run_status.tsv
```

The current release does not have a `rnaseq2tracks status` subcommand. To check
the recorded PID:

```bash
PID=$(awk -F '\t' '$1=="pid" {print $2}' /path/to/OUTDIR/metadata/run_status.tsv)
ps -p "$PID" -o pid,etime,%cpu,%mem,stat,args
```

## Successful completion

Require all three forms of evidence:

1. `run_status.tsv` contains `status<TAB>completed`;
2. the master log ends with `rnaseq2tracks ... COMPLETE`;
3. expected requested deliverables exist, especially final MultiQC, pipeline
   report, count/DE outputs, and BigWigs.

`metadata/run_provenance.tsv` is written at report time and rewritten at final
completion with version, timestamps, resolved inputs, sample/row/contrast counts,
layout/species, and input hashes.

## Resume behavior

After correcting a failure, run the identical command:

```bash
rnaseq2tracks --config /path/to/project/config/config.conf
```

The workflow checks completed outputs and skips reusable lane/sample/stage work.
It also recognizes complete staged STAR outputs after an interrupted parallel
run and downstream STAR checkpoints after trimmed FASTQs have been cleaned.

There is no `--from-step` CLI. The workflow traverses its stage order and skips
recognized outputs.

Use a new `OUTDIR` when changing:

- sample membership or FASTQ assignments;
- SE/PE layout or strandedness;
- species, assembly, STAR index, GTF, chromosome sizes, or RSeQC BED;
- a scientific design that changes the meaning of existing outputs.

Output-existence checkpoints are practical restart guards, not content-addressed
workflow caching.

## Forced rerun

`FORCE_RERUN=1` makes most `done_check` guards recompute their stages. It is a
broad control, not a single-stage force option. Do not enable it merely because a
run stopped: a normal rerun is safer and faster when existing outputs are valid.

Before forcing, preserve or move the old `OUTDIR` when results may be needed for
audit. Never fabricate checkpoint files to make an incomplete stage look
successful.

## Cleanup

Cleanup is off by default. Enable an audit first:

```bash
CLEANUP_INTERMEDIATES=1
CLEANUP_DRYRUN=1
```

After reviewing the master-log targets, set `CLEANUP_DRYRUN=0` for a later full
successful run/resume.

Cleanup requires:

- final MultiQC;
- final pipeline report;
- enrichment sentinel when DE enrichment was requested;
- at least one BigWig.

It can remove:

- trimmed FASTQs;
- unsorted STAR BAMs and splice-junction tables;
- lane-level sorted BAMs/indices after biological-sample consolidation;
- raw per-sample bedGraphs;
- uncompressed condition bedGraphs;
- optionally all-chromosome bedGraph archives.

It retains original FASTQs, biological-sample BAMs, STAR counts/logs, normalized
bedGraphs, BigWigs, QC, DE/enrichment, reports, and provenance.

## Failure triage

Use this order:

1. read `metadata/run_status.tsv`;
2. read the last 100-200 master-log lines;
3. locate the command/tool named in the last error;
4. inspect its native output/log;
5. verify disk, memory, and process state;
6. correct the cause;
7. rerun the same command without force.

```bash
tail -n 150 "$OUTDIR/logs/rnaseq2tracks.log"
df -h "$OUTDIR"
free -h
ps -u "$USER" -o pid,ppid,etime,%cpu,%mem,stat,args --forest
```

## Common problems

### `realpath: ... config.conf: No such file or directory`

The example `/absolute/path/to/config.conf` was used literally. Supply the real
project path.

### FastQ Screen preflight failure

Confirm `FASTQSCREEN_CONF` exists and each `DATABASE` prefix has Bowtie2 index
files. Shared database paths are server-specific.

### RSeQC BED failure or empty outputs

Confirm BED12 format, assembly, and contig naming match the BAM. Do not substitute
the GTF path for a BED12 annotation.

### STAR is slow or the server is overloaded

Reduce `MAX_JOBS` first. Peak demand multiplies per-job `STAR_THREADS` and memory
by concurrent STAR jobs.

### DESeq2 design failure

Check biological replication, factor levels, empty/confounded batch values, and
full rank. Technical lanes do not rescue a design with insufficient biological
samples.

### Missing KEGG result

Read enrichment messages in the master log. Upstream KEGG service/network
failure is different from an empty valid result.

### UCSC rejects descriptors

Confirm each descriptor is exactly one line, `UCSC_BASE_URL` is plain HTTP(S)
text, files are actually published under their basenames, and the selected UCSC
genome matches the BigWig assembly.

### Failed release installation

The stable launcher is promoted only after installation tests. A failed new
version should leave the prior stable launcher intact. Inspect the installation
log and create a corrected versioned release rather than modifying a frozen
environment.
