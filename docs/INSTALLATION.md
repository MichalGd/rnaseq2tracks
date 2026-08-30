# Shared-server installation

This page is for administrators. Ordinary users should follow
[QUICK_START.md](QUICK_START.md) and should not activate Conda.

## Release model

Each Git tag is installed into a new versioned environment. The installer writes
a self-contained versioned launcher and promotes a stable symlink only after
tests pass. Existing versioned environments remain rollback targets and are not
modified in place.

Current validated release:

```text
v6.0.0-alpha.1.post1
```

## Install a tagged release

From an appropriate checkout/staging directory:

```bash
bash scripts/bash/install_release.sh \
  --tag v6.0.0-alpha.1.post1 \
  --repo https://github.com/MichalGd/rnaseq2tracks.git \
  --env-parent /opt/conda_envs \
  --bin-dir /opt/conda_envs/bin \
  --mamba /opt/miniconda/condabin/mamba
```

Defaults are the repository URL and shared `/opt/conda_envs` layout shown above.
Use `--no-promote` to install/test without changing the stable launcher.

The installer checks tag/version agreement, creates the environment, installs
the workflow, runs Python tests, Bash syntax checks, and R parsing, exports an
explicit environment specification, freezes the target read-only, writes a
self-contained launcher, and then promotes the stable link.

## Launcher chain

A typical installation provides:

```text
/opt/conda_envs/rnaseq2tracks-6.0.0a1.post1/
/opt/conda_envs/bin/rnaseq2tracks-6.0.0-alpha.1.post1
/opt/conda_envs/bin/rnaseq2tracks
/usr/local/bin/rnaseq2tracks
```

The system link is site-managed and should point to the stable shared launcher.
The versioned launcher sets its environment `PATH` and clears inherited Python/R
library overrides. Users do not run `conda activate`.

## Clean-shell validation

```bash
env -i \
  HOME="$HOME" \
  USER="$USER" \
  PATH="/usr/local/bin:/usr/bin:/bin" \
  bash --noprofile --norc -c '
    set -e
    command -v rnaseq2tracks
    rnaseq2tracks --version
    rnaseq2tracks --help
  '
```

Expected current version:

```text
6.0.0-alpha.1.post1
```

## External reference resources

The software environment does not duplicate large project/site references:

- STAR indexes;
- GTF annotations;
- chromosome-size files;
- RSeQC BED12 annotations;
- FastQ Screen Bowtie2 indexes/configuration;
- Kent utilities if not otherwise supplied at the configured path.

Audit their readability, provenance, assembly, contig naming, and compatibility,
then place paths in each project config. Installation success alone does not
validate a reference combination.

## Acceptance before production

At minimum:

1. confirm clean-shell launcher/version;
2. confirm all installed tests passed;
3. validate SE and PE samplesheet templates;
4. run a small species-appropriate FastQ Screen canary;
5. run a small real-read STAR/merge/track canary for each supported assembly and
   layout used at the site;
6. verify RSeQC with the deployed BED12 annotation;
7. render a small DE/enrichment/report smoke project;
8. confirm world readability/traversability and read-only versioned content.

## Rollback

Repoint the stable launcher atomically to a previously validated versioned
launcher. Do not edit an immutable environment or delete it while a running job
or project record may reference it.

Promotion affects future invocations only. An active process continues using the
environment and absolute executables with which it started.
