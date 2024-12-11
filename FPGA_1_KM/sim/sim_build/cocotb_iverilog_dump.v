module cocotb_iverilog_dump();
initial begin
    $dumpfile("/Users/christophermejia/school/6.205/FinalProj/FPGA_1/sim/sim_build/uart_wrapper.fst");
    $dumpvars(0, uart_wrapper);
end
endmodule
