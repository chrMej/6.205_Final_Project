`default_nettype none
module evt_counter
#(
  parameter MAX_COUNT = 40_000
)
  ( input wire          clk_in,
    input wire          rst_in,
    input wire          evt_in,
    output logic[$clog2(MAX_COUNT) - 1:0]  count_out
  );
 
  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      count_out <= 0;
    end else begin
      if (evt_in == 1) begin
        if (count_out == MAX_COUNT - 1) begin
          count_out <= 0;
        end
        else begin
          count_out <= count_out + 1;
        end
      end
      else begin
        count_out <= count_out;
      end
    end
  end
endmodule
`default_nettype wire