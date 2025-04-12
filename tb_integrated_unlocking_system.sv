`timescale 1ns/1ps

module tb_integrated_unlocking_system();
    // Parameters
    parameter N = 4;
    parameter CLK_PERIOD = 10;  // 10ns clock period
    
    // Testbench signals
    logic clk;
    logic rst_n;
    logic [N-1:0] p_data;
    logic p_valid;
    logic p_ready;
    logic unlock;
    logic pwd_incorrect;
    
    // Internal debug signals to monitor the P2S to FSM interface
    logic s_data;     // Serial data bit
    logic s_valid;    // Serial data valid
    logic s_ready;    // Serial data ready
    
    // Instantiate the device under test
    integrated_unlocking_system #(.N(N)) dut (
        .clk(clk),
        .rst_n(rst_n),
        .p_data(p_data),
        .p_valid(p_valid),
        .p_ready(p_ready),
        .unlock(unlock),
        .pwd_incorrect(pwd_incorrect)
    );
    
    // Connect to internal signals for monitoring
    assign s_data = dut.s_data;
    assign s_valid = dut.s_valid;
    assign s_ready = dut.s_ready;
    
    // For state display - adjust if your enum names are different
    string state_names[4] = {"IDLE", "S_1", "S_10", "S_101"};
    logic [2:0] current_fsm_state;
    assign current_fsm_state = dut.mealy_fsm.current_state;
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Monitor for serial bits
    always @(posedge clk) begin
        if (s_valid) begin
            $display("Time=%0t: Serial bit = %b, State = %s, FSM ready = %b", 
                     $time, s_data, state_names[current_fsm_state], s_ready);
            
            // Display FSM outputs when they change
            if (unlock)
                $display("Time=%0t: UNLOCK SIGNAL ACTIVATED!", $time);
                
            if (pwd_incorrect)
                $display("Time=%0t: PASSWORD INCORRECT SIGNAL ACTIVATED!", $time);
        end
    end
    
    // Task to apply a 4-bit pattern and wait for processing
    task apply_pattern(input [N-1:0] pattern);
        int wait_cycles;
        bit error_or_unlock_seen;
        
        $display("\n=== Testing Pattern: %b ===", pattern);
        
        // Wait for the system to be ready
        repeat(5) @(posedge clk); // Wait a few cycles for system to settle
        wait(p_ready);
        @(posedge clk);
        
        // Apply the pattern
        p_data = pattern;
        p_valid = 1;
        @(posedge clk);
        
        // Wait for the pattern to be accepted
        wait(!p_ready);
        p_valid = 0;
        
        // Wait for processing to complete (simplified approach without fork-join)
        wait_cycles = 0;
        error_or_unlock_seen = 0;
        
        while (wait_cycles < N+5 && !error_or_unlock_seen) begin
            @(posedge clk);
            wait_cycles = wait_cycles + 1;
            
            // Check for error or unlock
            if (pwd_incorrect || unlock) begin
                error_or_unlock_seen = 1;
                // Wait a few more cycles after error/unlock
                repeat(3) @(posedge clk);
                break;
            end
        end
        
        // Wait for system to return to ready state
        repeat(5) @(posedge clk); // Allow additional time for reset
        
        // Report final state
        $display("=== Pattern %b complete ===", pattern);
        $display("Final state: unlock = %b, pwd_incorrect = %b\n", unlock, pwd_incorrect);
    endtask
    
    // Main simulation
    initial begin
        // Set up waveform dumping
        $dumpfile("unlocking_system.vcd");
        $dumpvars(0, tb_integrated_unlocking_system);
        
        // Initialize signals
        rst_n = 0;
        p_data = '0;
        p_valid = 0;
        
        // Apply reset
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // Test case 1: Valid combination (1101 in binary)
        // LSB first: 1->0->1->1, which is the correct unlock sequence
        apply_pattern(4'b1101);
        
        // Test case 2: Invalid combination (1100 in binary)
        // LSB first: 0->0->1->1, which is incorrect
        apply_pattern(4'b1100);
        
        // Test case 3: Invalid combination (1001 in binary)
        // LSB first: 1->0->0->1, which is incorrect
        apply_pattern(4'b1001);
        
        // Allow time for final operations
        repeat(10) @(posedge clk);
        
        // End simulation
        $display("\n=== Simulation Complete ===");
        $finish;
    end
    
    // Status monitoring for summary view
    initial begin
        // Display header
        $display("Time\t\tp_ready\tp_valid\tunlock\tpwd_incorrect");
        
        // Periodically sample key status signals
        forever begin
            #(CLK_PERIOD);
            $display("%0t\t%b\t%b\t%b\t%b", $time, p_ready, p_valid, unlock, pwd_incorrect);
        end
    end
endmodule
