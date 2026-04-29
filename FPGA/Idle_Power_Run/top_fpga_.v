module top_fpga #(
    parameter integer CLK_HZ = 12000000,
    parameter integer POR_MS = 50
)(
    input  wire clk,
    output wire uart_rxd_out
);

    localparam integer POR_CYCLES = (CLK_HZ / 1000) * POR_MS;

    // Keep UART pin idle-high so the same XDC can remain unchanged
    assign uart_rxd_out = 1'b1;

    // ------------------------------------------------------------
    // Power-on reset
    // ------------------------------------------------------------
    reg [31:0] por_cnt = 0;
    wire rst = (por_cnt < POR_CYCLES);

    always @(posedge clk) begin
        if (por_cnt < POR_CYCLES)
            por_cnt <= por_cnt + 1'b1;
    end

    // ------------------------------------------------------------
    // Free-running internal logic so the FPGA is configured and active,
    // but not performing image processing
    // ------------------------------------------------------------
    (* DONT_TOUCH = "true", KEEP = "true" *) reg [31:0] idle_counter = 32'd0;
    (* DONT_TOUCH = "true", KEEP = "true" *) reg [15:0] idle_mix     = 16'd0;
    (* DONT_TOUCH = "true", KEEP = "true" *) reg [7:0]  idle_acc     = 8'd0;

    always @(posedge clk) begin
        if (rst) begin
            idle_counter <= 32'd0;
            idle_mix     <= 16'd0;
            idle_acc     <= 8'd0;
        end else begin
            idle_counter <= idle_counter + 1'b1;
            idle_mix     <= idle_mix + idle_counter[15:0];
            idle_acc     <= idle_acc ^ idle_counter[23:16] ^ idle_mix[7:0];
        end
    end

endmodule