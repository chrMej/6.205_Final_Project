`timescale 1ns / 1ps
`default_nettype none

module comparator (
    input wire clk_in,
    input wire rst_in,
    input wire [8:0] dist_1_in,
    input wire [8:0] dist_2_in,
    input wire valid_1_in,
    input wire valid_2_in,
    output logic [1:0] valid_out
);

    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            valid_out <= 2'b00;
        end else begin 
            if (valid_1_in && valid_2_in) begin
                if (dist_1_in < dist_2_in) begin
                    valid_out <= 2'b01;
                end else if (dist_1_in > dist_2_in) begin
                    valid_out <= 2'b10;
                end else begin
                    valid_out <= 2'b01;
                end
            end else begin
                valid_out <= 2'b00;
            end
        end
    end

endmodule

`default_nettype wire