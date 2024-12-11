import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, ClockCycles
from PIL import Image, ImageDraw
import random
import numpy as np
from pathlib import Path
import os

def create_test_image(width=320, height=180):
    image = Image.new('RGB', (width, height), 'black')
    draw = ImageDraw.Draw(image)
    
    radius = 30
    circle1_center = (80, height//2) 
    circle2_center = (240, height//2)
    
    draw.ellipse([circle1_center[0]-radius, circle1_center[1]-radius,
                  circle1_center[0]+radius, circle1_center[1]+radius], fill='red')
    draw.ellipse([circle2_center[0]-radius, circle2_center[1]-radius,
                  circle2_center[0]+radius, circle2_center[1]+radius], fill='red')
    
    return image

def draw_centroids(image, c1_x, c1_y, c2_x, c2_y, color='yellow', radius=5):
    draw = ImageDraw.Draw(image)
    draw.ellipse([c1_x-radius, c1_y-radius, c1_x+radius, c1_y+radius], fill=color)
    draw.ellipse([c2_x-radius, c2_y-radius, c2_x+radius, c2_y+radius], fill=color)
    return image

@cocotb.test()
async def test_kmeans(dut):
    clock = Clock(dut.clk_in, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    image = create_test_image()
    
    c1_x = random.randint(0, 319)
    c1_y = random.randint(0, 179)
    c2_x = random.randint(0, 319)
    c2_y = random.randint(0, 179)
    
    initial_viz = image.copy()
    draw_centroids(initial_viz, c1_x, c1_y, c2_x, c2_y, color='blue')
    initial_viz.save('initial_centroids.png')
    
    dut.rst_in.value = 1
    await ClockCycles(dut.clk_in, 5)
    dut.rst_in.value = 0
    
    dut.c1_x_in.value = c1_x
    dut.c1_y_in.value = c1_y
    dut.c2_x_in.value = c2_x
    dut.c2_y_in.value = c2_y
    
    for y in range(180):
        for x in range(320):
            pixel = image.getpixel((x, y))
            if pixel == (255, 0, 0):
                dut.valid_in.value = 1
                dut.x_in.value = x
                dut.y_in.value = y
                await ClockCycles(dut.clk_in, 1)

    dut.start_in.value = 1
    await ClockCycles(dut.clk_in, 1)
    dut.start_in.value = 0
    
    dut.valid_in.value = 0
    while dut.valid_out.value == 0:
        await ClockCycles(dut.clk_in, 1)
    
    final_c1_x = int(dut.c1_x_out.value)
    final_c1_y = int(dut.c1_y_out.value)
    final_c2_x = int(dut.c2_x_out.value)
    final_c2_y = int(dut.c2_y_out.value)
    
    final_viz = image.copy()
    draw_centroids(final_viz, final_c1_x, final_c1_y, final_c2_x, final_c2_y, color='green')
    final_viz.save('final_centroids.png')
    
    print(f"Initial centroids: C1({c1_x}, {c1_y}), C2({c2_x}, {c2_y})")
    print(f"Final centroids: C1({final_c1_x}, {final_c1_y}), C2({final_c2_x}, {final_c2_y})")

def test_runner():
    """Simulate using the Python runner"""
    from cocotb.runner import get_runner
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    
    sources = [
        proj_path / "hdl" / "kmeans.sv",
        proj_path / "hdl" / "manhattan_distance.sv",
        proj_path / "hdl" / "comparator.sv",
        proj_path / "hdl" / "center_of_mass.sv",
        proj_path / "hdl" / "divider.sv",
        ]
    
    build_test_args = ["-Wall"]
    parameters = {}
    
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="kmeans",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale=('1ns', '1ps'),
        waves=True
    )
    
    run_test_args = []
    runner.test(
        hdl_toplevel="kmeans",
        test_module="test_kmeans",
        test_args=run_test_args,
        waves=True
    )

test_runner()