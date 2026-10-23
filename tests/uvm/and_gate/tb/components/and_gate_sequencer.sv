class and_gate_sequencer extends uvm_sequencer #(and_gate_item);
    `uvm_component_utils(and_gate_sequencer)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
endclass
