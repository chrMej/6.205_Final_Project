`timescale 1ns / 1ps
`default_nettype none

module uart_transmit 
  #(
    parameter INPUT_CLOCK_FREQ = 100_000_000,
    parameter BAUD_RATE = 9600
    )
   (
    input wire        clk_in,
    input wire        rst_in,
    input wire [7:0]  data_byte_in,
    input wire        trigger_in,
    output logic      busy_out,
    output logic      tx_wire_out
    );
  localparam BAUD_BIT_PERIOD = INPUT_CLOCK_FREQ / BAUD_RATE;
  logic [7:0] send_data_buffer;
  logic [$clog2(BAUD_BIT_PERIOD) - 1:0] bit_uptime;
  logic [3:0] bit_progress;

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      busy_out <= 0;
      tx_wire_out <= 1;
      send_data_buffer <= 0;
      bit_uptime <= 0;
      bit_progress <= 0;
    end else if (trigger_in && !busy_out) begin
      busy_out <= 1;
      tx_wire_out <= 0;
      send_data_buffer <= data_byte_in;
      bit_uptime <= 0;
      bit_progress <= 0;
    end else if (busy_out) begin
      if (bit_uptime == BAUD_BIT_PERIOD - 1) begin
        bit_uptime <= 0;
        bit_progress <= bit_progress + 1;
        case (bit_progress)
          0, 1, 2, 3, 4, 5, 6, 7: begin
            tx_wire_out <= send_data_buffer[0];
            send_data_buffer <= send_data_buffer >> 1;
          end
          8: tx_wire_out <= 1;
          9: begin
            busy_out <= 0;
            tx_wire_out <= 1;
          end
        endcase
      end else begin
        bit_uptime <= bit_uptime + 1'b1;
      end
    end else begin
      tx_wire_out <= 1;  // Keep line high when not transmitting
    end
  end
   
endmodule // uart_transmit

`default_nettype wire