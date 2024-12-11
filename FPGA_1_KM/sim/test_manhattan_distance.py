import cocotb
import os
import random
from pathlib import Path
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.runner import get_runner

async def calculate_manhattan_distance(dut, x1, y1, x2, y2):
    dut.valid_in.value = 0
    await RisingEdge(dut.clk_in)

    dut.x_1.value = x1
    dut.y_1.value = y1
    dut.x_2.value = x2
    dut.y_2.value = y2
    dut.valid_in.value = 1
    
    await RisingEdge(dut.clk_in)
    dut.valid_in.value = 0
    
    while not dut.valid_out.value:
        await RisingEdge(dut.clk_in)
    
    distance = int(dut.distance_out.value)
    
    await RisingEdge(dut.clk_in)
    
    return distance

@cocotb.test()
async def manhattan_distance_test(dut):
    clock = Clock(dut.clk_in, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.valid_in.value = 0
    dut.x_1.value = 0
    dut.y_1.value = 0
    dut.x_2.value = 0
    dut.y_2.value = 0
    
    for _ in range(3):
        await RisingEdge(dut.clk_in)

    test_cases = [
        (0, 0, 3, 4, 7),    
        (10, 10, 10, 10, 0),
        (0, 0, 5, 0, 5), 
        (0, 0, 0, 5, 5),  
        (100, 100, 90, 95, 15), 
    ]
    
    for x1, y1, x2, y2, expected_dist in test_cases:
        dut._log.info(f"Testing Manhattan distance between ({x1},{y1}) and ({x2},{y2})")
        distance = await calculate_manhattan_distance(dut, x1, y1, x2, y2)
        
        assert distance == expected_dist, \
            f"Wrong distance: got {distance}, expected {expected_dist}"
        
        dut._log.info(f"Distance: {distance}")
        
        for _ in range(2):
            await RisingEdge(dut.clk_in)
    
    
    for i in range(20):
        x1 = random.randint(0, 511)  # 9-bit
        y1 = random.randint(0, 255)  # 8-bit
        x2 = random.randint(0, 511)  # 9-bit
        y2 = random.randint(0, 255)  # 8-bit
        
        expected_dist = abs(x1 - x2) + abs(y1 - y2)
        
        dut._log.info(f"Test {i+1}: Points ({x1},{y1}) and ({x2},{y2})")
        distance = await calculate_manhattan_distance(dut, x1, y1, x2, y2)
        
        assert distance == expected_dist, \
            f"Wrong distance: got {distance}, expected {expected_dist}"
        
        dut._log.info(f"Distance: {distance}")
        dut._log.info("-" * 50)
        
        for _ in range(2):
            await RisingEdge(dut.clk_in)

def manhattan_distance_runner():
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    
    sources = []
    sources += [proj_path / "hdl" / "manhattan_distance.sv"]
    
    build_test_args = ["-Wall"]
    parameters = {}
    
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="manhattan_distance",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale=('1ns', '1ps'),
        waves=True
    )
    
    run_test_args = []
    runner.test(
        hdl_toplevel="manhattan_distance",
        test_module="test_manhattan_distance",
        test_args=run_test_args,
        waves=True
    )

manhattan_distance_runner()