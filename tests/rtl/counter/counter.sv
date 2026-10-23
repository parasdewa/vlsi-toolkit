module counter #(
    parameter integer WIDTH = 4
) (
    input  logic             clk,
    input  logic             reset_n,
    output logic [WIDTH-1:0] count
);
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            count <= '0;
        else
            count <= count + 1'b1;
    end
endmodule
