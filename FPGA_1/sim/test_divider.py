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

async def generate_clock(clock_wire):
    while True:
        clock_wire.value = 0
        await Timer(5,units="ns")
        clock_wire.value = 1
        await Timer(5,units="ns")

async def reset_dut(dut):
    dut.rst_in.value = 1
    await RisingEdge(dut.clk_in)
    await RisingEdge(dut.clk_in)
    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)

async def perform_division(dut, dividend, divisor):
    dut.dividend_in.value = dividend
    dut.divisor_in.value = divisor
    dut.data_valid_in.value = 1
    
    cycle_count = 0
    await RisingEdge(dut.clk_in)
    cycle_count += 1
    dut.data_valid_in.value = 0

    while dut.data_valid_out.value == 0:
        await RisingEdge(dut.clk_in)
        cycle_count += 1
    
    quotient = int(dut.quotient_out.value)
    remainder = int(dut.remainder_out.value)
    error = int(dut.error_out.value)
    
    await RisingEdge(dut.clk_in)
    cycle_count += 1
    
    return quotient, remainder, error, cycle_count

@cocotb.test()
async def first_test(dut):
    clock = Clock(dut.clk_in, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    test_cases = [
        # (dividend, divisor, expected_quotient, expected_remainder)
        (100, 10, 10, 0),  
        (101, 10, 10, 1),  
        (50, 100, 0, 50),
        (42, 0, 0, 0),
        (0, 5, 0, 0),
    ]
    
    dut._log.info("\nFixed test cases:")
    dut._log.info("-" * 50)
    for dividend, divisor, expected_q, expected_r in test_cases:
        dut._log.info(f"Testing {dividend} / {divisor}")
        quotient, remainder, error, cycles = await perform_division(dut, dividend, divisor)
        
        if divisor == 0:
            assert error == 1, f"Division by zero didnt set error"
        else:
            assert error == 0, f"Error flag should not be set for valid division"
            assert quotient == expected_q, \
                f"Wrong quotient for {dividend}/{divisor}: got {quotient}, expected {expected_q}"
            assert remainder == expected_r, \
                f"Wrong remainder for {dividend}/{divisor}: got {remainder}, expected {expected_r}"
        
        dut._log.info(f"Operation took {cycles} cycles")
        dut._log.info("-" * 50)
        
        for _ in range(3):
            await RisingEdge(dut.clk_in)
    
    dut._log.info("\nRandom test cases:")
    dut._log.info("-" * 50)
    total_cycles = 0
    for i in range(20):
        dividend = random.randint(0, 1000)  
        divisor = random.randint(1, 100)   
        expected_q = dividend // divisor
        expected_r = dividend % divisor
        
        dut._log.info(f"Test {i+1}: {dividend} / {divisor}")
        quotient, remainder, error, cycles = await perform_division(dut, dividend, divisor)
        total_cycles += cycles
        
        assert error == 0, f"Error flag should not be set for valid division"
        assert quotient == expected_q, \
            f"Wrong quotient for {dividend}/{divisor}: got {quotient}, expected {expected_q}"
        assert remainder == expected_r, \
            f"Wrong remainder for {dividend}/{divisor}: got {remainder}, expected {expected_r}"
        
        dut._log.info(f"Operation took {cycles} cycles")
        
        for _ in range(3):
            await RisingEdge(dut.clk_in)
    
    dut._log.info(f"\nAverage cycles for random tests: {total_cycles/20:.1f}")

def divider_runner():
    """Simulate the counter using the Python runner."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    
    sources = []
    sources += [proj_path / "hdl" / "divider.sv"]
    
    build_test_args = ["-Wall"]
    parameters = {}
    
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="divider",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale=('1ns', '1ps'),
        waves=True
    )
    
    run_test_args = []
    runner.test(
        hdl_toplevel="divider",
        test_module="test_divider",
        test_args=run_test_args,
        waves=True
    )

divider_runner()