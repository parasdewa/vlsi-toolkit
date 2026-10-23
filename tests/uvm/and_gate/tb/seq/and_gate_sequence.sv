class and_gate_sequence extends uvm_sequence #(and_gate_item);
    `uvm_object_utils(and_gate_sequence)

    function new(string name = "and_gate_sequence");
        super.new(name);
    endfunction

    task body();
        and_gate_item item;

        for (int i = 0; i < 4; i++) begin
            item = and_gate_item::type_id::create("item");

            start_item(item);
            item.a = (i >> 1) & 1;
            item.b = i & 1;
            finish_item(item);

            `uvm_info("SEQ",
                      $sformatf("Sent a=%0b b=%0b", item.a, item.b),
                      UVM_MEDIUM)
        end
    endtask
endclass
