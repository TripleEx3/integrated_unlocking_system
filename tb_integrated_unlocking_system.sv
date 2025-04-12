`timescale 1ns/1ps

module tb_integrated_unlocking_system();
    // Parameters
    parameter N = 4;
    parameter CLK_PERIOD = 10; // 10ns clock period
    
    // Testbench signals
    logic clk;
    logic rst_n;
    logic [N-1:0] p_data;
    logic p_valid;
    logic p_ready;
    logic unlock;
    logic pwd_incorrect;
    
    // DUT instantiation
    integrated_unlocking_system #(.N(N)) dut (
        .clk(clk),
        .rst_n(rst_n),
        .p_data(p_data),
        .p_valid(p_valid),
        .p_ready(p_ready),
        .unlock(unlock),
        .pwd_incorrect(pwd_incorrect)
    );
    
    // Clock generation
    always begin
        clk = 1'b0;
        #(CLK_PERIOD/2);
        clk = 1'b1;
        #(CLK_PERIOD/2);
    end
    
    // Task to send a parallel data word
    task send_parallel_data(input logic [N-1:0] data);
        p_data = data;
        p_valid = 1'b1;
        @(posedge clk);
        while (!p_ready) @(posedge clk); // Wait until p_ready is asserted
        @(posedge clk);
        p_valid = 1'b0;
        @(posedge clk);
        // Wait for the parallel-to-serial conversion and FSM processing
        repeat(10) @(posedge clk);
    endtask
    
    // Stimulus
    initial begin
        // Initialize signals
        rst_n = 1'b0;
        p_data = '0;
        p_valid = 1'b0;
        
        // Set up waveform dumping for simulation viewing
        $dumpfile("unlocking_system_waves.vcd");
        $dumpvars(0, tb_integrated_unlocking_system);
        
        // Reset the system
        repeat(5) @(posedge clk);
        rst_n = 1'b1;
        repeat(5) @(posedge clk);
        
        // Start testing
        $display("Starting tests at time %0t", $time);
        
        // Test case 1: Valid combination (1101 in binary)
        // LSB first: 1->0->1->1
        // This is the unlock sequence for the FSM (which expects 1-0-1-1)
        $display("\nTest case 1: Valid combination 4'b1101 at time %0t", $time);
        send_parallel_data(4'b1101);  // LSB first: 1->0->1->1
        $display("Unlock: %b, Password Incorrect: %b at time %0t", unlock, pwd_incorrect, $time);
        
        // Test case 2: Invalid combination (1010 in binary)
        // LSB first: 0->1->0->1
        // This is not the unlock sequence
        $display("\nTest case 2: Invalid combination 4'b1010 at time %0t", $time);
        send_parallel_data(4'b1010);  // LSB first: 0->1->0->1
        $display("Unlock: %b, Password Incorrect: %b at time %0t", unlock, pwd_incorrect, $time);
        
        // Test case 3: Invalid combination (1011 in binary)
        // LSB first: 1->1->0->1
        // This is not the unlock sequence (which is 1-0-1-1)
        $display("\nTest case 3: Invalid combination 4'b1011 at time %0t", $time);
        send_parallel_data(4'b1011);  // LSB first: 1->1->0->1
        $display("Unlock: %b, Password Incorrect: %b at time %0t", unlock, pwd_incorrect, $time);
        
        // Test case 4: Invalid combination (0000 in binary)
        $display("\nTest case 4: Invalid combination 4'b0000 at time %0t", $time);
        send_parallel_data(4'b0000);
        $display("Unlock: %b, Password Incorrect: %b at time %0t", unlock, pwd_incorrect, $time);
        
        // End simulation
        $display("\nTests completed at time %0t", $time);
        #100 $finish;
    end
    
    // Monitor important signals
    initial begin
        $monitor("Time=%0t: p_ready=%b, unlock=%b, pwd_incorrect=%b", 
                 $time, p_ready, unlock, pwd_incorrect);
    end
    
    // Debug signals to observe the internal operations
    logic s_data, s_valid, s_ready;
    assign s_data = dut.s_data;
    assign s_valid = dut.s_valid;
    assign s_ready = dut.s_ready;
    
    // Log debug information
    always @(posedge clk) begin
        if (s_valid)
            $display("DEBUG: Time=%0t - Serial bit: %b, s_valid=%b, s_ready=%b", 
                    $time, s_data, s_valid, s_ready);
    end
    
endmodule
