# Shared server installation

## Release model

Install a signed/approved Git tag into a versioned Conda/Mamba prefix, write a
self-contained launcher and promote a stable symlink. Users then run
`rnaseq2tracks --config ...` without activating Conda.

Prerequisites are a writable environment parent, Mamba, Git and enough storage.
From a checked-out release source:

```bash
bash scripts/bash/install_release.sh --tag v6.0.0-alpha.1.post1
```

Defaults:

- environment parent: `/opt/conda_envs`
- launcher directory: `/opt/conda_envs/bin`
- repository after rename: `https://github.com/MichalGd/rnaseq2tracks.git`
- Mamba: `/opt/miniconda/condabin/mamba`

Override with `--repo`, `--env-parent`, `--bin-dir` or `--mamba`. Use
`--no-promote` to test without changing the stable launcher.

The installer checks tag/version agreement, builds the environment, copies the
workflow, runs Python tests, Bash syntax and R parsing, exports an explicit lock,
freezes the versioned environment read-only and only then promotes the stable
launcher.

## Clean-shell validation

```bash
env -i HOME="$HOME" USER="$USER" PATH="/usr/local/bin:/usr/bin:/bin" \
  bash --noprofile --norc -c '
    command -v rnaseq2tracks
    rnaseq2tracks --version
    rnaseq2tracks --help
  '
```

Site-specific STAR indices, GTFs, chromosome sizes, RSeQC BEDs, FastQ Screen
indices and Kent utilities remain external reference resources and belong in the
project config. They are not silently downloaded by an analysis run.

## Rollback

Versioned launchers remain independent. Repoint the stable symlink atomically to
the previous tested launcher; never modify an immutable environment in place.
