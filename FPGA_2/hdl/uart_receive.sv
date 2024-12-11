`timescale 1ns / 1ps
`default_nettype none

module uart_receive
  #(
    parameter INPUT_CLOCK_FREQ = 100_000_000,
    parameter BAUD_RATE = 9600
    )
   (
    input wire 	       clk_in,
    input wire 	       rst_in,
    input wire 	       rx_wire_in,
    output logic       new_data_out,
    output logic [7:0] data_byte_out
    );
    localparam BAUD_BIT_PERIOD = INPUT_CLOCK_FREQ / BAUD_RATE;
    localparam HALF_BAUD_BIT_PERIOD = BAUD_BIT_PERIOD >> 1;

    typedef enum logic [2:0] {IDLE, START, DATA, STOP, TRANSMIT} uart_state;
    uart_state state;

    logic [7:0] data_received_buffer;
    logic [3:0] bits_received;
    logic [$clog2(BAUD_BIT_PERIOD)-1:0] clock_cycles_elapsed;
    logic invalid_start;

    always_comb begin
      new_data_out = (state == TRANSMIT);
      data_byte_out = (state == TRANSMIT) ? data_received_buffer : 8'b0;
    end

    always_ff @(posedge clk_in) begin
      if (rst_in) begin
        state <= IDLE;
        clock_cycles_elapsed <= 0;
        bits_received <= 0;
        data_received_buffer <= 8'b0;
      end else begin
        case(state)
          IDLE: begin
            state <= !rx_wire_in ? START : IDLE; // 0 detected? start : stay idle
            clock_cycles_elapsed <= 0;
            bits_received <= 0;
            invalid_start <= 0;
          end

          START: begin
            if (clock_cycles_elapsed == HALF_BAUD_BIT_PERIOD) begin
              invalid_start <= rx_wire_in;
              clock_cycles_elapsed <= clock_cycles_elapsed + 1;
            end else if (clock_cycles_elapsed == BAUD_BIT_PERIOD) begin
              state <= invalid_start ? IDLE : DATA;
              clock_cycles_elapsed <= 0;
            end else begin
              clock_cycles_elapsed <= clock_cycles_elapsed + 1;
            end
          end

          DATA: begin
            if (clock_cycles_elapsed == HALF_BAUD_BIT_PERIOD) begin           // every time counter hits half period log a value
              data_received_buffer <= {rx_wire_in, data_received_buffer[7:1]};
              bits_received <= bits_received + 1;
              clock_cycles_elapsed <= clock_cycles_elapsed + 1;
            end else if (clock_cycles_elapsed == BAUD_BIT_PERIOD) begin       // only reset counter after a full period
              clock_cycles_elapsed <= 0;
              if (bits_received == 8) state <= STOP;
            end else begin
              clock_cycles_elapsed <= clock_cycles_elapsed + 1;
            end
          end

          STOP: begin
            if (clock_cycles_elapsed == HALF_BAUD_BIT_PERIOD) begin
              state <= rx_wire_in ? TRANSMIT : IDLE;
              clock_cycles_elapsed <= clock_cycles_elapsed + 1;
            end else if (clock_cycles_elapsed == BAUD_BIT_PERIOD) begin       // only reset counter after a full period
              clock_cycles_elapsed <= 0;
            end else begin
              clock_cycles_elapsed <= clock_cycles_elapsed + 1;
            end
          end

          TRANSMIT: state <= IDLE;

          default: state <= IDLE;
        endcase
      end
    end

endmodule // uart_receive

`default_nettype wire
