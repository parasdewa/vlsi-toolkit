module uvm_smoke;
  import uvm_pkg::*;

  class smoke_test extends uvm_test;
    `uvm_component_utils(smoke_test)

    function new(string name = "smoke_test",
                 uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void report_phase(uvm_phase phase);
      super.report_phase(phase);
      $display("MY_UVM_SMOKE_TEST_PASSED");
    endfunction
  endclass

  initial begin
    run_test("smoke_test");
  end
endmodule
