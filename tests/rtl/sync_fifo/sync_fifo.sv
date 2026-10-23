module sync_fifo #(
    parameter integer WIDTH = 8,
    parameter integer DEPTH = 4,
    parameter integer PTR_WIDTH = (DEPTH < 2) ? 1 : $clog2(DEPTH),
    parameter integer COUNT_WIDTH = (DEPTH < 2) ? 1 : $clog2(DEPTH + 1)
) (
    input  logic                 clk,
    input  logic                 reset_n,
    input  logic                 push,
    input  logic                 pop,
    input  logic [WIDTH-1:0]     data_in,
    output logic [WIDTH-1:0]     data_out,
    output logic                 full,
    output logic                 empty
);
    logic [WIDTH-1:0] storage [0:DEPTH-1];
    logic [PTR_WIDTH-1:0] write_ptr;
    logic [PTR_WIDTH-1:0] read_ptr;
    logic [COUNT_WIDTH-1:0] count;
    localparam logic [PTR_WIDTH-1:0] LAST_PTR = PTR_WIDTH'(DEPTH - 1);
    localparam logic [COUNT_WIDTH-1:0] DEPTH_COUNT = COUNT_WIDTH'(DEPTH);

    assign full = (count == DEPTH_COUNT);
    assign empty = (count == 0);
    assign data_out = storage[read_ptr];

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            write_ptr <= '0;
            read_ptr <= '0;
            count <= '0;
        end else begin
            if (push && !full) begin
                storage[write_ptr] <= data_in;
                if (write_ptr == LAST_PTR)
                    write_ptr <= '0;
                else
                    write_ptr <= write_ptr + 1'b1;
            end

            if (pop && !empty) begin
                if (read_ptr == LAST_PTR)
                    read_ptr <= '0;
                else
                    read_ptr <= read_ptr + 1'b1;
            end

            case ({push && !full, pop && !empty})
                2'b10: count <= count + 1'b1;
                2'b01: count <= count - 1'b1;
                default: count <= count;
            endcase
        end
    end
endmodule
