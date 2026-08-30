from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class RepositoryContractTests(unittest.TestCase):
    def test_version_and_citation_use_new_identity(self):
        self.assertEqual((ROOT / "VERSION").read_text().strip(), "6.0.0-alpha.1.post1")
        citation = (ROOT / "CITATION.cff").read_text(encoding="utf-8")
        self.assertIn("MichalGd/rnaseq2tracks", citation)
        self.assertNotIn("rnaseq2tracksP", citation)

    def test_launcher_requires_config_option(self):
        script = (ROOT / "scripts" / "rnaseq2tracks.sh").read_text(encoding="utf-8")
        self.assertIn("Usage: rnaseq2tracks --config FILE", script)
        self.assertIn("--config)", script)
        self.assertNotIn("conda activate", script)

    def test_templates_use_lane_hierarchy(self):
        for name in ("samplesheet_template_SE.csv", "samplesheet_template_PE.csv"):
            header = (ROOT / "config" / name).read_text(encoding="utf-8").splitlines()[0]
            for field in (
                "sample_id", "biological_replicate_id", "technical_replicate_id",
                "lane_id", "fastq_R1", "condition", "strandedness",
            ):
                self.assertIn(field, header.split(","))

    def test_config_owns_samplesheet_path(self):
        config = (ROOT / "config" / "config_template.conf").read_text(encoding="utf-8")
        self.assertIn('SAMPLESHEET="samplesheet.csv"', config)
        self.assertIn('RUN_ENRICHMENT="true"', config)
        active = [line for line in config.splitlines() if not line.lstrip().startswith("#")]
        self.assertFalse(any(line.startswith("CONTRASTS=") for line in active))

    def test_strand_check_reads_named_samplesheet_columns(self):
        script = (ROOT / "scripts" / "check_strand_consistency.sh").read_text(
            encoding="utf-8"
        )
        self.assertIn('required = {"sample_id", "strandedness"}', script)
        self.assertNotIn('STRAND+=("$f6")', script)

    def test_star_resume_accepts_complete_staged_lane_outputs(self):
        script = (ROOT / "scripts" / "rnaseq2tracks.sh").read_text(encoding="utf-8")
        self.assertIn("complete staged STAR outputs exist from an interrupted run", script)
        self.assertIn("_staged_counts=", script)

    def test_installer_makes_all_shell_helpers_executable(self):
        installer = (ROOT / "scripts" / "bash" / "install_release.sh").read_text(
            encoding="utf-8"
        )
        self.assertIn("find \"$WORKFLOW_ROOT/scripts\" -type f -name '*.sh'", installer)


if __name__ == "__main__":
    unittest.main()
