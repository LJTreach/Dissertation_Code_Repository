module window_3x3 #(
    parameter integer W = 32,
    parameter integer H = 32
)(
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] pixel_in,
    input  wire       in_valid,

    output reg  [7:0] p00, p01, p02,
    output reg  [7:0] p10,      p12,
    output reg  [7:0] p20, p21, p22,
    output reg        win_valid
);

    localparam integer XW = (W <= 2) ? 1 : $clog2(W);
    localparam integer YW = (H <= 2) ? 1 : $clog2(H);

    reg [7:0] line1 [0:W-1];
    reg [7:0] line2 [0:W-1];

    reg [XW-1:0] x;
    reg [YW-1:0] y;

    integer i;

    always @(posedge clk) begin
        if (rst) begin
            x <= 0;
            y <= 0;

            p00 <= 8'd0; p01 <= 8'd0; p02 <= 8'd0;
            p10 <= 8'd0;             p12 <= 8'd0;
            p20 <= 8'd0; p21 <= 8'd0; p22 <= 8'd0;

            win_valid <= 1'b0;

            for (i = 0; i < W; i = i + 1) begin
                line1[i] <= 8'd0;
                line2[i] <= 8'd0;
            end
        end else begin
            win_valid <= 1'b0;

            if (in_valid) begin
                // Shift window left
                p00 <= p01;
                p01 <= p02;

                p10 <= p12;

                p20 <= p21;
                p21 <= p22;

                // New right-hand column
                p02 <= line2[x];
                p12 <= line1[x];
                p22 <= pixel_in;

                // Update line buffers
                line2[x] <= line1[x];
                line1[x] <= pixel_in;

                if ((x >= 2) && (y >= 2))
                    win_valid <= 1'b1;

                if (x == W-1) begin
                    x <= 0;
                    if (y == H-1)
                        y <= 0;
                    else
                        y <= y + 1'b1;
                end else begin
                    x <= x + 1'b1;
                end
            end
        end
    end

endmodule