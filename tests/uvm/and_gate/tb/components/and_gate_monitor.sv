class and_gate_monitor extends uvm_monitor;
    `uvm_component_utils(and_gate_monitor)

    virtual and_gate_if vif;
    uvm_analysis_port #(and_gate_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(virtual and_gate_if)::get(
                this, "", "vif", vif)) begin
            `uvm_fatal("NOVIF", "Virtual interface not configured")
        end
    endfunction

    task run_phase(uvm_phase phase);
        and_gate_item item;

        forever begin
            wait (vif.txn_valid == 1);

            item = and_gate_item::type_id::create("item");
            item.a = vif.a;
            item.b = vif.b;
            item.y = vif.y;

            ap.write(item);

            `uvm_info("MON",
                      $sformatf("Observed a=%0b b=%0b y=%0b",
                                item.a, item.b, item.y),
                      UVM_MEDIUM)

            wait (vif.txn_valid == 0);
        end
    endtask
endclass
