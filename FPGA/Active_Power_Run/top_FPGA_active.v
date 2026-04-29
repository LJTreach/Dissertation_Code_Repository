module top_fpga #(
    parameter integer W      = 32,
    parameter integer H      = 32,
    parameter integer CLK_HZ = 12000000,
    parameter [7:0]  THRESH  = 8'd120,
    parameter integer POR_MS = 50,
    parameter        ROMFILE = "C:/FPGA/sobel_diss_v2/data/input_32x32.mem"
)(
    input  wire clk,
    output wire uart_rxd_out
);

    localparam integer N          = W * H;
    localparam integer ADDR_W     = (N <= 1) ? 1 : $clog2(N + 1);
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
    // ROM holding the fixed 32x32 input image
    // ------------------------------------------------------------
    (* rom_style = "block", DONT_TOUCH = "true", KEEP = "true" *)
    reg [7:0] rom [0:N-1];

    initial begin
        $readmemh(ROMFILE, rom);
    end

    // ------------------------------------------------------------
    // Feed control
    // ------------------------------------------------------------
    reg [ADDR_W-1:0] addr      = 0;
    reg              in_valid  = 1'b0;
    reg              frame_rst = 1'b0;

    wire [7:0] pixel_in   = rom[addr];
    wire       sobel_rst  = rst | frame_rst;

    // ------------------------------------------------------------
    // Sobel pipeline
    // ------------------------------------------------------------
    wire [7:0] pixel_out;
    wire       out_valid;

    (* DONT_TOUCH = "true", KEEP = "true" *)
    sobel_top #(
        .W(W),
        .H(H)
    ) sob (
        .clk(clk),
        .rst(sobel_rst),
        .pixel_in(pixel_in),
        .in_valid(in_valid),
        .thresh(THRESH),
        .pixel_out(pixel_out),
        .out_valid(out_valid)
    );

    // ------------------------------------------------------------
    // Internal sinks to retain real switching activity
    // ------------------------------------------------------------
    (* DONT_TOUCH = "true", KEEP = "true" *) reg [31:0] frame_count   = 32'd0;
    (* DONT_TOUCH = "true", KEEP = "true" *) reg [15:0] valid_count   = 16'd0;
    (* DONT_TOUCH = "true", KEEP = "true" *) reg [15:0] edge_sum      = 16'd0;
    (* DONT_TOUCH = "true", KEEP = "true" *) reg [7:0]  activity_acc  = 8'd0;

    // ------------------------------------------------------------
    // Autonomous repeated frame processing
    // ------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            addr         <= 0;
            in_valid     <= 1'b0;
            frame_rst    <= 1'b0;
            frame_count  <= 32'd0;
            valid_count  <= 16'd0;
            edge_sum     <= 16'd0;
            activity_acc <= 8'd0;
        end else begin
            // defaults each cycle
            in_valid  <= 1'b0;
            frame_rst <= 1'b0;

            // consume Sobel outputs so logic remains active
            if (out_valid) begin
                valid_count  <= valid_count + 1'b1;
                edge_sum     <= edge_sum + pixel_out;
                activity_acc <= activity_acc ^ pixel_out ^ addr[7:0];
            end

            // feed one pixel every clock cycle
            if (addr < N) begin
                in_valid <= 1'b1;
                addr <= addr + 1'b1;
            end else begin
                // end of frame: reset Sobel/window state and restart
                addr        <= 0;
                frame_rst   <= 1'b1;
                frame_count <= frame_count + 1'b1;

                // keep some frame-level activity
                activity_acc <= activity_acc ^ frame_count[7:0];
            end
        end
    end

endmodule