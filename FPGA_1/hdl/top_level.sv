`timescale 1ns / 1ps
`default_nettype none

module top_level
  (
    input wire          clk_100mhz,
    output logic [15:0] led,
    // camera bus
    input wire [7:0]    camera_d, // 8 parallel data wires
    output logic        cam_xclk, // XC driving camera
    input wire          cam_hsync, // camera hsync wire
    input wire          cam_vsync, // camera vsync wire
    input wire          cam_pclk, // camera pixel clock
    inout wire          i2c_scl, // i2c inout clock
    inout wire          i2c_sda, // i2c inout data
    input wire [15:0]   sw,
    input wire [3:0]    btn,
    // output logic [2:0]  rgb0,
    // output logic [2:0]  rgb1,
    // seven segment
    output logic [3:0]  ss0_an,//anode control for upper four digits of seven-seg display
    output logic [3:0]  ss1_an,//anode control for lower four digits of seven-seg display
    output logic [6:0]  ss0_c, //cathode controls for the segments of upper four digits
    output logic [6:0]  ss1_c, //cathod controls for the segments of lower four digits
    // hdmi port
    // output logic [2:0]  hdmi_tx_p, //hdmi output signals (positives) (blue, green, red)
    // output logic [2:0]  hdmi_tx_n, //hdmi output signals (negatives) (blue, green, red)
    // output logic        hdmi_clk_p, hdmi_clk_n, //differential hdmi clock
    input wire 				 uart_rxd, // UART computer-FPGA
    input wire         fpga_rx,
    output logic       fpga_tx,
    output logic       uart_txd  // fpga to computer
  );

  logic sys_rst;
  logic clk_camera;
  logic clk_xc;
  logic clk_100_passthrough;

  // System reset
  assign sys_rst = btn[0];

  // Clock wizard generate camera clocks
  cw_fast_clk_wiz wizard_migcam
    (.clk_in1(clk_100mhz),
     .clk_camera(clk_camera),
     .clk_xc(clk_xc),
     .clk_100(clk_100_passthrough),
     .reset(0));
  
  // Set driving xclk for camera
  assign cam_xclk = clk_xc;

  // Camera input synchronizers to prevent metastability (sampling an input that happening too close to clock edge)
  logic [7:0]    camera_d_buf [1:0];
  logic          cam_hsync_buf [1:0];
  logic          cam_vsync_buf [1:0];
  logic          cam_pclk_buf [1:0];

  always_ff @(posedge clk_camera) begin
     camera_d_buf <= {camera_d, camera_d_buf[1]};
     cam_pclk_buf <= {cam_pclk, cam_pclk_buf[1]};
     cam_hsync_buf <= {cam_hsync, cam_hsync_buf[1]};
     cam_vsync_buf <= {cam_vsync, cam_vsync_buf[1]};
  end

  // Pixel Reconstruct
  logic [8:0]  camera_hcount;
  logic [7:0]   camera_vcount;
  logic [15:0]  camera_pixel;
  logic         camera_valid;

  pixel_reconstruct pr (
    .clk_in(clk_camera),
    .rst_in(sys_rst),
    .camera_pclk_in(cam_pclk_buf[0]),
    .camera_hs_in(cam_hsync_buf[0]),
    .camera_vs_in(cam_vsync_buf[0]),
    .camera_data_in(camera_d_buf[0]),
    .pixel_valid_out(camera_valid),
    .pixel_hcount_out(camera_hcount),
    .pixel_vcount_out(camera_vcount),
    .pixel_data_out(camera_pixel)
  );

  logic [7:0] red, green, blue;
  assign red   = {camera_pixel[15:11], 3'b0};
  assign green = {camera_pixel[10:5], 2'b0};
  assign blue  = {camera_pixel[4:0], 3'b0};

  logic [9:0] y_full, cr_full, cb_full;
  logic [7:0] y, cr, cb;

  // RGB TO YCRB

  rgb_to_ycrcb rgbtoycrcb_m(
    .clk_in(clk_camera),
    .r_in(red),
    .g_in(green),
    .b_in(blue),
    .y_out(y_full),
    .cr_out(cr_full),
    .cb_out(cb_full)
  );

  assign y = y_full[7:0];
  assign cr = {!cr_full[7], cr_full[6:0]};
  assign cb = {!cb_full[7], cb_full[6:0]};

  // THRESHOLDING
  
  logic [7:0] lower_threshold, upper_threshold;
  assign lower_threshold = {sw[11:8],4'b0};
  assign upper_threshold = {sw[15:12],4'b0};

  logic mask;

  threshold mt (
    .clk_in(clk_camera),
    .rst_in(sys_rst),
    .pixel_in(cr),
    .lower_bound_in(lower_threshold),
    .upper_bound_in(upper_threshold),
    .mask_out(mask)
  );

  // Seven Segment For Tresholding
  logic [6:0] ss_c;
  //modified version of seven segment display for showing
  // thresholds and selected channel
  // special customized version
  lab05_ssc mssc(.clk_in(clk_camera),
                 .rst_in(sys_rst),
                 .lt_in(lower_threshold),
                 .ut_in(upper_threshold),
                 .channel_sel_in(3'b111),
                 .cat_out(ss_c),
                 .an_out({ss0_an, ss1_an})
  );
  assign ss0_c = ss_c; //control upper four digit's cathodes!
  assign ss1_c = ss_c; //same as above but for lower four digits!

  // Center of Mass
  logic [8:0] x_com, x_com_calc;  
  logic [7:0] y_com, y_com_calc;
  logic new_com;

  center_of_mass com_m (
    .clk_in(clk_camera),
    .rst_in(sys_rst),
    .x_in(camera_hcount),
    .y_in(camera_vcount),
    .valid_in(mask),
    .tabulate_in((camera_hcount == 319) && (camera_vcount == 179)),
    .x_out(x_com_calc),
    .y_out(y_com_calc),
    .valid_out(new_com)
  );

  always_ff @(posedge clk_camera) begin
    if (sys_rst) begin
      x_com <= 0;
      y_com <= 0;
    end if(new_com) begin
      x_com <= x_com_calc;
      y_com <= y_com_calc;
    end
  end

  logic uart_rx_data_valid;
  logic [7:0] uart_rx_data;
  logic start_transmission;

  uart_receive #(
    .INPUT_CLOCK_FREQ(200_000_000),
    .BAUD_RATE(115200)
  ) uart_rx (
      .clk_in(clk_camera),
      .rst_in(sys_rst),
      // .rx_wire_in(uart_rxd), 
      .rx_wire_in(fpga_rx),
      .new_data_out(uart_rx_data_valid),
      .data_byte_out(uart_rx_data)
  );

  always_ff @(posedge clk_camera) begin
    if (sys_rst) begin
        start_transmission <= 0;
    end else if (uart_rx_data_valid && uart_rx_data == 8'hAA) begin 
        start_transmission <= 1;
    end
  end

  logic uart_busy;

  // uart_transmit #(
  //     .INPUT_CLOCK_FREQ(200_000_000),
  //     .BAUD_RATE(115200)
  //   ) uart_tx (
  //     .clk_in(clk_camera),
  //     .rst_in(sys_rst),
  //     .data_byte_in(8'b1010_1010),
  //     .trigger_in(btn[1]),
  //     .busy_out(),
  //     .tx_wire_out(fpga_tx)
  //   );

  uart_wrapper #(
    .INPUT_CLOCK_FREQ(200_000_000),
    .BAUD_RATE(115200)
  ) uart_out 
  (
    .clk_in(clk_camera),
    .rst_in(sys_rst),
    .data_in({x_com, y_com}),
    .trigger_in(new_com && !uart_busy && start_transmission),
    .busy_out(uart_busy),
    // .tx_wire_out(uart_txd)
    .tx_wire_out(fpga_tx)
  );

  // Camera set up stuff
  logic  busy, bus_active;
  logic  cr_init_valid, cr_init_ready;

  logic  recent_reset;
  always_ff @(posedge clk_camera) begin
     if (sys_rst) begin
        recent_reset <= 1'b1;
        cr_init_valid <= 1'b0;
     end
     else if (recent_reset) begin
        cr_init_valid <= 1'b1;
        recent_reset <= 1'b0;
     end else if (cr_init_valid && cr_init_ready) begin
        cr_init_valid <= 1'b0;
     end
  end

  logic [23:0] bram_dout;
  logic [7:0]  bram_addr;

  // ROM holding pre-built camera settings to send
  xilinx_single_port_ram_read_first
    #(
      .RAM_WIDTH(24),
      .RAM_DEPTH(256),
      .RAM_PERFORMANCE("HIGH_PERFORMANCE"),
      .INIT_FILE("rom.mem")
      ) registers
      (
       .addra(bram_addr),     // Address bus, width determined from RAM_DEPTH
       .dina(24'b0),          // RAM input data, width determined from RAM_WIDTH
       .clka(clk_camera),     // Clock
       .wea(1'b0),            // Write enable
       .ena(1'b1),            // RAM Enable, for additional power savings, disable port when not in use
       .rsta(sys_rst), // Output reset (does not affect memory contents)
       .regcea(1'b1),         // Output register enable
       .douta(bram_dout)      // RAM output data, width determined from RAM_WIDTH
       );

  logic [23:0] registers_dout;
  logic [7:0]  registers_addr;
  assign registers_dout = bram_dout;
  assign bram_addr = registers_addr;

  logic       con_scl_i, con_scl_o, con_scl_t;
  logic       con_sda_i, con_sda_o, con_sda_t;

  // NOTE these also have pullup specified in the xdc file!
  // access our inouts properly as tri-state pins
  IOBUF IOBUF_scl (.I(con_scl_o), .IO(i2c_scl), .O(con_scl_i), .T(con_scl_t) );
  IOBUF IOBUF_sda (.I(con_sda_o), .IO(i2c_sda), .O(con_sda_i), .T(con_sda_t) );

  // provided module to send data BRAM -> I2C
  camera_registers crw
    (.clk_in(clk_camera),
     .rst_in(sys_rst),
     .init_valid(cr_init_valid),
     .init_ready(cr_init_ready),
     .scl_i(con_scl_i),
     .scl_o(con_scl_o),
     .scl_t(con_scl_t),
     .sda_i(con_sda_i),
     .sda_o(con_sda_o),
     .sda_t(con_sda_t),
     .bram_dout(registers_dout),
     .bram_addr(registers_addr));

  // a handful of debug signals for writing to registers
  assign led[0] = uart_txd;      // UART transmitting
  assign led[1] = start_transmission;       // New coordinates ready
  assign led[2] = new_com;     // UART busy status
  assign led[3] = mask;          // See if threshold detection is working
  assign led[15:4] = 0;

endmodule


`default_nettype wire