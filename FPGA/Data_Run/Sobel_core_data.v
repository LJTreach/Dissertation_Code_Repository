module sobel_core (
    input  wire [7:0] p00, p01, p02,
    input  wire [7:0] p10,      p12,
    input  wire [7:0] p20, p21, p22,
    input  wire [7:0] thresh,
    output wire [7:0] edge_out
);

    wire signed [10:0] gx =
        ($signed({1'b0, p02}) + ($signed({1'b0, p12}) <<< 1) + $signed({1'b0, p22}))
      - ($signed({1'b0, p00}) + ($signed({1'b0, p10}) <<< 1) + $signed({1'b0, p20}));

    wire signed [10:0] gy =
        ($signed({1'b0, p20}) + ($signed({1'b0, p21}) <<< 1) + $signed({1'b0, p22}))
      - ($signed({1'b0, p00}) + ($signed({1'b0, p01}) <<< 1) + $signed({1'b0, p02}));

    wire [10:0] ax = gx[10] ? (~gx + 11'd1) : gx;
    wire [10:0] ay = gy[10] ? (~gy + 11'd1) : gy;

    wire [11:0] mag = ax + ay;

    assign edge_out = (mag > {4'b0, thresh}) ? 8'hFF : 8'h00;

endmodule