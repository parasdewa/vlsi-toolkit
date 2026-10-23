class and_gate_item extends uvm_sequence_item;
    rand bit a;
    rand bit b;
    bit y;

    `uvm_object_utils(and_gate_item)

    function new(string name = "and_gate_item");
        super.new(name);
    endfunction
endclass
