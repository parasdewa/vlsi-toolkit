"""Small CLI and local EDA integration checks for the VLSI toolkit."""

from __future__ import annotations

import json
import os
import shlex
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ENTRYPOINT = ROOT / "vlsi"
REGRESSION_ROOT = ROOT / "build" / "regression"
COUNTER_PROJECT = ROOT / "tests" / "rtl" / "counter"
AND_PROJECT = ROOT / "tests" / "rtl" / "and_gate_synthesis"
FIFO_PROJECT = ROOT / "tests" / "rtl" / "sync_fifo"


def find_uvm_source() -> Path | None:
    candidates = []
    if os.environ.get("VERILATOR_UVM_DIR"):
        candidates.append(Path(os.environ["VERILATOR_UVM_DIR"]))
    if os.environ.get("VERILATOR_ROOT"):
        candidates.append(Path(os.environ["VERILATOR_ROOT"]) / "test_regress" / "t" / "uvm")
    verilator = shutil.which("verilator")
    if verilator:
        verilator_root = Path(verilator).resolve().parent.parent
        candidates.append(verilator_root / "test_regress" / "t" / "uvm")
    for candidate in candidates:
        package = candidate / "uvm_pkg_all_v2020_3_2_nodpi.svh"
        if package.is_file() and "Accellera:1800.2:UVM:2020.3.2" in package.read_text(encoding="utf-8", errors="replace"):
            return candidate.resolve()
    return None


class ToolkitCliTests(unittest.TestCase):
    def invoke(self, *arguments: str, timeout: int = 120) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(ENTRYPOINT), *arguments],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout,
            check=False,
        )

    def test_help_lists_commands(self) -> None:
        result = self.invoke("--help")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("init", result.stdout)
        self.assertIn("doctor", result.stdout)
        self.assertIn("run", result.stdout)
        self.assertIn("synth", result.stdout)

    def test_missing_source_is_rejected(self) -> None:
        result = self.invoke(
            "run", "--project", str(COUNTER_PROJECT), "--top", "counter_tb",
            "--rtl", "missing.sv",
        )
        self.assertEqual(result.returncode, 2, result.stdout)
        self.assertIn("source file does not exist", result.stdout)

    @unittest.skipUnless(shutil.which("verilator"), "Verilator is not installed")
    def test_run_defaults_to_verilator_without_manifest(self) -> None:
        REGRESSION_ROOT.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="default-sim-", dir=REGRESSION_ROOT) as output:
            result = self.invoke(
                "run", "--project", str(COUNTER_PROJECT), "--top", "counter_tb",
                "--rtl", "counter.sv", "--tb", "counter_tb.sv", "--build-dir", output,
            )
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertIn("COUNTER_TEST_PASSED count=5", result.stdout)

    @unittest.skipUnless(shutil.which("verilator"), "Verilator is not installed")
    def test_init_creates_verilator_project_by_default(self) -> None:
        REGRESSION_ROOT.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="init-", dir=REGRESSION_ROOT) as output:
            project = Path(output) / "starter"
            initialized = self.invoke("init", str(project))
            self.assertEqual(initialized.returncode, 0, initialized.stdout)
            self.assertTrue((project / "rtl" / "and_gate.sv").is_file())
            self.assertTrue((project / "tb" / "and_gate_tb.sv").is_file())
            self.assertTrue((project / "vlsi.toml").is_file())
            self.assertIn('sim = "verilator"', (project / "vlsi.toml").read_text(encoding="utf-8"))
            generated_readme = (project / "README.md").read_text(encoding="utf-8")
            self.assertIn(shlex.quote(str(project / "vlsi.toml")), generated_readme)

            result = self.invoke("run", "--config", str(project / "vlsi.toml"))
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertIn("AND_GATE_TEST_PASSED", result.stdout)
            self.assertTrue((project / "build" / "run" / "waveforms" / "and_gate.vcd").is_file())

    @unittest.skipUnless(shutil.which("iverilog") and shutil.which("vvp"), "Icarus is not installed")
    def test_init_iverilog_override(self) -> None:
        REGRESSION_ROOT.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="init-iverilog-", dir=REGRESSION_ROOT) as output:
            project = Path(output) / "starter"
            initialized = self.invoke("init", str(project), "--sim", "iverilog")
            self.assertEqual(initialized.returncode, 0, initialized.stdout)
            self.assertIn('sim = "iverilog"', (project / "vlsi.toml").read_text(encoding="utf-8"))
            result = self.invoke("run", "--config", str(project / "vlsi.toml"))
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertIn("AND_GATE_TEST_PASSED", result.stdout)
            self.assertTrue((project / "build" / "run" / "waveforms" / "and_gate.vcd").is_file())

    @unittest.skipUnless(shutil.which("iverilog") and shutil.which("vvp"), "Icarus is not installed")
    def test_counter_project_config_and_cli_override(self) -> None:
        REGRESSION_ROOT.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="config-run-", dir=REGRESSION_ROOT) as output:
            result = self.invoke(
                "run", "--config", str(COUNTER_PROJECT / "vlsi.toml"),
                "--build-dir", output,
            )
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertIn("COUNTER_TEST_PASSED count=5", result.stdout)
            self.assertTrue((Path(output) / "waveforms" / "config_counter.vcd").is_file())

            disabled_output = Path(output) / "disabled"
            disabled = self.invoke(
                "run", "--config", str(COUNTER_PROJECT / "vlsi.toml"),
                "--no-waveform", "--build-dir", str(disabled_output),
            )
            self.assertEqual(disabled.returncode, 0, disabled.stdout)
            self.assertFalse((disabled_output / "waveforms" / "config_counter.vcd").exists())

    @unittest.skipUnless(shutil.which("iverilog") and shutil.which("vvp"), "Icarus is not installed")
    def test_iverilog_counter_and_waveform(self) -> None:
        REGRESSION_ROOT.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="iverilog-", dir=REGRESSION_ROOT) as output:
            result = self.invoke(
                "run", "--sim", "iverilog", "--waveform-file", "traces/custom.vcd",
                "--project", str(COUNTER_PROJECT),
                "--top", "counter_tb", "--rtl", "counter.sv", "--tb", "counter_tb.sv",
                "--build-dir", output,
            )
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertIn("COUNTER_TEST_PASSED count=5", result.stdout)
            waveform = Path(output) / "traces" / "custom.vcd"
            self.assertTrue(waveform.is_file())
            self.assertIn("$var", waveform.read_text(encoding="utf-8"))

    @unittest.skipUnless(shutil.which("verilator"), "Verilator is not installed")
    def test_verilator_counter_and_waveform(self) -> None:
        REGRESSION_ROOT.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="verilator-", dir=REGRESSION_ROOT) as output:
            result = self.invoke(
                "run", "--sim", "verilator", "--jobs", "1",
                "--waveform-file", "traces/verilator.vcd",
                "--project", str(COUNTER_PROJECT), "--top", "counter_tb",
                "--rtl", "counter.sv", "--tb", "counter_tb.sv", "--build-dir", output,
            )
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertIn("COUNTER_TEST_PASSED count=5", result.stdout)
            waveform = Path(output) / "traces" / "verilator.vcd"
            self.assertTrue(waveform.is_file())
            self.assertIn("$var", waveform.read_text(encoding="utf-8"))

    @unittest.skipUnless(shutil.which("verilator") and find_uvm_source(), "Verilator or UVM 2020.3.2 source is unavailable")
    def test_verilator_uvm_and_gate_scoreboard_and_waveform(self) -> None:
        REGRESSION_ROOT.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="uvm-", dir=REGRESSION_ROOT) as output:
            environment = os.environ.copy()
            environment["VERILATOR_UVM_DIR"] = str(find_uvm_source())
            result = subprocess.run(
                [str(ENTRYPOINT), "run", "--sim", "verilator", "--uvm", "--jobs", "1",
                 "--project", str(ROOT / "tests" / "uvm" / "and_gate"),
                 "--top", "and_gate_tb_top", "--rtl", "rtl/and_gate.sv",
                 "--tb", "tb/and_gate_if.sv", "--tb", "tb/and_gate_pkg.sv",
                 "--tb", "tb/and_gate_tb_top.sv", "--include", "tb",
                 "--build-dir", output],
                cwd=ROOT, env=environment, text=True, stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT, timeout=600, check=False,
            )
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertIn("AND_GATE_UVM_SCOREBOARD_PASSED", result.stdout)
            self.assertIn("SCOREBOARD: checked=4 errors=0", result.stdout)
            self.assertRegex(result.stdout, r"UVM_ERROR\s*:\s*0")
            self.assertRegex(result.stdout, r"UVM_FATAL\s*:\s*0")
            waveform = Path(output) / "build" / "and_gate_uvm.vcd"
            self.assertTrue(waveform.is_file(), result.stdout)
            self.assertGreater(waveform.stat().st_size, 0)

    @unittest.skipUnless(
        shutil.which("iverilog") and shutil.which("vvp") and shutil.which("verilator"),
        "Icarus or Verilator is not installed",
    )
    def test_fifo_with_both_simulators(self) -> None:
        REGRESSION_ROOT.mkdir(parents=True, exist_ok=True)
        for simulator in ("iverilog", "verilator"):
            with self.subTest(simulator=simulator):
                with tempfile.TemporaryDirectory(prefix=f"fifo-{simulator}-", dir=REGRESSION_ROOT) as output:
                    result = self.invoke(
                        "run", "--config", str(FIFO_PROJECT / "vlsi.toml"),
                        "--sim", simulator, "--jobs", "1", "--build-dir", output,
                        "--sim-arg", "+FIFO_SEED=D00DFEED",
                        "--sim-arg", "+FIFO_CYCLES=300",
                    )
                    self.assertEqual(result.returncode, 0, result.stdout)
                    self.assertIn("FIFO_TEST_PASSED depth=4 random_cycles=300", result.stdout)
                    self.assertRegex(result.stdout, r"seed=[0-9a-fA-F]{8}")
                    self.assertRegex(
                        result.stdout,
                        r"simultaneous=[1-9][0-9]* rejected_pushes=[1-9][0-9]* rejected_pops=[1-9][0-9]*",
                    )

    @unittest.skipUnless(shutil.which("yosys"), "Yosys is not installed")
    def test_yosys_counter_and_multifile_include(self) -> None:
        REGRESSION_ROOT.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="yosys-counter-", dir=REGRESSION_ROOT) as counter_output:
            counter_result = self.invoke(
                "synth", "--project", str(COUNTER_PROJECT), "--top", "counter",
                "--rtl", "counter.sv", "--build-dir", counter_output,
            )
            self.assertEqual(counter_result.returncode, 0, counter_result.stdout)
            self.assertTrue((Path(counter_output) / "netlist.v").is_file())
            counter_netlist = json.loads((Path(counter_output) / "netlist.json").read_text(encoding="utf-8"))
            self.assertIn("counter", counter_netlist["modules"])
            self.assertIn("Found and reported 0 problems", counter_result.stdout)

        with tempfile.TemporaryDirectory(prefix="yosys-and-", dir=REGRESSION_ROOT) as and_output:
            and_result = self.invoke(
                "synth", "--config", str(AND_PROJECT / "vlsi.toml"),
                "--build-dir", and_output,
            )
            self.assertEqual(and_result.returncode, 0, and_result.stdout)
            self.assertIn("Found and reported 0 problems", and_result.stdout)
            and_netlist = json.loads((Path(and_output) / "netlist.json").read_text(encoding="utf-8"))
            self.assertIn("and_gate_top", and_netlist["modules"])

        with tempfile.TemporaryDirectory(prefix="yosys-fifo-", dir=REGRESSION_ROOT) as fifo_output:
            fifo_result = self.invoke(
                "synth", "--config", str(FIFO_PROJECT / "vlsi.toml"),
                "--build-dir", fifo_output,
            )
            self.assertEqual(fifo_result.returncode, 0, fifo_result.stdout)
            self.assertIn("Found and reported 0 problems", fifo_result.stdout)
            fifo_netlist = json.loads((Path(fifo_output) / "netlist.json").read_text(encoding="utf-8"))
            self.assertIn("sync_fifo", fifo_netlist["modules"])


if __name__ == "__main__":
    unittest.main()
