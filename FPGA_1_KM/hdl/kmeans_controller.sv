`timescale 1ns / 1ps
`default_nettype none

module kmeans_controller
  (
    input wire clk_in,
    input wire rst_in,
    input wire [8:0]  hcount_in,
    input wire [7:0]  vcount_in,
    input wire [14:0] num_points_in,
    input wire camera_valid_in,
    input wire iteration_finished_in,
    output logic [14:0] addrb_out,
    output logic start_iteration_out,
    output logic km_valid_in,
    output logic uart_trigger_out,
    output logic reset_coms
  );
  
  typedef enum logic [1:0] {
    WAITING,
    CALCULATING,
    DONE
  } km_state;

  km_state state;

  logic km_valid_pipe [1:0];
  logic start_pipe [1:0];

  always_ff @(posedge clk_in) begin
    km_valid_pipe[1] <= km_valid_pipe[0];
    start_pipe[1] <= start_pipe[0];
  end

  assign km_valid_in = km_valid_pipe[1];
  assign start_iteration_out = start_pipe[1];

  logic iteration_running;

  always_ff @(posedge clk_in) begin
    if(rst_in) begin
      addrb_out <= 0;
      start_iteration_out <= 0;
      km_valid_in <= 0;
      uart_trigger_out <= 0;
      iteration_running <= 0;

      state <= WAITING;
    end else begin
      case(state)
        WAITING : begin
          uart_trigger_out <= 1'b0;
          reset_coms <= 1'b0;
          addrb_out <= 0;

          if (hcount_in == 319 && vcount_in == 179) begin
            state <= CALCULATING;
          end
        end

        CALCULATING : begin
          start_pipe[0] <= 1'b0;

          if (addrb_out != num_points_in - 1) begin
            addrb_out <= addrb_out + 1;
            km_valid_pipe[0] <= 1'b1;
          end else begin
            if (iteration_finished_in) begin
              addrb_out <= 0;
              km_valid_pipe[0] <= 1'b1;
              iteration_running <= 0;
            end else if(!iteration_running) begin
              km_valid_pipe[0] <= 1'b1;
              start_pipe[0] <= 1'b1;
              iteration_running <= 1'b1;
            end else begin
              km_valid_pipe[0] <= 1'b0;
            end

            state <= (hcount_in == 0) && (vcount_in == 0) && camera_valid_in ? DONE : CALCULATING;
          end
        end

        DONE : begin
          uart_trigger_out <= 1'b1;
          reset_coms <= 1'b1;
          start_iteration_out <= 0;
          km_valid_in <= 0;
          state <= WAITING;
        end
      endcase
    end
  end



endmodule
`default_nettype wire