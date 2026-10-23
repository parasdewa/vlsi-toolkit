class and_gate_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(and_gate_scoreboard)

    uvm_analysis_imp #(and_gate_item, and_gate_scoreboard) analysis_export;

    int unsigned checked;
    int unsigned errors;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        analysis_export = new("analysis_export", this);
        checked = 0;
        errors = 0;
    endfunction

    function void write(and_gate_item item);
        bit expected;
        expected = item.a & item.b;
        checked++;

        if (item.y !== expected) begin
            errors++;
            `uvm_error("SCOREBOARD",
                $sformatf("FAIL a=%0b b=%0b y=%0b expected=%0b",
                          item.a, item.b, item.y, expected))
        end else begin
            `uvm_info("SCOREBOARD",
                $sformatf("PASS a=%0b b=%0b y=%0b",
                          item.a, item.b, item.y), UVM_MEDIUM)
        end
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        $display("SCOREBOARD: checked=%0d errors=%0d", checked, errors);

        if (checked == 0 || errors != 0)
            `uvm_error("SCOREBOARD_SUMMARY", "Scoreboard did not pass")
        else
            $display("AND_GATE_UVM_SCOREBOARD_PASSED");
    endfunction
endclass
