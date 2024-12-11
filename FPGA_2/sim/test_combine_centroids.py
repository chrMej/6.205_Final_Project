import cocotb
import os
import random
import sys
import logging
from pathlib import Path
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner
from cocotb.clock import Clock
from cocotb.binary import BinaryValue

async def reset_dut(dut):
    dut.rst_in.value = 1
    await RisingEdge(dut.clk_in)
    await RisingEdge(dut.clk_in)
    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)

async def send_input_data(dut, local_x, local_y, uart_z, uart_y, delay_between=0):
    dut.local_valid_in.value = 0
    dut.uart_valid_in.value = 0
    await RisingEdge(dut.clk_in)
    
    dut.local_x_in.value = local_x
    dut.local_y_in.value = local_y
    dut.local_valid_in.value = 1
    await RisingEdge(dut.clk_in)
    dut.local_valid_in.value = 0
    
    for _ in range(delay_between):
        await RisingEdge(dut.clk_in)
    
    dut.uart_z_in.value = uart_z
    dut.uart_y_in.value = uart_y
    dut.uart_valid_in.value = 1
    await RisingEdge(dut.clk_in)
    dut.uart_valid_in.value = 0

async def check_output(dut, expected_x, expected_y, expected_z, timeout=100):
    for _ in range(timeout):
        await RisingEdge(dut.clk_in)
        if dut.valid_out.value == 1:
            assert dut.x_out.value == expected_x, f"Expected x={expected_x}, got {int(dut.x_out.valu)}"
            assert dut.y_out.value == expected_y, f"Expected y={expected_y}, got {int(dut.y_out.value)}"
            assert dut.z_out.value == expected_z, f"Expected z={expected_z}, got {int(dut.z_out.value)}"
            return
    raise TimeoutError("Output valid signal never asserted")

@cocotb.test()
async def test_combine_centroids(dut):
    clock = Clock(dut.clk_in, 5, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.local_valid_in.value = 0
    dut.uart_valid_in.value = 0
    
    await reset_dut(dut)
    
    await send_input_data(
        dut,
        local_x=100,
        local_y=50,
        uart_z=200,
        uart_y=50
    )
    await check_output(
        dut,
        expected_x=100,
        expected_y=50,  
        expected_z=200
    )
    
    await send_input_data(
        dut,
        local_x=511, 
        local_y=255, 
        uart_z=511,
        uart_y=255
    )
    await check_output(
        dut,
        expected_x=511,
        expected_y=255,
        expected_z=511
    )
    
    await send_input_data(
        dut,
        local_x=0,
        local_y=0,
        uart_z=0,
        uart_y=0
    )
    await check_output(
        dut,
        expected_x=0,
        expected_y=0,
        expected_z=0
    )
    
    await send_input_data(
        dut,
        local_x=100,
        local_y=40,
        uart_z=300,
        uart_y=60,
        delay_between=5
    )
    await check_output(
        dut,
        expected_x=100,
        expected_y=50,
        expected_z=300
    )
    
    for _ in range(3):
        local_x = random.randint(0, 511)
        local_y = random.randint(0, 255)
        uart_z = random.randint(0, 511)
        uart_y = random.randint(0, 255)
        
        await send_input_data(
            dut,
            local_x=local_x,
            local_y=local_y,
            uart_z=uart_z,
            uart_y=uart_y
        )
        await check_output(
            dut,
            expected_x=local_x,
            expected_y=(local_y + uart_y) // 2,
            expected_z=uart_z
        )
    
    dut.local_valid_in.value = 0
    dut.uart_valid_in.value = 0
    await RisingEdge(dut.clk_in)
    
    dut.local_x_in.value = 150
    dut.local_y_in.value = 75
    dut.local_valid_in.value = 1
    await RisingEdge(dut.clk_in)
    dut.local_valid_in.value = 0
    
    dut.local_x_in.value = 160
    dut.local_y_in.value = 80
    dut.local_valid_in.value = 1
    await RisingEdge(dut.clk_in)
    dut.local_valid_in.value = 0
    
    dut.uart_z_in.value = 250
    dut.uart_y_in.value = 100
    dut.uart_valid_in.value = 1
    await RisingEdge(dut.clk_in)
    dut.uart_valid_in.value = 0
    
    await check_output(
        dut,
        expected_x=160,
        expected_y=90,  
        expected_z=250
    )

def combine_centroids_runner():
    """Simulate the center of mass calculator"""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    
    sources = [
        proj_path / "hdl" / "divider.sv",
        proj_path / "hdl" / "combine_centroids.sv"
    ]
    
    build_test_args = ["-Wall"]
    parameters = {}
    
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="combine_centroids",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale=('1ns', '1ps'),
        waves=True
    )
    
    run_test_args = []
    runner.test(
        hdl_toplevel="combine_centroids",
        test_module="test_combine_centroids",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    combine_centroids_runner()