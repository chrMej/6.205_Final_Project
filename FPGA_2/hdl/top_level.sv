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
    output logic [2:0]  rgb0,
    output logic [2:0]  rgb1,
    // seven segment
    output logic [3:0]  ss0_an,//anode control for upper four digits of seven-seg display
    output logic [3:0]  ss1_an,//anode control for lower four digits of seven-seg display
    output logic [6:0]  ss0_c, //cathode controls for the segments of upper four digits
    output logic [6:0]  ss1_c, //cathod controls for the segments of lower four digits
    input wire 				  uart_rxd, // UART computer-FPGA
    input wire          fpga_rx,
    output logic        uart_txd,  // fpga to computer
    output logic        fpga_tx,
    output logic [2:0]  hdmi_tx_p, //hdmi output signals (positives) (blue, green, red)
    output logic [2:0]  hdmi_tx_n, //hdmi output signals (negatives) (blue, green, red)
    output logic        hdmi_clk_p, hdmi_clk_n //differential hdmi clock
  );

  assign rgb0 = 0;
  assign rgb1 = 0;

  logic sys_rst;
  logic clk_camera;
  logic clk_xc;
  logic clk_100_passthrough;
  logic clk_pixel;
  logic clk_5x;

  // System reset
  assign sys_rst = btn[0];

  // Clock wizard generate camera clocks
  cw_fast_clk_wiz wizard_migcam
    (.clk_in1(clk_100mhz),
     .clk_camera(clk_camera),
     .clk_xc(clk_xc),
     .clk_100(clk_100_passthrough),
     .reset(0));

  cw_hdmi_clk_wiz wizard_hdmi
    (.sysclk(clk_100_passthrough),
    .clk_pixel(clk_pixel),
    .clk_tmds(clk_5x),
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

  logic [7:0] cam_red, cam_green, cam_blue;
  assign cam_red   = {camera_pixel[15:11], 3'b0};
  assign cam_green = {camera_pixel[10:5], 2'b0};
  assign cam_blue  = {camera_pixel[4:0], 3'b0};

  logic [9:0] y_full, cr_full, cb_full;
  logic [7:0] y, cr, cb;

  // RGB TO YCRB

  rgb_to_ycrcb rgbtoycrcb_m(
    .clk_in(clk_camera),
    .r_in(cam_red),
    .g_in(cam_green),
    .b_in(cam_blue),
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

  logic local_ready;

  always_ff @(posedge clk_camera) begin
    if (sys_rst) begin
      x_com <= 0;
      y_com <= 0;
    end else begin
      if(new_com) begin
        x_com <= x_com_calc;
        y_com <= y_com_calc;
        local_ready <= 1'b1;
      end else begin
        local_ready <= 0;
      end
    end
  end

  // UART TRANSMIT AA to Start second FPGA transmit (BUTTON 1)
  uart_transmit #(
    .INPUT_CLOCK_FREQ(200_000_000),
    .BAUD_RATE(115200)
  ) fpga_tx_m (
    .clk_in(clk_camera),
    .rst_in(sys_rst),
    .data_byte_in(8'b10101010),
    .trigger_in(btn[1]),
    .busy_out(),
    .tx_wire_out(fpga_tx)
  );

  logic fpga_rx_new_data;
  logic [7:0] uart_y;
  logic [8:0] uart_z;

  // // UART Receive FSM 
  uart_rx_wrapper #(
    .INPUT_CLOCK_FREQ(200_000_000),
    .BAUD_RATE(115200)
  ) fpga_rx_m (
    .clk_in(clk_camera),
    .rst_in(sys_rst),
    .rx_wire_in(fpga_rx),
    .new_data_out(fpga_rx_new_data),
    .data_out({uart_z, uart_y})
  );

  // Combine centroids
  logic [8:0] centroid_x;
  logic [7:0] centroid_y;
  logic [8:0] centroid_z;
  logic centroid_ready;

  combine_centroids combine (
    .clk_in(clk_camera),
    .rst_in(sys_rst),
    .local_x_in(x_com),
    .local_y_in(y_com),
    .local_valid_in(local_ready),
    .uart_z_in(uart_z),
    .uart_y_in(uart_y),
    .uart_valid_in(fpga_rx_new_data),
    .x_out(centroid_x),
    .y_out(centroid_y),
    .z_out(centroid_z),
    .valid_out(centroid_ready)
  );

  // combine_centroids combine (
  //   .clk_in(clk_camera),
  //   .rst_in(sys_rst),
  //   .local_x_in(x_com),
  //   .local_y_in(y_com),
  //   .local_valid_in(local_ready),
  //   .uart_z_in(160),
  //   .uart_y_in(y_com),
  //   .uart_valid_in(1'b1),
  //   .x_out(centroid_x),
  //   .y_out(centroid_y),
  //   .z_out(centroid_z),
  //   .valid_out(centroid_ready)
  // );

  logic [8:0] point_x;
  logic [7:0] point_y;
  logic [8:0] point_z;
  logic interp_done;
  interpolate interp(
    .clk_in(clk_camera),
    .rst_in(sys_rst),
    .centroid_x(centroid_x),
    .centroid_y(centroid_y),
    .centroid_z(centroid_z),
    .centroid_ready(centroid_ready),
    .point_x(point_x),
    .point_y(point_y),
    .point_z(point_z),
    .interp_done(interp_done)
  );

  logic [11:0] addra;
  logic [11:0] addrb;

  logic [25:0] point_data;

  typedef enum logic [1:0] {
    DRAWING,
    REVIEWING
  } mode_t;
  logic [3:0] issued_read;
  logic [11:0] num_points;
  mode_t mode, last_mode;

  always_ff @(posedge clk_camera) begin
    last_mode <= mode;
    if (sys_rst) begin
      mode <= DRAWING;
      last_mode <= DRAWING;
    end else begin
      mode <= sw[0] ? DRAWING : REVIEWING;
    end
  end

  // Address Counter for Drawing Mode
  always_ff @(posedge clk_camera) begin
    if (sys_rst) begin
        addra <= 0;
        num_points <= 0;
    end else if (mode == DRAWING && (centroid_ready || ~interp_done)) begin
        addra <= (addra == 2249) ? 0 : addra + 1;
        num_points <= (num_points == 2250) ? 2250 : num_points + 1;
    end
  end

  always_ff @(posedge clk_camera) begin
    if (sys_rst) begin
        addrb <= 0;
        issued_read <= 0;
    end else begin
        issued_read[3:1] <= issued_read[2:0]; 
        
        if (mode != last_mode) begin
            addrb <= 0;
            issued_read[0] <= 1'b1;  // Initial read on mode change
        end else if (projection_done) begin  // wait for projection ready
            if (num_points > 0) begin
                if (addrb + 1 < num_points) begin
                    addrb <= addrb + 1;
                end else begin
                    addrb <= 0;
                end
                issued_read[0] <= 1'b1;
            end
        end else if (centroid_ready && (num_points == 1)) begin  // First point trigger
            // When we get our very first point, trigger initial read
            addrb <= 0;
            issued_read[0] <= 1'b1;
        end else begin
            issued_read[0] <= 1'b0;
        end
    end
  end

  // POINT_MEMORY BRAM 2250x26
  xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(26),
    .RAM_DEPTH(2250),
    .RAM_PERFORMANCE("HIGH_PERFORMANCE")
  ) point_memory (
    .addra(addra),
    .addrb(addrb),
    .dina({point_x, point_y, point_z}),
    .dinb(26'b0),
    .clka(clk_camera),
    .clkb(clk_camera), // DOUBLE CHECK LATER TO MAKE SURE ALL RENDERING STUFF CAN GO AT 200MHZ
    .wea((centroid_ready || ~interp_done) && (mode == DRAWING)),
    .web(1'b0), // NEVER WRITE FROM PORT B SIDE ONLY READ
    .ena(1'b1),
    .enb(1'b1),
    .rsta(1'b0),
    .rstb(1'b0),
    .regcea(1'b1),
    .regceb(1'b1),
    .douta(),
    .doutb(point_data)
  );

  logic [31:0] angle;
  logic signed [15:0] cos;
  logic signed [15:0] sin;

  angle_inc ang(
    .clk_in(clk_camera),
    .rst_in(sys_rst),
    .inc(btn[2]),
    .dec(btn[3]),
    .angle(angle)
  );

  cordic angle_cordic(
    .clk_in(clk_camera),
    .rst_in(sys_rst),
    .x(16'h8000),
    .y(0),
    .angle(angle),
    .cos(cos),
    .sin(sin)
  );

  // ROATIONS & PERSPECTIVE PROJECTION
  logic [8:0] x_projection;
  logic [7:0] y_projection;
  logic projection_done;

  perspective_projection proj (
    .clk_in(clk_camera),
    .rst_in(sys_rst),
    .cos(cos),
    .sin(sin),
    .x_in(point_data[25:17]),
    .y_in(point_data[16:9]),
    .z_in(point_data[8:0]),
    .valid_in(issued_read[3]),
    .x_out(x_projection),
    .y_out(y_projection),
    .valid_out(projection_done)
  );

  // logic uart_rx_data_valid;
  // logic [7:0] uart_rx_data;
  // logic start_transmission;

  // // DEBUG UART
  // uart_receive #(
  //   .INPUT_CLOCK_FREQ(200_000_000),
  //   .BAUD_RATE(115200)
  // ) uart_rx (
  //     .clk_in(clk_camera),
  //     .rst_in(sys_rst),
  //     .rx_wire_in(uart_rxd), 
  //     .new_data_out(uart_rx_data_valid),
  //     .data_byte_out(uart_rx_data)
  // );

  // always_ff @(posedge clk_camera) begin
  //   if (sys_rst) begin
  //       start_transmission <= 0;
  //   end else if (uart_rx_data_valid && uart_rx_data == 8'hAA) begin 
  //       start_transmission <= 1;
  //   end
  // end

  // logic uart_busy;
  
  // uart_wrapper #(
  //   .INPUT_CLOCK_FREQ(200_000_000),
  //   .BAUD_RATE(115200)
  // ) uart_out (
  //     .clk_in(clk_camera),
  //     .rst_in(sys_rst),
  //     .data_in({x_projection, y_projection}),  // What we're trying to write
  //     .trigger_in(projection_done && !uart_busy && start_transmission),  // When write should happen
  //     .busy_out(uart_busy),
  //     .tx_wire_out(uart_txd)
  // );
  // DEBUG UART END

  logic angle_changed;
  logic [31:0] last_angle;

  always_ff @(posedge clk_camera) begin
      last_angle <= angle;
      angle_changed <= (angle != last_angle);
  end

  logic clear_frame;
  logic [15:0] clear_addr;

  always_ff @(posedge clk_camera) begin
      if (sys_rst || angle_changed) begin
          clear_frame <= 1'b1;
          clear_addr <= 0;
      end else if (clear_frame) begin
          if (clear_addr == 57599) begin 
              clear_frame <= 1'b0;
          end
          clear_addr <= clear_addr + 1;
      end
  end


  logic [15:0] frame_buffer_addra;
  logic [15:0] frame_buffer_addrb;
  logic frame_buffer_wea;

  always_ff @(posedge clk_camera) begin
    if (sys_rst) begin
      frame_buffer_addra <= 0;
      frame_buffer_wea <= 0;
    end else if (clear_frame) begin
      frame_buffer_addra <= clear_addr;
      frame_buffer_wea <= 1'b1;
    end else if(projection_done) begin
      if (x_projection < 320 && y_projection < 180) begin
        frame_buffer_addra <= x_projection + y_projection * 320;
        frame_buffer_wea <= 1;
      end else begin
        frame_buffer_wea <= 0;
      end
    end else begin
      frame_buffer_wea <= 0;
    end
  end

  logic fb_point_data;
  // // x_projection & y_projection to frame buffer addr logic
  xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(1),
    .RAM_DEPTH(57600),
    .RAM_PERFORMANCE("HIGH_PERFORMANCE")
  ) frame_buffer (
    .addra(frame_buffer_addra),
    .addrb(frame_buffer_addrb),
    .dina(clear_frame ? 1'b0 : 1'b1),
    .dinb(1'b0),
    .clka(clk_camera),
    .clkb(clk_pixel), // DOUBLE CHECK LATER TO MAKE SURE ALL RENDERING STUFF CAN GO AT 200MHZ
    .wea(frame_buffer_wea), // SW[0] TO CONTROL WRITING
    .web(1'b0), // NEVER WRITE FROM PORT B SIDE ONLY READ
    .ena(1'b1),
    .enb(1'b1),
    .rsta(1'b0),
    .rstb(1'b0),
    .regcea(1'b1),
    .regceb(1'b1),
    .douta(),
    .doutb(fb_point_data)
  );

  // HDMI Signal Generator
  logic [10:0]  hcount_hdmi;
  logic [9:0]    vcount_hdmi;
  logic vsync_hdmi;
  logic hsync_hdmi;
  logic nf_hdmi;
  logic active_draw_hdmi;
  logic frame_count_hdmi;
  logic [7:0] red, green, blue;

  video_sig_gen vsg
     (
      .pixel_clk_in(clk_pixel),
      .rst_in(sys_rst),
      .hcount_out(hcount_hdmi),
      .vcount_out(vcount_hdmi),
      .vs_out(vsync_hdmi),
      .hs_out(hsync_hdmi),
      .nf_out(nf_hdmi),
      .ad_out(active_draw_hdmi),
      .fc_out(frame_count_hdmi)
      );

  logic [2:0] display_valid;

  always_ff @(posedge clk_pixel) begin
    display_valid[2] <= display_valid[1];
    display_valid[1] <= display_valid[0];

    if ((hcount_hdmi < 1280) && (vcount_hdmi < 720)) begin
        frame_buffer_addrb <= (319-(hcount_hdmi >> 2)) + 320*(vcount_hdmi >> 2);
        display_valid[0] = 1'b1;
    end else begin
      display_valid[0] = 1'b0;
    end
  end

  always_ff @(posedge clk_pixel) begin
    if (display_valid[2] && fb_point_data) begin
        red <= 8'hFF;
        green <= 8'hFF;
        blue <= 8'hFF;
    end else begin
        red <= 8'h00;
        green <= 8'h00;
        blue <= 8'h00;
    end
  end

  logic [9:0] tmds_10b [0:2]; //output of each TMDS encoder!
  logic       tmds_signal [2:0]; //output of each TMDS serializer!

  //three tmds_encoders (blue, green, red)
  //note green should have no control signal like red
  //the blue channel DOES carry the two sync signals:
  //  * control_in[0] = horizontal sync signal
  //  * control_in[1] = vertical sync signal

  tmds_encoder tmds_red(
      .clk_in(clk_pixel),
      .rst_in(sys_rst),
      .data_in(red),
      .control_in(2'b0),
      .ve_in(active_draw_hdmi),
      .tmds_out(tmds_10b[2]));

  tmds_encoder tmds_green(
        .clk_in(clk_pixel),
        .rst_in(sys_rst),
        .data_in(green),
        .control_in(2'b0),
        .ve_in(active_draw_hdmi),
        .tmds_out(tmds_10b[1]));

  tmds_encoder tmds_blue(
      .clk_in(clk_pixel),
      .rst_in(sys_rst),
      .data_in(blue),
      .control_in({vsync_hdmi,hsync_hdmi}),
      .ve_in(active_draw_hdmi),
      .tmds_out(tmds_10b[0]));


  //three tmds_serializers (blue, green, red):
  //MISSING: two more serializers for the green and blue tmds signals.
  tmds_serializer red_ser(
        .clk_pixel_in(clk_pixel),
        .clk_5x_in(clk_5x),
        .rst_in(sys_rst),
        .tmds_in(tmds_10b[2]),
        .tmds_out(tmds_signal[2]));
  tmds_serializer green_ser(
        .clk_pixel_in(clk_pixel),
        .clk_5x_in(clk_5x),
        .rst_in(sys_rst),
        .tmds_in(tmds_10b[1]),
        .tmds_out(tmds_signal[1]));
  tmds_serializer blue_ser(
        .clk_pixel_in(clk_pixel),
        .clk_5x_in(clk_5x),
        .rst_in(sys_rst),
        .tmds_in(tmds_10b[0]),
        .tmds_out(tmds_signal[0]));

  //output buffers generating differential signals:
  //three for the r,g,b signals and one that is at the pixel clock rate
  //the HDMI receivers use recover logic coupled with the control signals asserted
  //during blanking and sync periods to synchronize their faster bit clocks off
  //of the slower pixel clock (so they can recover a clock of about 742.5 MHz from
  //the slower 74.25 MHz clock)
  OBUFDS OBUFDS_blue (.I(tmds_signal[0]), .O(hdmi_tx_p[0]), .OB(hdmi_tx_n[0]));
  OBUFDS OBUFDS_green(.I(tmds_signal[1]), .O(hdmi_tx_p[1]), .OB(hdmi_tx_n[1]));
  OBUFDS OBUFDS_red  (.I(tmds_signal[2]), .O(hdmi_tx_p[2]), .OB(hdmi_tx_n[2]));
  OBUFDS OBUFDS_clock(.I(clk_pixel), .O(hdmi_clk_p), .OB(hdmi_clk_n));

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

  // always_ff @(posedge clk_camera) begin
  //   if (issued_read[3]) begin
  //     led[3] <= 1;
  //   end
  // end

  always_ff @(posedge clk_camera) begin 
    if (sys_rst) begin
      led[0] <= 0;
      led[1] <= 0;
    end else begin
      if (fpga_rx_new_data) begin
        led[0] <= 1;
      end

      if (local_ready) begin
        led[1] <= 1;
      end
    end
  end

  // a handful of debug signals for writing to registers
  // assign led[0] = fpga_rx_new_data;  // Is wea ever high?
  // assign led[1] = local_ready;  // Is write address incrementing?
  assign led[2] = (mode == DRAWING);  // Are we in DRAWING mode?
  assign led[15:3] = 0;

endmodule


`default_nettype wire
