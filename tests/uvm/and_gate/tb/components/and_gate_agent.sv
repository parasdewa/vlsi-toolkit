class and_gate_agent extends uvm_agent;
    `uvm_component_utils(and_gate_agent)

    and_gate_sequencer sequencer;
    and_gate_driver    driver;
    and_gate_monitor   monitor;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        monitor = and_gate_monitor::type_id::create("monitor", this);

        if (is_active == UVM_ACTIVE) begin
            sequencer = and_gate_sequencer::type_id::create(
                "sequencer", this);
            driver = and_gate_driver::type_id::create("driver", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        if (is_active == UVM_ACTIVE) begin
            driver.seq_item_port.connect(sequencer.seq_item_export);
        end
    endfunction
endclass
