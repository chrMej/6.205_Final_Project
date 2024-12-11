
module tm_choice (
  input wire [7:0] data_in,
  output logic [8:0] qm_out
  );

  logic [3:0] count_ones;
  logic invert;

  always_comb begin
    // Count number of ones in the 
    count_ones = '0;
    for (int i = 0; i < 8; i++) begin
      count_ones = count_ones + data_in[i];
    end

    invert = (count_ones > 4) || ((count_ones == 4) && (data_in[0] == 0));

    // Assign data according to TM scheme
    qm_out[0] = data_in[0];
    
    for (int i = 1; i < 8; i++) begin
      qm_out[i] = invert ? qm_out[i - 1] ~^ data_in[i] : qm_out[i - 1] ^ data_in[i];
    end

    qm_out[8] = ~invert;
  end

endmodule //end tm_choice
