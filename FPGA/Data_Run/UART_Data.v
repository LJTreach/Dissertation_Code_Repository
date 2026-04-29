module uart_tx #(
    parameter integer CLK_HZ = 12000000,
    parameter integer BAUD   = 115200
)(
    input  wire clk,
    input  wire rst,
    input  wire [7:0] data,
    input  wire send,
    output reg  tx,
    output reg  busy
);
    localparam integer CLKS_PER_BIT = CLK_HZ / BAUD;
    localparam integer CNT_W = $clog2(CLKS_PER_BIT);

    reg [CNT_W-1:0] clk_cnt;
    reg [3:0] bit_idx;
    reg [9:0] shifter;

    always @(posedge clk) begin
        if (rst) begin
            tx <= 1'b1;
            busy <= 1'b0;
            clk_cnt <= 0;
            bit_idx <= 0;
            shifter <= 10'h3FF;
        end else begin
            if (!busy) begin
                tx <= 1'b1;
                if (send) begin
                    shifter <= {1'b1, data, 1'b0}; // stop, data, start
                    busy <= 1'b1;
                    clk_cnt <= 0;
                    bit_idx <= 0;
                end
            end else begin
                if (clk_cnt == CLKS_PER_BIT-1) begin
                    clk_cnt <= 0;
                    tx <= shifter[0];
                    shifter <= {1'b1, shifter[9:1]};
                    bit_idx <= bit_idx + 1;
                    if (bit_idx == 9) begin
                        busy <= 1'b0;
                        tx <= 1'b1;
                    end
                end else begin
                    clk_cnt <= clk_cnt + 1;
                end
            end
        end
    end
endmodule