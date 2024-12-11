`timescale 1ns / 1ps
`default_nettype none

module uart_wrapper
  #(
    parameter INPUT_CLOCK_FREQ = 200_000_000,
    parameter BAUD_RATE = 115200
    )
   (
    input wire        clk_in,
    input wire        rst_in,
    input wire [16:0]  data_in,
    input wire        trigger_in,
    output logic      busy_out,
    output logic      tx_wire_out
    );

    typedef enum logic [1:0] {
      IDLE,
      SEND_BYTE1,
      SEND_BYTE2,
      SEND_BYTE3
    } uart_state;

    uart_state state;
    logic [16:0] data_buffer;
    logic uart_trigger;
    logic uart_busy;
    logic [7:0] uart_data;

    uart_transmit #(
      .INPUT_CLOCK_FREQ(INPUT_CLOCK_FREQ),
      .BAUD_RATE(BAUD_RATE)
    ) uart_tx (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .data_byte_in(uart_data),
      .trigger_in(uart_trigger),
      .busy_out(uart_busy),
      .tx_wire_out(tx_wire_out)
    );

    always_ff @(posedge clk_in) begin
      if(rst_in) begin
        state <= IDLE;
        busy_out <= 0;
        uart_trigger <= 0;
        data_buffer <= 0;
        uart_data <= 0;
      end else begin
        case (state)
          IDLE: begin
            uart_trigger <= 0;
            if (trigger_in && !busy_out) begin
              state <= SEND_BYTE1;
              busy_out <= 1;
              data_buffer <= data_in;
              uart_data <= {2'b00, data_in[5:0]};
              uart_trigger <= 1;
            end
          end

          SEND_BYTE1: begin
            uart_trigger <= 0;
            if (!uart_busy && !uart_trigger) begin
              state <= SEND_BYTE2;
              uart_data <= {2'b01, data_buffer[11:6]};
              uart_trigger <= 1;
            end
          end

          SEND_BYTE2: begin
            uart_trigger <= 0;
            if (!uart_busy && !uart_trigger) begin
              state <= SEND_BYTE3;
              uart_data <= {3'b100, data_buffer[16:12]};
              uart_trigger <= 1;
            end
          end

          SEND_BYTE3: begin
            uart_trigger <= 0;
            if (!uart_busy) begin
              state <= IDLE;
              busy_out <= 0;
            end
          end
        endcase
      end
    end


endmodule
`default_nettype wire