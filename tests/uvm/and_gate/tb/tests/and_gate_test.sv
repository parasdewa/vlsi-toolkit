class and_gate_test extends uvm_test;
    `uvm_component_utils(and_gate_test)

    and_gate_env env;
    virtual and_gate_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(virtual and_gate_if)::get(
                this, "", "vif", vif)) begin
            `uvm_fatal("NOVIF", "Top-level virtual interface not configured")
        end

        uvm_config_db#(virtual and_gate_if)::set(
            this, "env.agent.*", "vif", vif);

        env = and_gate_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        and_gate_sequence seq;

        phase.raise_objection(this);

        seq = and_gate_sequence::type_id::create("seq");
        seq.start(env.agent.sequencer);

        // Allow the last driven transaction to reach the monitor.
        #2;
        phase.drop_objection(this);
    endtask
endclass
