`default_nettype none
module interpolate #(
    parameter X_WIDTH = 9,
    parameter Y_WIDTH = 8,
    parameter Z_WIDTH = 9
    ) (input wire clk_in,
        input wire rst_in,
        input wire [X_WIDTH-1:0] centroid_x,
        input wire [Y_WIDTH-1:0] centroid_y,
        input wire [Z_WIDTH-1:0] centroid_z,
        input wire centroid_ready,
        output logic [X_WIDTH-1:0] point_x,
        output logic [Y_WIDTH-1:0] point_y,
        output logic [Z_WIDTH-1:0] point_z,
        output logic interp_done);

    logic first_prev; 
    logic [X_WIDTH-1:0] prev_x;
    logic [Y_WIDTH-1:0] prev_y;
    logic [Z_WIDTH-1:0] prev_z;
    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            interp_done <= 1;
            point_x <= 0;
            point_y <= 0;
            point_z <= 0;
            first_prev <= 0;
        end
        else if (centroid_ready) begin
            if (~first_prev) begin
                prev_x <= centroid_x;
                prev_y <= centroid_y;
                prev_z <= centroid_z;
                first_prev <= 1;
            end
            else begin
                interp_done <= 0;
                point_x <= prev_x;
                point_y <= prev_y;
                point_z <= prev_z;
            end
        end
        else if (~interp_done) begin
            point_x <= (centroid_x > point_x) ? point_x + 1 :
                        (centroid_x < point_x) ? point_x - 1 : point_x; //go in x direction
            point_y <= (centroid_y > point_y) ? point_y + 1 :
                        (centroid_y < point_y) ? point_y - 1 : point_y; //go in y direction
            point_z <= (centroid_z > point_z) ? point_z + 1 :
                        (centroid_z < point_z) ? point_z - 1 : point_z; //go in z direction

            if ((point_x == centroid_x) && (point_y == centroid_y) && (point_z == centroid_z)) begin
                interp_done <= 1;
                prev_x <= centroid_x;
                prev_y <= centroid_y;
                prev_z <= centroid_z;
            end
        end
    end
        
endmodule
`default_nettype wire
