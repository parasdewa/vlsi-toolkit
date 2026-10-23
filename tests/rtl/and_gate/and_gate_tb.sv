module and_gate_tb;
    logic a;
    logic b;
    logic y;
    logic expected;

    and_gate dut (
        .a(a),
        .b(b),
        .y(y)
    );

    initial begin
        $display("Starting AND gate test");

        for (int i = 0; i < 4; i++) begin
            {a, b} = i[1:0];
            #1;

            expected = a & b;

            if (y !== expected) begin
                $error("FAIL: a=%0b b=%0b y=%0b expected=%0b",
                       a, b, y, expected);
                $fatal(1);
            end else begin
                $display("PASS: a=%0b b=%0b y=%0b",
                         a, b, y);
            end
        end

        $display("AND_GATE_TEST_PASSED");
        $finish;
    end
endmodule
