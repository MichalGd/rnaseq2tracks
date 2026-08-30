from __future__ import annotations

import csv
import importlib.util
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def load(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


samplesheet = load("prepare_samplesheet", ROOT / "scripts" / "prepare_samplesheet.py")
merge_counts = load("merge_star_counts", ROOT / "scripts" / "merge_star_counts.py")


class SamplesheetTests(unittest.TestCase):
    def test_two_lanes_collapse_to_one_biological_sample(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ("a.fq.gz", "b.fq.gz", "c.fq.gz"):
                (root / name).write_bytes(b"test")
            sheet = root / "samples.csv"
            sheet.write_text(
                "sample_id,biological_replicate_id,technical_replicate_id,lane_id,fastq_R1,condition,strandedness\n"
                "CTRL_1,R1,T1,L001,a.fq.gz,control,reverse\n"
                "CTRL_1,R1,T1,L002,b.fq.gz,control,reverse\n"
                "TREAT_1,R1,T1,L001,c.fq.gz,treated,reverse\n",
                encoding="utf-8",
            )
            lanes, biological = samplesheet.validate(sheet, "SE", True)
            self.assertEqual(len(lanes), 3)
            self.assertEqual(len(biological), 2)
            self.assertEqual(biological[0]["lane_count"], "2")
            self.assertEqual(lanes[0]["library_id"], "CTRL_1__T1__L001")

    def test_inconsistent_sample_metadata_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "a.fq.gz").write_bytes(b"x")
            (root / "b.fq.gz").write_bytes(b"x")
            sheet = root / "samples.csv"
            sheet.write_text(
                "sample_id,biological_replicate_id,technical_replicate_id,lane_id,fastq_R1,condition,strandedness\n"
                "S1,R1,T1,L001,a.fq.gz,control,reverse\n"
                "S1,R1,T1,L002,b.fq.gz,treated,reverse\n",
                encoding="utf-8",
            )
            with self.assertRaisesRegex(samplesheet.SamplesheetError, "condition differs"):
                samplesheet.validate(sheet, "SE", True)

    def test_duplicate_fastq_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "a.fq.gz").write_bytes(b"x")
            sheet = root / "samples.csv"
            sheet.write_text(
                "sample_id,biological_replicate_id,technical_replicate_id,lane_id,fastq_R1,condition,strandedness\n"
                "S1,R1,T1,L001,a.fq.gz,control,reverse\n"
                "S2,R2,T1,L001,a.fq.gz,control,reverse\n",
                encoding="utf-8",
            )
            with self.assertRaisesRegex(samplesheet.SamplesheetError, "assigned more than once"):
                samplesheet.validate(sheet, "SE", True)


class MergeCountsTests(unittest.TestCase):
    def test_lane_counts_are_summed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            counts = root / "counts"
            output = root / "output"
            counts.mkdir()
            lanes = root / "lanes.tsv"
            with lanes.open("w", encoding="utf-8", newline="") as handle:
                writer = csv.DictWriter(handle, fieldnames=["library_id", "sample_id"], delimiter="\t")
                writer.writeheader()
                writer.writerow({"library_id": "S1__T1__L001", "sample_id": "S1"})
                writer.writerow({"library_id": "S1__T1__L002", "sample_id": "S1"})
            (counts / "S1__T1__L001_ReadsPerGene.out.tab").write_text(
                "N_unmapped\t1\t2\t3\ngeneA\t4\t5\t6\n", encoding="utf-8"
            )
            (counts / "S1__T1__L002_ReadsPerGene.out.tab").write_text(
                "N_unmapped\t10\t20\t30\ngeneA\t40\t50\t60\n", encoding="utf-8"
            )
            original = __import__("sys").argv
            try:
                __import__("sys").argv = [
                    "merge_star_counts.py", "--lanes", str(lanes), "--count-dir", str(counts),
                    "--output-dir", str(output),
                ]
                self.assertEqual(merge_counts.main(), 0)
            finally:
                __import__("sys").argv = original
            self.assertEqual(
                (output / "S1_ReadsPerGene.out.tab").read_text(encoding="utf-8"),
                "N_unmapped\t11\t22\t33\ngeneA\t44\t55\t66\n",
            )


if __name__ == "__main__":
    unittest.main()
