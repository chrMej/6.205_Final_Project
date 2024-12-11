`timescale 1ns / 1ps
`default_nettype none

module uart_rx_wrapper
  #(
    parameter INPUT_CLOCK_FREQ = 100_000_000,
    parameter BAUD_RATE = 9600
  )
  (
    input wire         clk_in,
    input wire         rst_in,
    input wire         rx_wire_in,
    output logic       new_data_out,
    output logic [16:0] data_out
  );

  logic uart_new_data;
  logic [7:0] uart_data;
  logic [16:0] assembled_data;
  
  typedef enum logic [1:0] {
    WAIT_BYTE1,
    WAIT_BYTE2,
    WAIT_BYTE3,
    OUTPUT_DATA
  } state_t;
  
  state_t state;

  uart_receive #(
    .INPUT_CLOCK_FREQ(200_000_000),
    .BAUD_RATE(115200)
  ) uart_rx (
    .clk_in(clk_in),
    .rst_in(rst_in),
    .rx_wire_in(rx_wire_in),
    .new_data_out(uart_new_data),
    .data_byte_out(uart_data)
  );

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      state <= WAIT_BYTE1;
      new_data_out <= 0;
      data_out <= 0;
      assembled_data <= 0;
    end else begin
      case (state)
        WAIT_BYTE1: begin
          new_data_out <= 0;
          if (uart_new_data) begin
            // Check for first alignment 00
            if (uart_data[7:6] == 2'b00) begin
              assembled_data[5:0] <= uart_data[5:0];
              state <= WAIT_BYTE2;
            end
          end
        end

        WAIT_BYTE2: begin
          if (uart_new_data) begin
            // Check for second alignment 01
            if (uart_data[7:6] == 2'b01) begin
              assembled_data[11:6] <= uart_data[5:0];
              state <= WAIT_BYTE3;
            end else begin
              state <= WAIT_BYTE1;
            end
          end
        end

        WAIT_BYTE3: begin
          if (uart_new_data) begin
            // Check for third alignment 10
            if (uart_data[7:5] == 3'b100) begin
              assembled_data[16:12] <= uart_data[4:0];
              state <= OUTPUT_DATA;
            end else begin
              state <= WAIT_BYTE1;
            end
          end
        end

        OUTPUT_DATA: begin
          new_data_out <= 1;
          data_out <= assembled_data;
          state <= WAIT_BYTE1;
        end
      endcase
    end
  end

endmodule

`default_nettype wire