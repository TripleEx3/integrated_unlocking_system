module integrated_unlocking_system #(parameter N=4)(
    input logic clk,
    input logic rst_n,            // Active low reset
    input logic [N-1:0] p_data,   // Parallel data input
    input logic p_valid,          // Parallel data valid
    output logic p_ready,         // Ready to accept parallel data
    output logic unlock,          // Unlock signal
    output logic pwd_incorrect    // Password incorrect signal
);
    // Internal signals connecting P2S converter to Mealy FSM
    logic s_data;     // Serial data bit
    logic s_valid;    // Serial data valid
    logic s_ready;    // Serial data ready
    
    // Reset handling
    logic auto_reset;  // Auto reset signal after error or unlock
    logic system_rst;  // Combined reset signal
    
    // Create reset pulse when we get an error or unlock
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            auto_reset <= 1'b0;
        else if (pwd_incorrect || unlock)
            auto_reset <= 1'b1;
        else
            auto_reset <= 1'b0;
    end
    
    // Combined reset for the system
    assign system_rst = ~rst_n | auto_reset;

    // Instantiate P2S Converter
    p2s_converter #(.N(N)) p2s_inst (
        .clk(clk),
        .rstn(~system_rst),      // Active low reset
        .p_data(p_data),         // Parallel input data
        .p_valid(p_valid),       // Parallel data valid
        .p_ready(p_ready),       // Ready to accept parallel data
        .s_data(s_data),         // Serial output data
        .s_valid(s_valid),       // Serial data valid
        .s_ready(s_ready)        // Serial data ready
    );

    // Instantiate Mealy FSM Unlocking Module
    mealy_fsm_unlocking mealy_fsm (
        .clk(clk),
        .reset(system_rst),      // Use combined reset
        .serial_data(s_data),    // Serial input data from P2S
        .serial_valid(s_valid),  // Serial data valid
        .serial_ready(s_ready),  // Ready to accept serial data
        .unlock(unlock),         // Unlock output signal
        .pwd_incorrect(pwd_incorrect) // Password incorrect output signal
    );

endmodule
