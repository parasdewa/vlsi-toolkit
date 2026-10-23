module and_gate_tb_top;
    import uvm_pkg::*;
    import and_gate_pkg::*;

    and_gate_if vif();

    and_gate dut (
        .a(vif.a),
        .b(vif.b),
        .y(vif.y)
    );

    initial begin
        vif.a = 0;
        vif.b = 0;
        vif.txn_valid = 0;

        uvm_config_db#(virtual and_gate_if)::set(
            null, "uvm_test_top", "vif", vif);

        run_test("and_gate_test");
    end

    initial begin
        $dumpfile("build/and_gate_uvm.vcd");
        $dumpvars(0, and_gate_tb_top);
    end
endmodule
