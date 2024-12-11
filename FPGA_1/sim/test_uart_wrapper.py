import cocotb
import os
import random
import sys
from math import log
import logging
from pathlib import Path
from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles, RisingEdge, FallingEdge, ReadOnly, with_timeout
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner

def reverse_bits(n, size):
    reversed_n = 0
    for i in range(size):
        reversed_n = (reversed_n << 1) | (n & 1)
        n >>= 1
    return reversed_n

@cocotb.test()
async def test_17bit_transmission(dut):
    INPUT_CLOCK_FREQ = 100_000_000
    BAUD_RATE = 9600
    BAUD_BIT_PERIOD = int(INPUT_CLOCK_FREQ / BAUD_RATE)
    CLOCK_PERIOD = 10  

    dut._log.info(f"BAUD_BIT_PERIOD: {BAUD_BIT_PERIOD} clock cycles")
    
    clock = Clock(dut.clk_in, CLOCK_PERIOD, units="ns")
    cocotb.start_soon(clock.start())

    data = 0b1_01010101_01010101

    dut.rst_in.value = 1
    dut.trigger_in.value = 0
    dut.data_in.value = data
    await ClockCycles(dut.clk_in, 3)
    assert dut.busy_out.value == 0, "busy_out is not 0 on reset"
    assert dut.tx_wire_out.value == 1, "tx_wire_out is not 1 on idle"

    await FallingEdge(dut.clk_in)
    dut.rst_in.value = 0
    await ClockCycles(dut.clk_in, 3)
    await FallingEdge(dut.clk_in)

    dut.trigger_in.value = 1
    await ClockCycles(dut.clk_in, 1, rising=False)
    dut.trigger_in.value = 0

    bytes_received = []
    
    for byte_num in range(3):
        while dut.tx_wire_out.value == 1:
            await FallingEdge(dut.clk_in)

        dut._log.info(f"Start bit detected for byte {byte_num}")
        bit_log = [0]

        await ClockCycles(dut.clk_in, BAUD_BIT_PERIOD)
        
        for bit in range(9):  
            await ClockCycles(dut.clk_in, BAUD_BIT_PERIOD//2)
            bit_value = dut.tx_wire_out.value
            bit_log.append(bit_value)
            dut._log.info(f"Byte {byte_num}, Bit {bit}: busy_out = {dut.busy_out.value}, tx_wire_out = {bit_value}")

            if bit != 8:
                await ClockCycles(dut.clk_in, BAUD_BIT_PERIOD//2)

        dut._log.info(f"Byte {byte_num} TX wire log: {bit_log}")
        
        start_bit = bit_log[0]
        data_bits = bit_log[1:9]
        stop_bit = bit_log[9]

        assert start_bit == 0, f"Start bit should be 0, got {start_bit}"
        assert stop_bit == 1, f"Stop bit should be 1, got {stop_bit}"

        received_byte = int(''.join(map(str, reversed(data_bits))), 2)
        bytes_received.append(received_byte)
        dut._log.info(f"Received byte {byte_num}: 0x{received_byte:02X}")

        await ClockCycles(dut.clk_in, BAUD_BIT_PERIOD//2)

    expected_data = data
    received_data = bytes_received[0] | (bytes_received[1] << 8) | ((bytes_received[2] & 0x1) << 16)
    
    assert received_data == expected_data, f"Data not matching. Expected 0x{expected_data:05X}, got 0x{received_data:05X}"


def uart_wrapper_runner():
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    
    sys.path.append(str(proj_path / "sim" / "model"))
    
    sources = [
        proj_path / "hdl" / "uart_transmit.sv",
        proj_path / "hdl" / "uart_wrapper.sv"
    ]
    
    build_test_args = ["-Wall"]
    parameters = {}
    
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="uart_wrapper",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale=('1ns', '1ps'),
        waves=True
    )
    
    run_test_args = []
    runner.test(
        hdl_toplevel="uart_wrapper",
        test_module="test_uart_wrapper",
        test_args=run_test_args,
        waves=True
    )

uart_wrapper_runner()