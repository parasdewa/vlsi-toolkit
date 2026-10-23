package and_gate_pkg;
    import uvm_pkg::*;

    `include "components/and_gate_item.sv"
    `include "components/and_gate_sequencer.sv"
    `include "seq/and_gate_sequence.sv"
    `include "components/and_gate_driver.sv"
    `include "components/and_gate_monitor.sv"
    `include "components/and_gate_agent.sv"
    `include "components/and_gate_scoreboard.sv"
    `include "tests/and_gate_env.sv"
    `include "tests/and_gate_test.sv"
endpackage
