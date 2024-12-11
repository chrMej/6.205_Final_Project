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

  logic [9:0] cr_full;
  logic [7:0] cr;

  rgb_to_ycrcb rgbtoycrcb_m(
    .clk_in(clk_camera),
    .r_in(red),
    .g_in(green),
    .b_in(blue),
    .y_out(),
    .cr_out(cr_full),
    .cb_out()
  );

  assign cr = {!cr_full[7], cr_full[6:0]};

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

  logic [6:0] ss_c;
  lab05_ssc mssc(.clk_in(clk_camera),
                 .rst_in(sys_rst),
                 .lt_in(lower_threshold),
                 .ut_in(upper_threshold),
                 .channel_sel_in(3'b111),
                 .cat_out(ss_c),
                 .an_out({ss0_an, ss1_an})
  );
  assign ss0_c = ss_c; 
  assign ss1_c = ss_c;

  // 4 Stage pipeline for camera_hcount and camera_vcount 3 (rgb_to_ycrb) + 1 (threshold)
  logic [8:0] hcount_pipe [3:0];
  logic [7:0] vcount_pipe [3:0];
  logic valid_pipe [3:0];

  always_ff @(posedge clk_camera)begin
    hcount_pipe[0] <= camera_hcount;
    vcount_pipe[0] <= camera_vcount;
    valid_pipe[0] <= camera_valid;

    for (int i=1; i<4; i = i+1)begin
      hcount_pipe[i] <= hcount_pipe[i-1];
      vcount_pipe[i] <= vcount_pipe[i-1];
      valid_pipe[i] <= valid_pipe[i-1];
    end
  end

  logic [13:0] addra, addrb;
  logic [13:0] num_points;

  // simple write addra control 
  always_ff @(posedge clk_camera) begin
    if (sys_rst) begin
      addra <= 0;
      num_points <= 0;
    end else begin
      if(mask) begin
        addra <= addra + 1;           // TODO THINK ABOUT ROLL-OVER LOGIC PERHAPS MIGHT ROLL OVER AUTO
        num_points <= num_points == 14400 ? num_points : num_points + 1;
      end
    end
  end

  xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(17),
    .RAM_DEPTH(14400),
    .RAM_PERFORMANCE("HIGH_PERFORMANCE")
  ) point_memory (
    .addra(addra),
    .addrb(addrb),
    .dina({hcount_pipe[3], vcount_pipe[3]}),
    .dinb(17'b0),
    .clka(clk_camera),
    .clkb(clk_camera), 
    .wea(mask),
    .web(1'b0), // NEVER WRITE FROM PORT B SIDE ONLY READ
    .ena(1'b1),
    .enb(1'b1),
    .rsta(1'b0),
    .rstb(1'b0),
    .regcea(1'b1),
    .regceb(1'b1),
    .douta(),
    .doutb({x, y})
  );

  logic start_iteration;
  logic coord_valid;
  logic [8:0] x, c1_x, c2_x;
  logic [7:0] y, c1_y, c2_y;
  logic centroids_ready;
  logic uart_trigger;
  logic reset_coms;

  logic [8:0] new_c1_x, new_c2_x;
  logic [7:0] new_c1_y, new_c2_y;

  kmeans_controller km_c (
    .clk_in(clk_camera),
    .rst_in(sys_rst),
    .hcount_in(hcount_pipe[3]),
    .vcount_in(vcount_pipe[3]),
    .num_points_in(num_points),
    .camera_valid_in(valid_pipe[3]),
    .iteration_finished_in(centroids_ready),
    .addrb_out(addrb),
    .start_iteration_out(start_iteration),
    .km_valid_in(coord_valid),
    .uart_trigger_out(uart_trigger),
    .reset_coms(reset_coms)
  );

  kmeans km (
    .clk_in(clk_camera),
    .start_in(start_iteration),
    .rst_in(sys_rst),
    .rst_coms(reset_coms),
    .valid_in(coord_valid),
    .x_in(x),
    .c1_x_in(c1_x),
    .c2_x_in(c2_x),
    .y_in(y),
    .c1_y_in(c1_y),
    .c2_y_in(c2_y),
    .c1_x_out(new_c1_x),
    .c2_x_out(new_c2_x),
    .c1_y_out(new_c1_y),
    .c2_y_out(new_c2_y),
    .valid_out(centroids_ready)
  );


  always_ff @(posedge clk_camera) begin
    if (sys_rst) begin
      c1_x <= 9'd50;    
      c1_y <= 8'd30;  

      c2_x <= 9'd270;   
      c2_y <= 8'd150; 
    end else if (centroids_ready) begin
      c1_x <= new_c1_x;
      c2_x <= new_c2_x;
      c1_y <= new_c1_y;
      c2_y <= new_c2_y;
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
      .rx_wire_in(uart_rxd), 
      // .rx_wire_in(fpga_rx),
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

  uart_wrapper #(
      .INPUT_CLOCK_FREQ(200_000_000),
      .BAUD_RATE(115200)
  ) uart_out (
      .clk_in(clk_camera),
      .rst_in(sys_rst),
      .c1_data_in({c1_x, c1_y}), 
      .c2_data_in({c2_x, c2_y}),
      .trigger_in(uart_trigger && !uart_busy && start_transmission),
      .busy_out(uart_busy),
      .tx_wire_out(uart_txd)
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

  logic centroid_ever_ready;

  always_ff @(posedge clk_camera) begin
    if (sys_rst) begin
      centroids_ready <= 0;
    end else if (centroids_ready) begin
      centroid_ever_ready <= 1;
    end
  end

  // a handful of debug signals for writing to registers
  assign led[0] = mask;      // UART transmitting
  assign led[1] = centroid_ever_ready;       // New coordinates ready
  assign led[2] = mask;     // UART busy status
  assign led[3] = start_transmission;          // See if threshold detection is working
  assign led[15:4] = 0;

endmodule


`default_nettype wire