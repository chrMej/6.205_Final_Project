`timescale 1ns / 1ps
`default_nettype none

module divider #(parameter WIDTH = 32) (
    input wire clk_in,
    input wire rst_in,
    input wire[WIDTH-1:0] dividend_in,
    input wire[WIDTH-1:0] divisor_in,
    input wire data_valid_in,
    output logic[WIDTH-1:0] quotient_out,
    output logic[WIDTH-1:0] remainder_out,
    output logic data_valid_out,
    output logic error_out
);

    logic [WIDTH-1:0] quotient;
    logic [WIDTH:0] remainder; 
    logic [WIDTH:0] divisor; 
    logic [$clog2(WIDTH)-1:0] count;

    typedef enum logic [2:0] {IDLE, DIVIDING, DONE} div_state;
    div_state state;

    logic [WIDTH:0] next_remainder;
    logic [WIDTH:0] shifted_remainder;
    logic [WIDTH-1:0] next_quotient;

    always_comb begin
        shifted_remainder = {remainder[WIDTH-1:0], quotient[WIDTH-1]};
        
        if (shifted_remainder >= divisor) begin
            next_remainder = shifted_remainder - divisor;
            next_quotient = {quotient[WIDTH-2:0], 1'b1};
        end else begin
            next_remainder = shifted_remainder;
            next_quotient = {quotient[WIDTH-2:0], 1'b0};
        end
    end
    
    always_ff @(posedge clk_in) begin
        if (rst_in) begin 
            state <= IDLE;
            count <= WIDTH;
            quotient <= 0;
            remainder <= 0;
            divisor <= 0;
            data_valid_out <= 0;
            error_out <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (data_valid_in) begin
                        if (divisor_in == 0) begin
                          error_out <= 1;
                          data_valid_out <= 1;
                          quotient <= 0;
                          remainder <= 0;
                          state <= DONE;
                        end else begin
                          quotient <= dividend_in;
                          remainder <= 0;
                          divisor <= {1'b0, divisor_in}; 
                          count <= WIDTH;
                          data_valid_out <= 0;
                          error_out <= (divisor_in == 0);
                          state <= DIVIDING;
                        end
                    end
                end

                DIVIDING: begin
                    quotient <= next_quotient;
                    remainder <= next_remainder;
                    count <= count - 1;

                    if (count == 1) begin
                        state <= DONE;
                        data_valid_out <= 1;
                    end else begin
                        state <= DIVIDING;
                    end
                end

                DONE: begin
                    data_valid_out <= 0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    assign quotient_out = quotient;
    assign remainder_out = remainder[WIDTH-1:0];

endmodule

`default_nettype wire