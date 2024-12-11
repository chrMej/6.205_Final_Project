module perspective_projection (
   input wire clk_in,
   input wire rst_in,
   input wire signed [15:0] cos,
   input wire signed [15:0] sin,
   input wire [8:0] x_in,
   input wire [7:0] y_in,
   input wire [8:0] z_in,
   input wire valid_in,
   output logic [8:0] x_out,
   output logic [7:0] y_out,
   output logic valid_out
);

   logic signed [31:0] centered_x_reg, centered_z_reg;
   logic signed [31:0] rot_x_reg, rot_z_reg;
   logic signed [31:0] x_cos;
   logic signed [31:0] z_sin;
   logic signed [31:0] x_sin;
   logic signed [31:0] z_cos;
   logic valid_rot;
   logic [8:0] x_rot;
   logic [7:0] y_rot;

   assign centered_x_reg = x_in - 160;
   assign centered_z_reg = z_in - 160;

   logic signed [15:0] cos_reg;
   logic signed [15:0] sin_reg;

   always_ff @(posedge clk_in) begin
    cos_reg <= cos;
    sin_reg <= sin; 
   end

   always_ff @(posedge clk_in) begin
       if (rst_in) begin
           rot_x_reg <= 0;
           rot_z_reg <= 0;
           valid_rot <= 0;
           y_rot <= 0;
       end else if (valid_in) begin
           x_cos <= centered_x_reg * cos_reg;
           x_sin <= centered_x_reg * sin_reg;

        //    rot_x_reg <= (centered_x_reg*cos - centered_z_reg*sin) >>> 15;
           valid_rot <= 1;
           y_rot <= y_in;
       end else begin
           valid_rot <= 0;
       end
   end

   always_ff @(posedge clk_in) begin
       if (rst_in) begin
           x_out <= 0;
           y_out <= 0;
           valid_out <= 0;
       end else if (valid_rot) begin
        x_out <= ((x_cos - z_sin) >>> 15) + 160;

        //    x_out <= ((rot_x_reg + 160) > 319) ? 319 : 
        //            ((rot_x_reg + 160) < 0) ? 0 : 
        //            rot_x_reg + 160;
           y_out <= y_rot;
           valid_out <= 1;
       end else begin
           valid_out <= 0;
       end
   end

endmodule