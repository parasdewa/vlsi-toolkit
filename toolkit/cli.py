"""Command line interface for the VLSI toolkit."""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

try:
    import tomllib
except ModuleNotFoundError:  # Python 3.10 on Ubuntu 22.04 uses the packaged tomli module.
    import tomli as tomllib

from . import __version__
from .runners.iverilog import run_iverilog
from .runners.liberty import check_liberty
from .runners.opensta import run_opensta
from .runners.verilator import run_verilator
from .runners.yosys import run_yosys


REPO_ROOT = Path(__file__).resolve().parents[1]
TOOL_VERSIONS = (
    ("iverilog", ("-V",)),
    ("vvp", ("-V",)),
    ("verilator", ("--version",)),
    ("yosys", ("-V",)),
    ("sta", ("-version",)),
    ("gtkwave", None),
)
DEFINE_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*(?:=.*)?$")
TOP_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_$]*$")


def _add_run_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--config", type=Path, help="TOML project configuration file")
    parser.add_argument("--sim", choices=("iverilog", "verilator"),
                        help="override the simulator selected in the config")
    parser.add_argument("--project", type=Path,
                        help="Project root; relative source paths are resolved from here")
    parser.add_argument("--top", help="Simulation top module")
    parser.add_argument("--rtl", action="append", default=None, metavar="FILE",
                        help="RTL source file (repeat for multiple files)")
    parser.add_argument("--tb", action="append", default=None, metavar="FILE",
                        help="Testbench source file (repeat as needed)")
    parser.add_argument("--include", action="append", default=None, metavar="DIR",
                        help="Include directory (repeat as needed)")
    parser.add_argument("--define", action="append", default=None, metavar="NAME[=VALUE]",
                        help="Preprocessor definition (repeat as needed)")
    parser.add_argument("--sim-arg", action="append", default=None, metavar="ARG",
                        help="Argument passed to the simulator executable (repeat as needed)")
    parser.add_argument("--waveform", action=argparse.BooleanOptionalAction, default=None,
                        help="write build/<project>/<top>/waveform.vcd (testbench must support VLSI_WAVEFORM)")
    parser.add_argument("--waveform-file", type=Path,
                        help="custom VCD path (relative paths are resolved from the build directory)")
    parser.add_argument("--jobs", type=int, choices=(1, 2),
                        help="Verilator build jobs (default: 1; maximum: 2)")
    parser.add_argument("--uvm", action=argparse.BooleanOptionalAction, default=None,
                        help="compile with Verilator's UVM 2020.3.2 package (Verilator only)")
    parser.add_argument("--uvm-dir", type=Path,
                        help="directory containing uvm_pkg_all_v2020_3_2_nodpi.svh")
    parser.add_argument("--build-dir", type=Path,
                        help="Build output directory (default: toolkit/build/<project>/<top>)")


def _resolve_project_paths(project: Path, entries: list[str], label: str) -> list[Path]:
    resolved = []
    for entry in entries:
        path = Path(entry).expanduser()
        path = (project / path).resolve() if not path.is_absolute() else path.resolve()
        if not path.exists():
            raise ValueError(f"{label} does not exist: {path}")
        if label == "source file" and not path.is_file():
            raise ValueError(f"{label} is not a file: {path}")
        if label == "include directory" and not path.is_dir():
            raise ValueError(f"{label} is not a directory: {path}")
        resolved.append(path)
    return resolved


def _resolve_optional_project_file(
    project: Path, value, setting: str, section: str = "synth"
) -> Path | None:
    if value is None:
        return None
    if not isinstance(value, (str, Path)):
        raise ValueError(f"{section} {setting} must be a file path string")
    path = Path(value).expanduser()
    path = (project / path).resolve() if not path.is_absolute() else path.resolve()
    if not path.is_file():
        raise ValueError(f"{section} {setting} file does not exist or is not a file: {path}")
    return path


def _load_config(config_path: Path | None, section: str) -> tuple[dict, Path | None]:
    if config_path is None:
        return {}, None
    config_path = config_path.expanduser().resolve()
    if not config_path.is_file():
        raise ValueError(f"configuration file does not exist: {config_path}")
    try:
        config = tomllib.loads(config_path.read_text(encoding="utf-8"))
    except tomllib.TOMLDecodeError as exc:
        raise ValueError(f"invalid TOML configuration {config_path}: {exc}") from exc

    if not isinstance(config, dict):
        raise ValueError("configuration root must be a TOML table")
    allowed_root = {"project", "run", "synth", "timing"}
    unknown_root = set(config) - allowed_root
    if unknown_root:
        raise ValueError(f"unknown configuration section(s): {', '.join(sorted(unknown_root))}")
    project_settings = config.get("project", {})
    if not isinstance(project_settings, dict):
        raise ValueError("[project] must be a TOML table")
    unknown_project = set(project_settings) - {"root"}
    if unknown_project:
        raise ValueError(f"unknown [project] key(s): {', '.join(sorted(unknown_project))}")
    project_root = project_settings.get("root", ".")
    if not isinstance(project_root, str):
        raise ValueError("[project].root must be a string path")
    project_path = Path(project_root).expanduser()
    project_path = (config_path.parent / project_path).resolve() if not project_path.is_absolute() else project_path.resolve()

    settings = config.get(section)
    if not isinstance(settings, dict):
        raise ValueError(f"configuration must contain a [{section}] table")
    common_keys = {"top", "rtl", "include", "defines", "build_dir"}
    if section == "run":
        section_keys = common_keys | {
            "sim", "tb", "sim_args", "waveform", "waveform_file", "jobs", "uvm", "uvm_dir"
        }
    elif section == "synth":
        section_keys = common_keys | {"liberty", "abc_constraints", "delay_ps"}
    else:
        section_keys = {"top", "netlist", "liberty", "sdc", "spef", "build_dir"}
    unknown_settings = set(settings) - section_keys
    if unknown_settings:
        raise ValueError(f"unknown [{section}] key(s): {', '.join(sorted(unknown_settings))}")
    return settings, project_path


def _selected(cli_value, settings: dict, key: str, default):
    return cli_value if cli_value is not None else settings.get(key, default)


def _project_and_settings(args: argparse.Namespace, section: str) -> tuple[Path, dict]:
    settings, configured_project = _load_config(args.config, section)
    if args.project is not None:
        project = args.project.expanduser().resolve()
    elif configured_project is not None:
        project = configured_project
    else:
        raise ValueError("--project or --config is required")
    if not project.is_dir():
        raise ValueError(f"project directory does not exist: {project}")
    return project, settings


def _doctor() -> int:
    print(f"VLSI toolkit {__version__}")
    missing = []
    for tool, version_args in TOOL_VERSIONS:
        executable = shutil.which(tool)
        if executable is None:
            print(f"MISSING  {tool}")
            missing.append(tool)
            continue
        if version_args is None:
            print(f"FOUND    {tool}: available ({executable}); GUI launch not checked")
            continue
        try:
            result = subprocess.run(
                [executable, *version_args], text=True, stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT, timeout=5, check=False,
            )
            if result.returncode:
                version = f"version check unavailable (exit {result.returncode})"
            else:
                version = next((line.strip() for line in result.stdout.splitlines() if line.strip()), "version unavailable")
        except (OSError, subprocess.TimeoutExpired):
            version = "version check failed"
        if tool == "verilator":
            match = re.search(r"Verilator (\d+)\.(\d+)", version)
            if match and tuple(map(int, match.groups())) < (5, 52):
                print(f"UNSUPPORTED  {tool}: {version}; UVM requires 5.052 or newer ({executable})")
                missing.append(tool)
                continue
        print(f"FOUND    {tool}: {version} ({executable})")
    if missing:
        apt_packages = sorted({
            {"iverilog": "iverilog", "vvp": "iverilog", "yosys": "yosys", "gtkwave": "gtkwave"}.get(tool, tool)
            for tool in missing if tool not in ("verilator", "sta")
        })
        if apt_packages:
            print("Install missing Ubuntu tools with:")
            print("  sudo apt-get update && sudo apt-get install -y " + " ".join(apt_packages))
        if "sta" in missing:
            print("OpenSTA is required for 'vlsi timing'; see docs/TIMING_ANALYSIS.md for the upstream build instructions.")
        if "verilator" in missing:
            print("For the toolkit's supported Verilator/UVM version, run:")
            print("  scripts/tool_setup_and_check.sh")
        return 1
    return 0


def _clean(project: Path | None = None, *, dry_run: bool = False) -> int:
    """Remove generated output directories and logs under the selected project."""
    root = Path.cwd() if project is None else project.expanduser()
    if not root.is_absolute():
        root = Path.cwd() / root
    root = root.resolve()
    if not root.is_dir():
        raise ValueError(f"clean project directory does not exist: {root}")

    targets = (root / "build", root / "logs", root / "log")
    found = [path for path in targets if path.exists() or path.is_symlink()]
    if not found:
        print(f"Nothing to clean (no build or log outputs found under {root}).")
        return 0

    for path in found:
        if dry_run:
            print(f"Would remove: {path}")
        else:
            if path.is_dir() and not path.is_symlink():
                shutil.rmtree(path)
            else:
                path.unlink()
            print(f"Removed: {path}")
    if dry_run:
        print("Dry run only; no files were removed.")
    return 0


def _resolve_uvm_dir(requested: Path | None, project: Path, config_value: bool = False) -> Path:
    candidates: list[Path] = []
    if requested is not None:
        candidate = requested.expanduser()
        if config_value and not candidate.is_absolute():
            candidate = project / candidate
        candidates.append(candidate.resolve())
    if os.environ.get("VERILATOR_UVM_DIR"):
        candidates.append(Path(os.environ["VERILATOR_UVM_DIR"]).expanduser().resolve())
    if os.environ.get("VERILATOR_ROOT"):
        candidates.append((Path(os.environ["VERILATOR_ROOT"]) / "test_regress" / "t" / "uvm").resolve())
    verilator = shutil.which("verilator")
    if verilator:
        root = Path(verilator).resolve().parent.parent
        candidates.append(root / "test_regress" / "t" / "uvm")
    package_name = "uvm_pkg_all_v2020_3_2_nodpi.svh"
    for candidate in candidates:
        package = candidate / package_name
        if package.is_file() and "Accellera:1800.2:UVM:2020.3.2" in package.read_text(encoding="utf-8", errors="replace"):
            return candidate.resolve()
    raise ValueError(
        "Verilator UVM 2020.3.2 source was not found. Set VERILATOR_UVM_DIR, "
        "pass --uvm-dir, or run scripts/tool_setup_and_check.sh."
    )


def _check_uvm_verilator_version() -> None:
    executable = shutil.which("verilator")
    if executable is None:
        raise ValueError("UVM runs require Verilator 5.052 or newer; run scripts/tool_setup_and_check.sh.")
    result = subprocess.run([executable, "--version"], text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=5, check=False)
    match = re.search(r"Verilator (\d+)\.(\d+)", result.stdout)
    if result.returncode or not match or tuple(map(int, match.groups())) < (5, 52):
        raise ValueError(
            f"UVM runs require Verilator 5.052 or newer ({result.stdout.strip()}). "
            "Run scripts/tool_setup_and_check.sh."
        )


def _run(args: argparse.Namespace) -> int:
    project, settings = _project_and_settings(args, "run")
    top = _selected(args.top, settings, "top", None)
    if not isinstance(top, str) or not TOP_RE.fullmatch(top):
        raise ValueError(f"invalid or missing simulation top module: {top!r}")

    rtl = _selected(args.rtl, settings, "rtl", None)
    tb = _selected(args.tb, settings, "tb", [])
    includes_value = _selected(args.include, settings, "include", [])
    defines = _selected(args.define, settings, "defines", [])
    sim = _selected(args.sim, settings, "sim", "verilator")
    sim_args = _selected(args.sim_arg, settings, "sim_args", [])
    waveform = _selected(args.waveform, settings, "waveform", False)
    waveform_file = _selected(args.waveform_file, settings, "waveform_file", None)
    jobs = _selected(args.jobs, settings, "jobs", 1)
    uvm = _selected(args.uvm, settings, "uvm", False)
    uvm_dir_value = args.uvm_dir if args.uvm_dir is not None else settings.get("uvm_dir")
    if not isinstance(rtl, list) or not rtl or not all(isinstance(item, str) for item in rtl):
        raise ValueError("run configuration must provide a non-empty rtl list")
    for key, entries in (("tb", tb), ("include", includes_value), ("defines", defines), ("sim_args", sim_args)):
        if not isinstance(entries, list) or not all(isinstance(item, str) for item in entries):
            raise ValueError(f"run {key} must be a list of strings")
    if sim not in ("iverilog", "verilator"):
        raise ValueError(f"unsupported simulator: {sim!r}")
    if not isinstance(uvm, bool):
        raise ValueError("run uvm must be a boolean")
    if uvm and sim != "verilator":
        raise ValueError("UVM is supported with Verilator only; use --sim verilator")
    if uvm_dir_value is not None and not isinstance(uvm_dir_value, (str, Path)):
        raise ValueError("run uvm_dir must be a path string")
    if uvm_dir_value is not None and not uvm:
        raise ValueError("uvm_dir requires uvm = true or --uvm")
    if not isinstance(waveform, bool):
        raise ValueError("run waveform must be a boolean")
    if waveform_file is not None and not isinstance(waveform_file, (str, Path)):
        raise ValueError("run waveform_file must be a path string")
    if args.waveform is False and args.waveform_file is not None:
        raise ValueError("--waveform-file cannot be combined with --no-waveform")
    if type(jobs) is not int or jobs not in (1, 2):
        raise ValueError("Verilator jobs must be 1 or 2")

    sources = _resolve_project_paths(project, rtl + tb, "source file")
    includes = _resolve_project_paths(project, includes_value, "include directory")
    for define in defines:
        if not DEFINE_RE.fullmatch(define):
            raise ValueError(f"invalid preprocessor definition: {define!r}")

    build_value = args.build_dir if args.build_dir is not None else settings.get("build_dir")
    if build_value is not None:
        if not isinstance(build_value, (str, Path)):
            raise ValueError("run build_dir must be a path string")
        build_path = Path(build_value).expanduser()
        build_dir = (project / build_path).resolve() if not build_path.is_absolute() and args.build_dir is None else build_path.resolve()
    else:
        project_key = re.sub(r"[^A-Za-z0-9_.-]+", "_", project.name) or "project"
        top_key = re.sub(r"[^A-Za-z0-9_.-]+", "_", top) or "top"
        build_dir = REPO_ROOT / "build" / project_key / top_key

    if args.waveform is False:
        waveform_path = None
    elif waveform_file is not None:
        waveform = True
        waveform_path = Path(waveform_file).expanduser()
        waveform_path = (build_dir / waveform_path).resolve() if not waveform_path.is_absolute() else waveform_path.resolve()
    elif waveform:
        waveform_path = build_dir / "waveform.vcd"
    else:
        waveform_path = None

    runner = run_iverilog if sim == "iverilog" else run_verilator
    uvm_dir = None
    if uvm:
        _check_uvm_verilator_version()
        requested_uvm_dir = Path(uvm_dir_value) if uvm_dir_value is not None else None
        uvm_dir = _resolve_uvm_dir(
            requested_uvm_dir, project,
            config_value=args.uvm_dir is None and uvm_dir_value is not None,
        )
    runner_args = dict(
        project=project,
        top=top,
        sources=sources,
        include_dirs=includes,
        defines=defines,
        sim_args=sim_args,
        build_dir=build_dir,
        waveform_path=waveform_path,
    )
    if sim == "verilator":
        runner_args["jobs"] = jobs
        runner_args["uvm_dir"] = uvm_dir
    return runner(**runner_args)


def _synth(args: argparse.Namespace) -> int:
    project, settings = _project_and_settings(args, "synth")
    top = _selected(args.top, settings, "top", None)
    if not isinstance(top, str) or not TOP_RE.fullmatch(top):
        raise ValueError(f"invalid or missing synthesis top module: {top!r}")

    rtl = _selected(args.rtl, settings, "rtl", None)
    includes_value = _selected(args.include, settings, "include", [])
    defines = _selected(args.define, settings, "defines", [])
    liberty_value = _selected(args.liberty, settings, "liberty", None)
    constraints_value = _selected(args.abc_constraints, settings, "abc_constraints", None)
    delay_ps = _selected(args.delay_ps, settings, "delay_ps", None)
    if not isinstance(rtl, list) or not rtl or not all(isinstance(item, str) for item in rtl):
        raise ValueError("synth configuration must provide a non-empty rtl list")
    for key, entries in (("include", includes_value), ("defines", defines)):
        if not isinstance(entries, list) or not all(isinstance(item, str) for item in entries):
            raise ValueError(f"synth {key} must be a list of strings")

    sources = _resolve_project_paths(project, rtl, "source file")
    includes = _resolve_project_paths(project, includes_value, "include directory")
    liberty = _resolve_optional_project_file(project, liberty_value, "liberty")
    abc_constraints = _resolve_optional_project_file(project, constraints_value, "abc_constraints")
    if abc_constraints is not None and liberty is None:
        raise ValueError("synth abc_constraints requires synth liberty for ABC technology mapping")
    if delay_ps is not None:
        if type(delay_ps) is not int or delay_ps <= 0:
            raise ValueError("synth delay_ps must be a positive integer")
        if liberty is None:
            raise ValueError("synth delay_ps requires synth liberty for ABC technology mapping")
    for define in defines:
        if not DEFINE_RE.fullmatch(define):
            raise ValueError(f"invalid preprocessor definition: {define!r}")

    build_value = args.build_dir if args.build_dir is not None else settings.get("build_dir")
    if build_value is not None:
        if not isinstance(build_value, (str, Path)):
            raise ValueError("synth build_dir must be a path string")
        build_path = Path(build_value).expanduser()
        build_dir = (project / build_path).resolve() if not build_path.is_absolute() and args.build_dir is None else build_path.resolve()
    else:
        project_key = re.sub(r"[^A-Za-z0-9_.-]+", "_", project.name) or "project"
        top_key = re.sub(r"[^A-Za-z0-9_.-]+", "_", top) or "top"
        build_dir = REPO_ROOT / "build" / project_key / top_key / "synthesis"

    return run_yosys(
        project=project,
        top=top,
        sources=sources,
        include_dirs=includes,
        defines=defines,
        build_dir=build_dir,
        liberty=liberty,
        abc_constraints=abc_constraints,
        delay_ps=delay_ps,
    )


def _timing(args: argparse.Namespace) -> int:
    project, settings = _project_and_settings(args, "timing")
    top = _selected(args.top, settings, "top", None)
    if not isinstance(top, str) or not TOP_RE.fullmatch(top):
        raise ValueError(f"invalid or missing timing top module: {top!r}")

    netlist_value = _selected(args.netlist, settings, "netlist", None)
    liberty_value = _selected(args.liberty, settings, "liberty", None)
    sdc_value = _selected(args.sdc, settings, "sdc", None)
    spef_value = _selected(args.spef, settings, "spef", None)
    netlist = _resolve_optional_project_file(project, netlist_value, "netlist", "timing")
    liberty = _resolve_optional_project_file(project, liberty_value, "liberty", "timing")
    sdc = _resolve_optional_project_file(project, sdc_value, "sdc", "timing")
    spef = _resolve_optional_project_file(project, spef_value, "spef", "timing")
    required_missing = [name for name, value in (("netlist", netlist), ("liberty", liberty), ("sdc", sdc)) if value is None]
    if required_missing:
        raise ValueError("timing configuration requires: " + ", ".join(required_missing))

    build_value = args.build_dir if args.build_dir is not None else settings.get("build_dir", "build/timing")
    if not isinstance(build_value, (str, Path)):
        raise ValueError("timing build_dir must be a path string")
    build_path = Path(build_value).expanduser()
    build_dir = (project / build_path).resolve() if not build_path.is_absolute() and args.build_dir is None else build_path.resolve()

    return run_opensta(
        project=project,
        top=top,
        netlist=netlist,
        liberty=liberty,
        sdc=sdc,
        spef=spef,
        build_dir=build_dir,
    )


def _library_check(args: argparse.Namespace) -> int:
    liberty = args.liberty.expanduser().resolve()
    if not liberty.is_file():
        raise ValueError(f"Liberty file does not exist or is not a file: {liberty}")
    if args.build_dir is None:
        build_dir = Path.cwd() / "build" / "liberty_check" / liberty.stem
    else:
        build_dir = args.build_dir.expanduser()
        if not build_dir.is_absolute():
            build_dir = Path.cwd() / build_dir
    return check_liberty(liberty=liberty, build_dir=build_dir.resolve())


def _add_synth_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--config", type=Path, help="TOML project configuration file")
    parser.add_argument("--project", type=Path,
                        help="Project root; relative source paths are resolved from here")
    parser.add_argument("--top", help="Synthesizable top module")
    parser.add_argument("--rtl", action="append", default=None, metavar="FILE",
                        help="RTL source file (repeat for multiple files; testbench files are omitted)")
    parser.add_argument("--include", action="append", default=None, metavar="DIR",
                        help="Include directory (repeat as needed)")
    parser.add_argument("--define", action="append", default=None, metavar="NAME[=VALUE]",
                        help="Preprocessor definition (repeat as needed)")
    parser.add_argument("--liberty", type=Path,
                        help="Liberty cell library for technology mapping")
    parser.add_argument("--abc-constraints", type=Path,
                        help="Yosys ABC input-drive/output-load constraints file (requires --liberty)")
    parser.add_argument("--delay-ps", type=int,
                        help="ABC delay target in picoseconds (requires --liberty)")
    parser.add_argument("--build-dir", type=Path,
                        help="Synthesis output directory (default: build/<project>/<top>/synthesis)")


def _add_timing_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--config", type=Path, help="TOML project configuration file")
    parser.add_argument("--project", type=Path,
                        help="Project root; relative input paths are resolved from here")
    parser.add_argument("--top", help="Top module in the synthesized netlist")
    parser.add_argument("--netlist", type=Path, help="Synthesized gate-level Verilog netlist")
    parser.add_argument("--liberty", type=Path, help="Liberty timing library")
    parser.add_argument("--sdc", type=Path, help="SDC timing constraints file")
    parser.add_argument("--spef", type=Path, help="Optional extracted parasitics file")
    parser.add_argument("--build-dir", type=Path,
                        help="Timing output directory (default: <project>/build/timing)")


def _init_project(path: Path) -> int:
    project = path.expanduser().resolve()
    if project.exists() and any(project.iterdir()):
        raise ValueError(f"refusing to initialize a non-empty directory: {project}")
    project.mkdir(parents=True, exist_ok=True)

    directories = (
        "config",
        "rtl/include",
        "tb/plain",
        "tb/uvm/interfaces",
        "tb/uvm/packages",
        "tb/uvm/agents",
        "tb/uvm/env",
        "tb/uvm/sequences",
        "tb/uvm/tests",
        "tb/uvm/top",
        "constraints/abc",
        "constraints/sdc",
        "scripts",
        "tests/unit",
        "tests/regression",
        "build/sim/plain-verilator",
        "build/sim/plain-iverilog",
        "build/sim/uvm-verilator",
        "build/synth/generic",
        "build/synth/technology",
        "build/timing",
    )
    for relative in directories:
        (project / relative).mkdir(parents=True, exist_ok=True)

    template_scripts = REPO_ROOT / "templates" / "project" / "scripts"
    for source in template_scripts.glob("*.sh"):
        target = project / "scripts" / source.name
        shutil.copy2(source, target)
        target.chmod(target.stat().st_mode | 0o111)
    shutil.copy2(REPO_ROOT / "templates" / "project" / ".gitignore", project / ".gitignore")
    shutil.copy2(
        REPO_ROOT / "templates" / "project" / "initial-start.md",
        project / "initial-start.md",
    )

    print(f"Created project directories, helper scripts, and starter guide: {project}")
    print(f"Read first: {project / 'initial-start.md'}")
    print("Add your project manifests under config/ before running the helpers:")
    print(f"  {project / 'config' / 'plain.toml'}")
    print(f"  {project / 'config' / 'uvm.toml'}")
    print(f"  {project / 'config' / 'synth.toml'}")
    print(f"  {project / 'config' / 'timing.toml'}")
    print(f"Scripts: {project / 'scripts'}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="vlsi", description="Small, direct RTL and verification project tools"
    )
    parser.add_argument("--version", action="version", version=f"vlsi {__version__}")
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("doctor", help="detect supported local EDA tools")
    clean_parser = subparsers.add_parser(
        "clean", help="remove build outputs and logs from a project directory"
    )
    clean_parser.add_argument(
        "--dry-run", action="store_true",
        help="show the project output paths that would be removed",
    )
    clean_parser.add_argument(
        "--project", type=Path, default=None,
        help="project root to clean (default: current working directory)",
    )
    run_parser = subparsers.add_parser("run", help="compile and run an RTL testbench")
    _add_run_arguments(run_parser)
    synth_parser = subparsers.add_parser("synth", help="synthesize RTL with Yosys")
    _add_synth_arguments(synth_parser)
    timing_parser = subparsers.add_parser("timing", help="analyze a synthesized netlist with OpenSTA")
    _add_timing_arguments(timing_parser)
    library_parser = subparsers.add_parser("library", help="validate an explicitly selected Liberty library")
    library_subparsers = library_parser.add_subparsers(dest="library_command", required=True)
    library_check_parser = library_subparsers.add_parser("check", help="parse a Liberty file with OpenSTA")
    library_check_parser.add_argument("--liberty", type=Path, required=True, help="explicit Liberty library path")
    library_check_parser.add_argument(
        "--build-dir", type=Path,
        help="directory for the validation script and log (default: build/liberty_check/<file>)",
    )
    init_parser = subparsers.add_parser(
        "init", help="create an RTL project directory structure and helper scripts"
    )
    init_parser.add_argument("path", type=Path, help="new or empty project directory")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        if args.command == "doctor":
            return _doctor()
        if args.command == "clean":
            return _clean(args.project, dry_run=args.dry_run)
        if args.command == "run":
            return _run(args)
        if args.command == "synth":
            return _synth(args)
        if args.command == "timing":
            return _timing(args)
        if args.command == "library" and args.library_command == "check":
            return _library_check(args)
        if args.command == "init":
            return _init_project(args.path)
    except (OSError, ValueError) as exc:
        print(f"vlsi: error: {exc}", file=sys.stderr)
        return 2
    parser.error(f"unknown command: {args.command}")
    return 2
