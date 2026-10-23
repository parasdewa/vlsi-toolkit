module counter_tb;
    logic clk = 0;
    logic reset_n = 0;
    logic [3:0] count;

    counter #(.WIDTH(4)) dut (
        .clk(clk),
        .reset_n(reset_n),
        .count(count)
    );

    always #5 clk = ~clk;

`ifdef VLSI_WAVEFORM
    string waveform_file;
    initial begin
        if (!$value$plusargs("VLSI_WAVEFORM=%s", waveform_file))
            waveform_file = "waveform.vcd";
        $dumpfile(waveform_file);
        $dumpvars(0, counter_tb);
    end
`endif

    initial begin
        repeat (2) @(posedge clk);
        #1;
        if (count !== 4'd0)
            $fatal(1, "reset failed: count=%0d", count);

        reset_n = 1;
        repeat (5) @(posedge clk);
        #1;
        if (count !== 4'd5)
            $fatal(1, "count failed: expected 5, got %0d", count);

        $display("COUNTER_TEST_PASSED count=%0d", count);
        $finish;
    end
endmodule
