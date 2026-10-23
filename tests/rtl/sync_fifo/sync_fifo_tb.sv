module sync_fifo_tb;
    logic clk;
    logic reset_n = 0;
    logic push = 0;
    logic pop = 0;
    logic [7:0] data_in = '0;
    logic [7:0] data_out;
    logic full;
    logic empty;
    logic [7:0] model_queue [0:3];
    integer model_head = 0;
    integer model_tail = 0;
    integer model_count = 0;
    integer simultaneous_cycles = 0;
    integer rejected_pushes = 0;
    integer rejected_pops = 0;

    sync_fifo #(.WIDTH(8), .DEPTH(4)) dut (
        .clk(clk),
        .reset_n(reset_n),
        .push(push),
        .pop(pop),
        .data_in(data_in),
        .data_out(data_out),
        .full(full),
        .empty(empty)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    task automatic push_item(input logic [7:0] value);
        begin
            @(negedge clk);
            if (full)
                $fatal(1, "push_item called while FIFO is full");
            data_in = value;
            push = 1;
            @(posedge clk);
            #1;
            push = 0;
        end
    endtask

    task automatic pop_expect(input logic [7:0] expected);
        begin
            @(negedge clk);
            if (empty)
                $fatal(1, "pop_expect called while FIFO is empty");
            if (data_out !== expected)
                $fatal(1, "FIFO order error: expected %02h, got %02h", expected, data_out);
            pop = 1;
            @(posedge clk);
            #1;
            pop = 0;
        end
    endtask

    task automatic replace_head(
        input logic [7:0] expected_head,
        input logic [7:0] replacement
    );
        begin
            @(negedge clk);
            if (empty || full)
                $fatal(1, "replace_head requires a partially filled FIFO");
            if (data_out !== expected_head)
                $fatal(1, "FIFO order error: expected %02h, got %02h", expected_head, data_out);
            data_in = replacement;
            push = 1;
            pop = 1;
            @(posedge clk);
            #1;
            push = 0;
            pop = 0;
        end
    endtask

    task automatic randomized_cycle(
        input logic push_request,
        input logic pop_request,
        input logic [7:0] value
    );
        logic push_accept;
        logic pop_accept;
        begin
            @(negedge clk);
            if (full !== (model_count == 4))
                $fatal(1, "full flag disagrees with reference model");
            if (empty !== (model_count == 0))
                $fatal(1, "empty flag disagrees with reference model");
            if (model_count > 0 && data_out !== model_queue[model_head])
                $fatal(1, "model mismatch before transfer: expected %02h, got %02h",
                       model_queue[model_head], data_out);

            push_accept = push_request && (model_count < 4);
            pop_accept = pop_request && (model_count > 0);
            if (push_request && !push_accept)
                rejected_pushes = rejected_pushes + 1;
            if (pop_request && !pop_accept)
                rejected_pops = rejected_pops + 1;
            if (push_accept && pop_accept)
                simultaneous_cycles = simultaneous_cycles + 1;

            data_in = value;
            push = push_request;
            pop = pop_request;
            @(posedge clk);
            #1;

            if (push_accept) begin
                model_queue[model_tail] = value;
                if (model_tail == 3)
                    model_tail = 0;
                else
                    model_tail = model_tail + 1;
            end
            if (pop_accept) begin
                if (model_head == 3)
                    model_head = 0;
                else
                    model_head = model_head + 1;
            end
            case ({push_accept, pop_accept})
                2'b10: model_count = model_count + 1;
                2'b01: model_count = model_count - 1;
                default: model_count = model_count;
            endcase

            push = 0;
            pop = 0;
            if (full !== (model_count == 4))
                $fatal(1, "full flag disagrees with reference model after transfer");
            if (empty !== (model_count == 0))
                $fatal(1, "empty flag disagrees with reference model after transfer");
            if (model_count > 0 && data_out !== model_queue[model_head])
                $fatal(1, "model mismatch after transfer: expected %02h, got %02h",
                       model_queue[model_head], data_out);
        end
    endtask

    initial begin
        logic [31:0] random_state;
        logic [31:0] random_seed;
        integer random_cycles;

        repeat (2) @(posedge clk);
        @(negedge clk);
        reset_n = 1;
        if (!empty || full)
            $fatal(1, "FIFO reset flags are incorrect");

        push_item(8'h11);
        push_item(8'h22);
        push_item(8'h33);
        push_item(8'h44);
        if (!full || empty)
            $fatal(1, "FIFO did not assert full at capacity");

        @(negedge clk);
        data_in = 8'h55;
        push = 1;
        @(posedge clk);
        #1;
        push = 0;
        if (!full)
            $fatal(1, "overflow attempt changed FIFO occupancy");

        pop_expect(8'h11);
        replace_head(8'h22, 8'h55);
        pop_expect(8'h33);
        pop_expect(8'h44);
        pop_expect(8'h55);
        if (!empty || full)
            $fatal(1, "FIFO did not assert empty after draining");

        @(negedge clk);
        pop = 1;
        @(posedge clk);
        #1;
        pop = 0;
        if (!empty)
            $fatal(1, "underflow attempt changed FIFO occupancy");

        model_head = 0;
        model_tail = 0;
        model_count = 0;
        random_state = 32'h1ACE_B00C;
        random_cycles = 200;
        if ($value$plusargs("FIFO_SEED=%h", random_state))
            $display("Using FIFO_SEED=%08h", random_state);
        if ($value$plusargs("FIFO_CYCLES=%d", random_cycles))
            $display("Using FIFO_CYCLES=%0d", random_cycles);
        random_seed = random_state;
        if (random_state == 0)
            $fatal(1, "FIFO_SEED must be nonzero for the LFSR generator");
        if (random_cycles < 1)
            $fatal(1, "FIFO_CYCLES must be positive");

        for (int cycle = 0; cycle < random_cycles; cycle++) begin
            random_state = {random_state[30:0],
                            random_state[31] ^ random_state[21] ^
                            random_state[1] ^ random_state[0]};
            randomized_cycle(random_state[9] | random_state[10], random_state[8], random_state[7:0]);
        end
        while (model_count > 0)
            randomized_cycle(1'b0, 1'b1, 8'h00);
        randomized_cycle(1'b0, 1'b1, 8'h00);

        if (simultaneous_cycles == 0 || rejected_pushes == 0 || rejected_pops == 0)
            $fatal(1, "randomized phase missed coverage: simultaneous=%0d rejected_pushes=%0d rejected_pops=%0d",
                   simultaneous_cycles, rejected_pushes, rejected_pops);
        $display("FIFO_TEST_PASSED depth=4 random_cycles=%0d seed=%08h final_state=%08h simultaneous=%0d rejected_pushes=%0d rejected_pops=%0d",
                 random_cycles, random_seed, random_state, simultaneous_cycles, rejected_pushes, rejected_pops);
        $finish;
    end
endmodule
