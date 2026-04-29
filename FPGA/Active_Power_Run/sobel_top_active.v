module sobel_top #(
    parameter integer W = 32,
    parameter integer H = 32
)(
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] pixel_in,
    input  wire       in_valid,
    input  wire [7:0] thresh,
    output wire [7:0] pixel_out,
    output reg        out_valid
);

    wire [7:0] p00, p01, p02;
    wire [7:0] p10,      p12;
    wire [7:0] p20, p21, p22;
    wire       win_valid;
    wire [7:0] edge_out;

    window_3x3 #(
        .W(W),
        .H(H)
    ) win (
        .clk(clk),
        .rst(rst),
        .pixel_in(pixel_in),
        .in_valid(in_valid),
        .p00(p00), .p01(p01), .p02(p02),
        .p10(p10),           .p12(p12),
        .p20(p20), .p21(p21), .p22(p22),
        .win_valid(win_valid)
    );

    sobel_core core (
        .p00(p00), .p01(p01), .p02(p02),
        .p10(p10),           .p12(p12),
        .p20(p20), .p21(p21), .p22(p22),
        .thresh(thresh),
        .edge_out(edge_out)
    );

    assign pixel_out = win_valid ? edge_out : 8'h00;

    always @(posedge clk) begin
        if (rst)
            out_valid <= 1'b0;
        else
            out_valid <= in_valid;
    end

endmodule