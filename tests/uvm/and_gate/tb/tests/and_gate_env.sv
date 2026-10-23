class and_gate_env extends uvm_env;
    `uvm_component_utils(and_gate_env)

    and_gate_agent      agent;
    and_gate_scoreboard scoreboard;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        agent = and_gate_agent::type_id::create("agent", this);
        scoreboard = and_gate_scoreboard::type_id::create(
            "scoreboard", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agent.monitor.ap.connect(scoreboard.analysis_export);
    endfunction
endclass
