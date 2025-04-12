module integrated_unlocking_system #(parameter N=4)(
    input logic clk,
    input logic rst_n,            // Active low reset
    input logic [N-1:0] p_data,   // Parallel data input
    input logic p_valid,          // Parallel data valid
    output logic p_ready,         // Ready to accept parallel data
    output logic unlock,          // Unlock signal
    output logic pwd_incorrect    // Password incorrect signal
);
    
    // Internal signals for connecting the modules
    logic s_data;       // Serial data from converter to FSM
    logic s_valid;      // Serial data valid
    logic s_ready;      // Serial data ready

    // Instantiate parallel to serial converter
    p2s_converter #(.N(N)) p2s_inst (
        .clk(clk),
        .rstn(rst_n),
        .p_data(p_data),
        .p_valid(p_valid),
        .p_ready(p_ready),
        .s_data(s_data),
        .s_valid(s_valid),
        .s_ready(s_ready)
    );

    // Instantiate Mealy FSM unlocking module
    mealy_fsm_unlocking fsm_inst (
        .clk(clk),
        .reset(~rst_n),         // Convert active-low to active-high reset
        .serial_data(s_data),
        .serial_valid(s_valid),
        .unlock(unlock),
        .pwd_incorrect(pwd_incorrect),
        .serial_ready(s_ready)
    );

endmodule
