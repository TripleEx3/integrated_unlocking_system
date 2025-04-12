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
    // Note: These connections assume the integrated module exposes these signals
    // If not, you'll need to modify the integrated_unlocking_system to expose them
    assign s_data = dut.s_data;
    assign s_valid = dut.s_valid;
    assign s_ready = dut.s_ready;
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Task to apply a 4-bit pattern and wait for processing
    task apply_pattern(input [N-1:0] pattern);
        $display("\n=== Testing Pattern: %b ===", pattern);
        
        // Wait for the system to be ready
        wait(p_ready);
        @(posedge clk);
        
        // Apply the pattern
        p_data = pattern;
        p_valid = 1;
        @(posedge clk);
        
        // Wait for the pattern to be accepted
        wait(!p_ready);
        p_valid = 0;
        
        // Wait for serial conversion and processing to complete
        repeat(N+2) @(posedge clk);
        
        // Wait for system to return to ready state
        wait(p_ready);
        
        // Report final state
        $display("=== Pattern %b complete ===", pattern);
        $display("Final state: unlock = %b, pwd_incorrect = %b\n", unlock, pwd_incorrect);
    endtask
    
    // Task to monitor serial bits going from P2S to FSM
    task automatic monitor_serial_bits();
        forever begin
            @(posedge clk);
            if (s_valid) begin
                $display("Time=%0t: Serial bit = %b, State = %s, FSM ready = %b", 
                         $time, s_data, dut.mealy_fsm.current_state.name(), s_ready);
                
                // Display FSM outputs when they change
                if (unlock)
                    $display("Time=%0t: UNLOCK SIGNAL ACTIVATED!", $time);
                    
                if (pwd_incorrect)
                    $display("Time=%0t: PASSWORD INCORRECT SIGNAL ACTIVATED!", $time);
            end
        end
    endtask
    
    // Main simulation
    initial begin
        // Set up waveform dumping
        $dumpfile("unlocking_system.vcd");
        $dumpvars(0, tb_integrated_unlocking_system);
        
        // Start monitoring process
        fork
            monitor_serial_bits();
        join_none
        
        // Initialize signals
        rst_n = 0;
        p_data = '0;
        p_valid = 0;
        
        // Apply reset
        repeat(2) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        
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
