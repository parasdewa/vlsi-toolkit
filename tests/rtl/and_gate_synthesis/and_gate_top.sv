`include "and_gate_config.vh"

module and_gate_top (
    input  logic a,
    input  logic b,
    output logic y
);
    logic gate_y;

    and_gate gate (
        .a(a),
        .b(b),
        .y(gate_y)
    );

    assign y = gate_y ^ `AND_GATE_OUTPUT_INVERT;
endmodule
