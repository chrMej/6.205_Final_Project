`default_nettype none
module angle_inc(input wire clk_in,
                input wire rst_in,
                input wire inc,
                input wire dec,
                output logic [31:0] angle);
    localparam CLK_FRQ = 200_000_000;
    localparam INCREMENT_COUNT = CLK_FRQ / 1_000_000;


    logic [$clog2(INCREMENT_COUNT) - 1:0] up;
    evt_counter #(.MAX_COUNT(INCREMENT_COUNT)) angle_up 
                        (.clk_in(clk_in),
                        .rst_in(rst_in),
                        .evt_in(inc),
                        .count_out(up));
    logic [$clog2(INCREMENT_COUNT) - 1:0] down;
    evt_counter #(.MAX_COUNT(INCREMENT_COUNT)) angle_down
                    (.clk_in(clk_in),
                        .rst_in(rst_in),
                        .evt_in(dec),
                        .count_out(down));


    logic prev_up;
    logic prev_down;
    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            angle[31:8] <= 0;
            prev_up <= 1;
            prev_down <= 1;
            angle[7:0] <= 0;
        end
        else begin
            angle[31:8] <= ((up == 0) & ~prev_up) ? angle[31:8] + 1 : 
                            ((down == 0) & ~prev_down) ? angle[31:8] - 1 : angle[31:8];
            prev_up <= ((up == 0) & (down != 0) & ~prev_up) ? 1 :  (up != 0) ? 0 : prev_up;
            prev_down <= ((down == 0) & (up != 0) & ~prev_down) ? 1 : (down != 0) ? 0 : prev_down;
        end
    end
    
        
endmodule
`default_nettype wire