`timescale 1ns / 1ps
`default_nettype none

module manhattan_distance
 (
  input wire clk_in,
  input wire [8:0]      x_1,
  input wire [7:0]      y_1,
  input wire [8:0]      x_2,
  input wire [7:0]      y_2,
  input wire            valid_in,
  output logic          valid_out,
  output logic [8:0]    distance_out
 );
  
 logic [8:0] x_diff;
 logic [8:0] y_diff;
 logic [8:0] manhattan_dist;

 assign x_diff = (x_1 > x_2) ? (x_1 - x_2) : (x_2 - x_1);
 assign y_diff = (y_1 > y_2) ? (y_1 - y_2) : (y_2 - y_1);
 assign manhattan_dist = x_diff + y_diff;

 always_ff @(posedge clk_in) begin
   if (valid_in) begin
    distance_out <= manhattan_dist;
    valid_out <= 1'b1;
   end else begin
    valid_out <= 1'b0;
   end
 end

endmodule
`default_nettype wire