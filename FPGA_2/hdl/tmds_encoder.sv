`timescale 1ns / 1ps
`default_nettype none

module tmds_encoder(
  input wire clk_in,
  input wire rst_in,
  input wire [7:0] data_in,  // video data (red, green or blue)
  input wire [1:0] control_in, //for blue set to {vs,hs}, else will be 0
  input wire ve_in,  // video data enable, to choose between control or video signal
  output logic [9:0] tmds_out
);

  logic [4:0] tally;
  logic [8:0] q_m;
  //you can assume a functioning (version of tm_choice for you.)
  tm_choice mtm(
    .data_in(data_in),
    .qm_out(q_m));
   
  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      tally <= 0;
      tmds_out <= 0;
    end else begin 
      if (ve_in) begin
        if ((tally == 0) || (number_ones == number_zeros)) begin
          tally <= q_m[8] ? tally + (number_ones - number_zeros) : tally + (number_zeros - number_ones); 
        end else if ((~tally[4] && (number_ones > number_zeros)) || (tally[4] && (number_zeros > number_ones))) begin
          tally <= tally + (q_m[8] ? 5'b00010 : 5'b00000) + (number_zeros - number_ones);
        end else begin
          tally <= tally - (q_m[8] ? 5'b00000 : 5'b00010) + (number_ones - number_zeros);
        end
        tmds_out <= q_out;
      end else begin
        case(control_in)
          2'b00 : tmds_out <= 10'b1101010100;
          2'b01 : tmds_out <= 10'b0010101011;
          2'b10 : tmds_out <= 10'b0101010100;
          2'b11 : tmds_out <= 10'b1010101011;
        endcase

        tally <= 0;
      end
    end
  end
  
  logic [3:0] number_ones;
  logic [3:0] number_zeros;
  logic [9:0] q_out;

  always_comb begin
    number_ones = q_m[0] + q_m[1] + q_m[2] + q_m[3] +
                  q_m[4] + q_m[5] + q_m[6] + q_m[7];
    number_zeros = 8 - number_ones;

    if ((tally == 0) || (number_ones == number_zeros)) begin
      q_out[9] = ~q_m[8];
      q_out[8] = q_m[8];
      q_out[7:0] = (q_m[8]) ? q_m[7:0] : ~q_m[7:0];
    end else if ((~tally[4] && (number_ones > number_zeros)) || (tally[4] && (number_zeros > number_ones))) begin
      q_out[9] = 1;
      q_out[8] = q_m[8];
      q_out[7:0] = ~q_m[7:0];
    end else begin
      q_out[9] = 0;
      q_out[8] = q_m[8];
      q_out[7:0] = q_m[7:0];
    end
  end
endmodule //end tmds_encoder
`default_nettype wire
