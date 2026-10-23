class and_gate_driver extends uvm_driver #(and_gate_item);
    `uvm_component_utils(and_gate_driver)

    virtual and_gate_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
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

        vif.txn_valid = 0;

        forever begin
            seq_item_port.get_next_item(item);

            vif.txn_valid = 0;
            vif.a = item.a;
            vif.b = item.b;
            #1;

            vif.txn_valid = 1;
            #1;
            vif.txn_valid = 0;

            `uvm_info("DRV",
                      $sformatf("Drove a=%0b b=%0b",
                                item.a, item.b),
                      UVM_MEDIUM)

            seq_item_port.item_done();
        end
    endtask
endclass
