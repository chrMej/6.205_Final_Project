`timescale 1ns / 1ps
`default_nettype none

module kmeans
  (
    input wire clk_in,
    input wire start_in,
    input wire rst_in,
    input wire rst_coms,
    input wire valid_in,
    input wire [8:0] x_in, c1_x_in, c2_x_in,
    input wire [7:0] y_in, c1_y_in, c2_y_in,
    output logic [8:0] c1_x_out, c2_x_out,
    output logic [7:0] c1_y_out, c2_y_out,
    output logic valid_out
  );

  logic c1_dist_valid_out, c2_dist_valid_out;
  logic [8:0] c1_dist, c2_dist;
  
  manhattan_distance c1_dist_m (
    .clk_in(clk_in),
    .x_1(x_in),
    .y_1(y_in),
    .x_2(c1_x_in),
    .y_2(c1_y_in),
    .valid_in(valid_in),
    .valid_out(c1_dist_valid_out),
    .distance_out(c1_dist)
  );

  manhattan_distance c2_dist_m (
    .clk_in(clk_in),
    .x_1(x_in),
    .y_1(y_in),
    .x_2(c2_x_in),
    .y_2(c2_y_in),
    .valid_in(valid_in),
    .valid_out(c2_dist_valid_out),
    .distance_out(c2_dist)
  );

  // Pipeline becase manhattan distance and comp each take 1 cycle
  logic [8:0] x_pipe [2:0];
  logic [7:0] y_pipe [2:0];
  logic start_pipe [2:0];

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      for (int i = 0; i < 3; i = i + 1) begin
        x_pipe[i] <= 1'b0;
        y_pipe[i] <= 1'b0;
        start_pipe[i] <= 1'b0;
      end
    end else begin
      for (int i=1; i<3; i = i+1)begin
        x_pipe[i] <= x_pipe[i-1];
        y_pipe[i] <= y_pipe[i-1];
        start_pipe[i] <= start_pipe[i-1];
      end
      if (valid_in) begin
        x_pipe[0] <= x_in;
        y_pipe[0] <= y_in;
      end
      start_pipe[0] <= start_in;
    end
  end

  logic [1:0] comp_valid_out;
  
  // Pipe into comparator
  comparator comp (
    .clk_in(clk_in),
    .rst_in(rst_in),
    .dist_1_in(c1_dist),
    .dist_2_in(c2_dist),
    .valid_1_in(c1_dist_valid_out),
    .valid_2_in(c2_dist_valid_out),
    .valid_out(comp_valid_out)
  );

  logic c1_valid_out, c2_valid_out;
  logic [8:0] c1_x_temp, c2_x_temp;
  logic [7:0] c1_y_temp, c2_y_temp;
  logic c1_ready, c2_ready;

  logic [8:0] c1_x_com, c2_x_com;
  logic [7:0] c1_y_com, c2_y_com;

  center_of_mass c1_com (
    .clk_in(clk_in),
    .rst_in(rst_in || rst_coms),
    .x_in(x_pipe[2]),
    .y_in(y_pipe[2]),
    .valid_in(comp_valid_out[0]),
    .tabulate_in(start_pipe[2]),
    .x_out(c1_x_com),
    .y_out(c1_y_com),
    .valid_out(c1_valid_out)
  );

  center_of_mass c2_com (
    .clk_in(clk_in),
    .rst_in(rst_in || rst_coms),
    .x_in(x_pipe[2]),
    .y_in(y_pipe[2]),
    .valid_in(comp_valid_out[1]),
    .tabulate_in(start_pipe[2]),
    .x_out(c2_x_com),
    .y_out(c2_y_com),
    .valid_out(c2_valid_out)
  );

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      c1_x_temp <= '0;
      c1_y_temp <= '0;
      c2_x_temp <= '0;
      c2_y_temp <= '0;
      c1_ready <= 1'b0;
      c2_ready <= 1'b0;
      valid_out <= 1'b0;
      c1_x_out <= '0;
      c1_y_out <= '0;
      c2_x_out <= '0;
      c2_y_out <= '0;
    end else begin
      if (c1_valid_out) begin
        c1_x_temp <= c1_x_com;
        c1_y_temp <= c1_y_com;

        c1_ready <= 1'b1;
      end
      
      if (c2_valid_out) begin
        c2_x_temp <= c2_x_com;
        c2_y_temp <= c2_y_com;

        c2_ready <= 1'b1;
      end

      if (c1_ready && c2_ready) begin
        c1_x_out <= c1_x_temp;
        c1_y_out <= c1_y_temp;

        c2_x_out <= c2_x_temp;
        c2_y_out <= c2_y_temp;

        valid_out <= 1'b1;

        c1_ready <= 1'b0;
        c2_ready <= 1'b0;
      end else begin
        valid_out <= 1'b0;
      end
    end
  end

endmodule
`default_nettype wire