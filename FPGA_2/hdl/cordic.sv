module cordic(input wire clk_in, 
            input wire rst_in,
            input logic [15:0] x,
            input logic [15:0] y,
            input logic signed [31:0] angle,
            output logic signed [15:0] cos,
            output logic signed [15:0] sin);



    logic signed [31:0] angles [30:0];

    // each angle is arctan(2^-i)

    assign angles[00] = 'b00100000000000000000000000000000; 
    assign angles[01] = 'b00010010111001000000010100011101; 
    assign angles[02] = 'b00001001111110110011100001011011;
    assign angles[03] = 'b00000101000100010001000111010100;
    assign angles[04] = 'b00000010100010110000110101000011;
    assign angles[05] = 'b00000001010001011101011111100001;
    assign angles[06] = 'b00000000101000101111011000011110;
    assign angles[07] = 'b00000000010100010111110001010101;
    assign angles[08] = 'b00000000001010001011111001010011;
    assign angles[09] = 'b00000000000101000101111100101110;
    assign angles[10] = 'b00000000000010100010111110011000;
    assign angles[11] = 'b00000000000001010001011111001100;
    assign angles[12] = 'b00000000000000101000101111100110;
    assign angles[13] = 'b00000000000000010100010111110011;
    assign angles[14] = 'b00000000000000001010001011111001;
    assign angles[15] = 'b00000000000000000101000101111100;
    assign angles[16] = 'b00000000000000000010100010111110;
    assign angles[17] = 'b00000000000000000001010001011111;
    assign angles[18] = 'b00000000000000000000101000101111;
    assign angles[19] = 'b00000000000000000000010100010111;
    assign angles[20] = 'b00000000000000000000001010001011;
    assign angles[21] = 'b00000000000000000000000101000101;
    assign angles[22] = 'b00000000000000000000000010100010;
    assign angles[23] = 'b00000000000000000000000001010001;
    assign angles[24] = 'b00000000000000000000000000101000;
    assign angles[25] = 'b00000000000000000000000000010100;
    assign angles[26] = 'b00000000000000000000000000001010;
    assign angles[27] = 'b00000000000000000000000000000101;
    assign angles[28] = 'b00000000000000000000000000000010;
    assign angles[29] = 'b00000000000000000000000000000001;
    assign angles[30] = 'b00000000000000000000000000000000;

    //make input angle between -90 and 90 degrees
    logic signed [17:0] x_vals [15:0];
    logic signed [17:0] y_vals [15:0];
    logic signed [31:0] ang_vals [15:0];
    logic signed [1:0] quadrant;
    assign quadrant = angle[31:30];

    always_ff @(posedge clk_in) begin
        case (quadrant)
            2'b00 : begin //this quadrant is fine
                    x_vals[0] <= x;
                    y_vals[0] <= y;
                    ang_vals[0] <= angle;
                end
            2'b01 : begin //shift 90 degrees back
                    x_vals[0] <= -y;
                    y_vals[0] <= x;
                    ang_vals[0] <= {2'b00, angle[29:0]};
                end
            2'b10 : begin // shift 90 degrees forward
                    x_vals[0] <= y;
                    y_vals[0] <= -x;
                    ang_vals[0] <= {2'b11, angle[29:0]};
                end
            2'b11 : begin // this quadrant is fine
                    x_vals[0] <= x;
                    y_vals[0] <= y;
                    ang_vals[0] <= angle;
                end
            default : begin
                    x_vals[0] <= x;
                    y_vals[0] <= y;
                    ang_vals[0] <= angle;
                end 
        endcase
    end



    genvar i;
    generate
        for (i=0; i < 15; i = i + 1)begin

            //did we go pass the desired angle
            logic angle_sign;
            assign angle_sign = ang_vals[i][31];

            //shift previously calclulated value
            logic signed [17:0] xshf, yshf;
            assign xshf = x_vals[i] >>> i;
            assign yshf = y_vals[i] >>> i;


            // add/subtract based on our previous guess
            always_ff @(posedge clk_in) begin
                x_vals[i+1] <= angle_sign ? x_vals[i] + yshf : x_vals[i] - yshf;
                y_vals[i+1] <= angle_sign ? y_vals[i] - xshf : y_vals[i] + xshf;
                ang_vals[i+1] <= angle_sign ? ang_vals[i] + angles[i] : ang_vals[i] - angles[i];
            end
        end
    endgenerate

    logic signed [15:0] temp_x_val;
    logic signed [15:0] temp_y_val;
    logic signed [15:0] temp_cos;
    logic signed [15:0] temp_sin;
    always_ff @(posedge clk_in) begin
        temp_x_val <= x_vals[15];
        temp_y_val <= y_vals[15];
        temp_cos <= (x_vals[15] >>> 1) + (x_vals[15] >>> 4) + (x_vals[15] >>> 5);
        temp_sin <= (y_vals[15] >>> 1) + (y_vals[15] >>> 4) + (y_vals[15] >>> 5);
        cos <= temp_cos + (temp_x_val[15] >>> 7) + (temp_x_val[15] >>> 8) + (temp_x_val[15] >>> 10);
        sin <= temp_sin + (temp_y_val[15] >>> 7) + (temp_y_val[15] >>> 8) + (temp_y_val[15] >>> 10);
    end

    // For shifting after the fact (multiply by ~0.60725...)
    // assign cos = (x_vals[15] >>> 1) + (x_vals[15] >>> 4) + (x_vals[15] >>> 5) + (x_vals[15] >>> 7) + (x_vals[15] >>> 8) + (x_vals[15] >>> 10);
    // assign sin = (y_vals[15] >>> 1) + (y_vals[15] >>> 4) + (y_vals[15] >>> 5) + (y_vals[15] >>> 7) + (y_vals[15] >>> 8) + (y_vals[15] >>> 10);






endmodule