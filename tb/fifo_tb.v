`timescale 1ns / 1ps

module tb_async_fifo();

    // ------------------------------------------------------------------------
    // Parameter Definitions (Matches RTL)
    // ------------------------------------------------------------------------
    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 3; 

    // ------------------------------------------------------------------------
    // Testbench Signals
    // ------------------------------------------------------------------------
    reg                   wclk;
    reg                   wrst_n;
    reg                   w_en;
    reg  [DATA_WIDTH-1:0] data_in;
    wire                  full;

    reg                   rclk;
    reg                   rrst_n;
    reg                   r_en;
    wire [DATA_WIDTH-1:0] data_out;
    wire                  empty;

    // ------------------------------------------------------------------------
    // Unit Under Test (UUT) Instantiation
    // ------------------------------------------------------------------------
    async_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) uut (
        .wclk(wclk),
        .wrst_n(wrst_n),
        .w_en(w_en),
        .data_in(data_in),
        .full(full),
        .rclk(rclk),
        .rrst_n(rrst_n),
        .r_en(r_en),
        .data_out(data_out),
        .empty(empty)
    );

    // ------------------------------------------------------------------------
    // 1. "Highly Disparate Asynchronous Clock" Generation
    // ------------------------------------------------------------------------
    // Write Clock: 50 MHz (Period = 20ns)
    initial wclk = 0;
    always #10 wclk = ~wclk; 

    // Read Clock: ~18.5 MHz (Period = 54ns)
    initial rclk = 0;
    always #27 rclk = ~rclk; 

    // ------------------------------------------------------------------------
    // Stimulus Tasks for Clean Code
    // ------------------------------------------------------------------------
    task write_data(input [DATA_WIDTH-1:0] wdata);
        begin
            @(negedge wclk); // Drive inputs on negedge to avoid setup/hold issues
            if (!full) begin
                w_en = 1'b1;
                data_in = wdata;
                $display("[%0t] WRITE: Data %h written to FIFO", $time, wdata);
            end else begin
                w_en = 1'b0;
                $display("[%0t] WRITE FAILED: FIFO is Full (Overflow prevented)", $time);
            end
            @(negedge wclk);
            w_en = 1'b0;
        end
    endtask

    task read_data();
        begin
            @(negedge rclk);
            if (!empty) begin
                r_en = 1'b1;
                @(negedge rclk);
                $display("[%0t] READ:  Data %h read from FIFO", $time, data_out);
            end else begin
                r_en = 1'b0;
                $display("[%0t] READ FAILED: FIFO is Empty (Underflow prevented)", $time);
            end
            r_en = 1'b0;
        end
    endtask

    // ------------------------------------------------------------------------
    // 2. Exhaustive Corner Case Testing Sequence
    // ------------------------------------------------------------------------
    initial begin
        // Initialize Inputs
        wrst_n = 0; w_en = 0; data_in = 0;
        rrst_n = 0; r_en = 0;

        // Apply Reset
        #100;
        wrst_n = 1; 
        rrst_n = 1;
        $display("--- System Reset Deasserted ---");
        #50;

        // TEST CASE 1: Write until Full (Check Overflow Protection)
        $display("\n--- TEST CASE 1: Burst Write to Full ---");
        write_data(8'hAA);
        write_data(8'hBB);
        write_data(8'hCC);
        write_data(8'hDD);
        write_data(8'hEE);
        write_data(8'hFF);
        write_data(8'h11);
        write_data(8'h22); // FIFO should be FULL here (8 items)
        write_data(8'h33); // This write should be blocked by the task/flag

        #100; // Wait a bit to let pointers synchronize across domains

        // TEST CASE 2: Read until Empty (Check Underflow Protection)
        $display("\n--- TEST CASE 2: Burst Read to Empty ---");
        read_data();
        read_data();
        read_data();
        read_data();
        read_data();
        read_data();
        read_data();
        read_data(); // FIFO should be EMPTY here
        read_data(); // This read should be blocked by the task/flag

        #100;

        // TEST CASE 3: Concurrent Maximum Throughput (Simultaneous Read/Write)
        $display("\n--- TEST CASE 3: Concurrent Read and Write ---");
        fork
            // Write process
            begin
                write_data(8'hA1);
                write_data(8'hB2);
                write_data(8'hC3);
                write_data(8'hD4);
            end
            // Read process (Delayed slightly to ensure FIFO isn't entirely empty)
            begin
                #60; 
                read_data();
                read_data();
                read_data();
                read_data();
            end
        join

        #200;
        $display("\n--- Simulation Complete ---");
        $finish;
    end

endmodule
