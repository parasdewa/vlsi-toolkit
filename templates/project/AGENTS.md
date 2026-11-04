# RTL Project Flow Assistant

Use these project instructions when the user asks to prepare or maintain
simulation, synthesis, timing, or command configuration. They are shared with
Codex and Claude Code; keep the workflow tool-neutral.

## User's ownership boundary

- The user owns RTL, testbench, and constraint file contents.
- Do not create, edit, rename, or delete `.sv`, `.v`, `.vhd`, `.vhdl`, ABC, or
  SDC source files unless the user explicitly asks for that specific change.
- For a flow-setup request, inspect the actual project files first. Update
  manifests and, only when needed, project Makefile/wrapper/documentation files.
- Preserve existing build outputs and logs. Do not clean them unless asked.
- Do not invent a UVM testbench or claim a UVM flow is ready when its sources
  are absent.

## Flow setup procedure

1. Identify each RTL module and the simulation top module from source files.
   Do not assume the filename, design name, RTL top, and testbench top are the
   same. For multi-file RTL, use dependency order in source lists.
2. Create or update one design-named manifest per flow:
   - Directed simulation: `config/simulation/directed/<design>.toml`.
   - UVM simulation, only when the user has UVM sources:
     `config/simulation/uvm/<design>.toml`.
   - Generic synthesis: `config/synthesis/<design>.toml`.
   - Technology mapping and timing: `config/timing/<design>.toml`.
3. Keep synthesizable RTL in synthesis manifests; never include testbench files
   there. Put source paths in compile order and use the existing project-root
   conventions for each config directory.
4. In a timing manifest, keep both `[synth]` and `[timing]` settings together.
   Point the timing `netlist` at the mapped output implied by `[synth]`'s
   `build_dir` and `top`. Use the same explicitly selected Liberty file for
   both sections. Reference the user's existing ABC and SDC files; do not
   invent library paths or timing assumptions.
5. Keep each flow's build directory and waveform filename unique and aligned
   with the Makefile's `DESIGN=<name>` lookup. Prefer the project's Makefile
   commands over long direct CLI invocations.
6. Before reporting completion, parse changed TOML files and inspect Makefile
   dry-run output for the affected commands. Run simulations, synthesis, or
   timing only when the user asks for execution or verification, or when
   needed to finish the specific request.

## Report to the user

State which manifests or command files changed, list the commands to run, and
call out any missing source, library, or constraint input that prevents a flow
from running. Keep RTL and testbench development separate from flow setup.
