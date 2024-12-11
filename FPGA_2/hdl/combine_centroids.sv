`timescale 1ns / 1ps
`default_nettype none

module combine_centroids #(
    parameter X_WIDTH = 9,
    parameter Y_WIDTH = 8,
    parameter Z_WIDTH = 9
) (
    input wire clk_in,
    input wire rst_in,
    
    input wire [X_WIDTH-1:0] local_x_in,
    input wire [Y_WIDTH-1:0] local_y_in,
    input wire local_valid_in,
    
    input wire [Z_WIDTH-1:0] uart_z_in,
    input wire [Y_WIDTH-1:0] uart_y_in,
    input wire uart_valid_in,
    
    output logic [X_WIDTH-1:0] x_out,
    output logic [Y_WIDTH-1:0] y_out,
    output logic [Z_WIDTH-1:0] z_out,
    output logic valid_out
);

    typedef enum logic [1:0] {WAIT_FOR_INPUTS, AVERAGING} combine_state;
    
    combine_state state;
    
    logic [X_WIDTH-1:0] local_x_reg;
    logic [Y_WIDTH-1:0] local_y_reg;
    logic [Z_WIDTH-1:0] uart_z_reg;
    logic [Y_WIDTH-1:0] uart_y_reg;
    logic local_ready, uart_ready;

    logic start_divide;
    logic division_done;
    logic [Y_WIDTH-1:0] average_y;

    divider #(
        .WIDTH(32) 
    ) y_averager (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .dividend_in({1'b0, local_y_reg} + {1'b0, uart_y_reg}), 
        .divisor_in(2),
        .data_valid_in(start_divide),
        .quotient_out(average_y),
        .remainder_out(),
        .data_valid_out(division_done),
        .error_out()
    );

    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            state <= WAIT_FOR_INPUTS;
            local_ready <= 1'b0;
            uart_ready <= 1'b0;
            valid_out <= 1'b0;
            start_divide <= 1'b0;
        end else begin
            valid_out <= 1'b0;
            start_divide <= 1'b0;
            
            if (local_valid_in) begin
                local_x_reg <= local_x_in;
                local_y_reg <= local_y_in;
                local_ready <= 1'b1;
            end
            
            if (uart_valid_in) begin
                uart_z_reg <= uart_z_in;
                uart_y_reg <= uart_y_in;
                uart_ready <= 1'b1;
            end

            case (state)
                WAIT_FOR_INPUTS: begin
                    if (local_ready && uart_ready) begin
                        state <= AVERAGING;
                        start_divide <= 1'b1;
                    end
                end

                AVERAGING: begin
                    if (division_done) begin
                        x_out <= local_x_reg;
                        y_out <= average_y;
                        z_out <= uart_z_reg;
                        valid_out <= 1'b1;
                        
                        state <= WAIT_FOR_INPUTS;
                        local_ready <= 1'b0;
                        uart_ready <= 1'b0;
                    end
                end

                default: state <= WAIT_FOR_INPUTS;
            endcase
        end
    end

endmodule

`default_nettype wire