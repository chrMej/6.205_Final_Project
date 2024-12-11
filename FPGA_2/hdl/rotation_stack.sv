module rotation_stack(
    input wire clk_in,
    input wire inc_in,
    input wire dec_in,
    input wire sys_rst,
    input wire [8:0] x_in,
    input wire [7:0] y_in,
    input wire [8:0] z_in,
    input wire valid_in,
    output logic [8:0] x_out,
    output logic [7:0] y_out,
    output logic valid_out );

    logic [31:0] angle;
    logic signed [15:0] cos;
    logic signed [15:0] sin;

    angle_inc ang(
    .clk_in(clk_in),
    .rst_in(sys_rst),
    .inc(inc_in),
    .dec(dec_in),
    .angle(angle)
    );

    cordic angle_cordic(
    .clk_in(clk_in),
    .rst_in(sys_rst),
    .x(16'h8000),
    .y(0),
    .angle(angle),
    .cos(cos),
    .sin(sin)
    );

    // ROATIONS & PERSPECTIVE PROJECTION
    logic [8:0] x_projection;
    logic [7:0] y_projection;
    logic projection_done;

    perspective_projection proj (
    .clk_in(clk_in),
    .rst_in(sys_rst),
    .cos(cos),
    .sin(sin),
    .x_in(x_in),
    .y_in(y_in),
    .z_in(z_in),
    .valid_in(valid_in),
    .x_out(x_out),
    .y_out(y_out),
    .valid_out(valid_out)
    );

endmodule