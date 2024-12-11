`timescale 1ns / 1ps
`default_nettype none
module center_of_mass (
                         input wire clk_in,
                         input wire rst_in,
                         input wire [10:0] x_in,
                         input wire [9:0]  y_in,
                         input wire valid_in,
                         input wire tabulate_in,
                         output logic [10:0] x_out,
                         output logic [9:0] y_out,
                         output logic valid_out);

	typedef enum logic [1:0] {SUMMING, DIVIDING, DONE} com_state;
    com_state state;

    logic [31:0] x_sum;
    logic [31:0] y_sum;
    logic [31:0] number_inputs;

    logic [31:0] avg_x;
    logic [31:0] avg_y;

    logic trigger_division;

    logic div_x_done;
    logic div_y_done;
    logic div_x_error;
    logic div_y_error;

    divider
      #(
        .WIDTH(32)
      ) div_x 
      (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .dividend_in(x_sum),
        .divisor_in(number_inputs),
        .data_valid_in(trigger_division),
        .quotient_out(avg_x),
        .remainder_out(),
        .data_valid_out(div_x_done),
        .error_out(div_x_error)
      );

    divider
      #(
        .WIDTH(32)
      ) div_y 
      (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .dividend_in(y_sum),
        .divisor_in(number_inputs),
        .data_valid_in(trigger_division),
        .quotient_out(avg_y),
        .remainder_out(),
        .data_valid_out(div_y_done),
        .error_out(div_y_error)
      );

   always_ff @(posedge clk_in)begin
        if (rst_in) begin
          state <= SUMMING;
          number_inputs <= 0;
          x_sum <= 0;
          y_sum <= 0;

          trigger_division <= 0;
          x_out <= 0;
          y_out <= 0;
          valid_out <= 0;
        end else begin
          trigger_division <= 0;

          case(state)
            SUMMING : begin
              if (valid_in) begin
                x_sum <= x_sum + x_in;
                y_sum <= y_sum + y_in;
                number_inputs <= number_inputs + 1;
              end

              if (tabulate_in && number_inputs > 0) begin
                state <= DIVIDING;
                trigger_division <= 1;
              end
            end

            DIVIDING : begin
              if (div_x_done && div_y_done) begin
                x_out <= avg_x;
                y_out <= avg_y;
                state <= DONE;
                valid_out <= 1;
              end else begin
                state <= DIVIDING;
              end
            end

            DONE : begin
                valid_out <= 0;
                state <= SUMMING;

                number_inputs <= 0;
                x_sum <= 0;
                y_sum <= 0;
            end

            default : state <= SUMMING;
          endcase   
        end
    end


endmodule

`default_nettype wire
