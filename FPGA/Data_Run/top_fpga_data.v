module top_fpga #(
    parameter integer W             = 32,
    parameter integer H             = 32,
    parameter integer CLK_HZ        = 12000000,
    parameter integer BAUD          = 115200,
    parameter [7:0]  THRESH         = 8'd120,
    parameter integer POR_MS        = 50,
    parameter integer BENCH_SECONDS = 60,
    parameter        ROMFILE        = "C:/FPGA/sobel_diss_v2/data/input_32x32.mem"
)(
    input  wire clk,
    output wire uart_rxd_out
);

    localparam integer N            = W * H;
    localparam integer ADDR_W       = (N <= 1) ? 1 : $clog2(N + 1);
    localparam integer COUNT_W      = (N <= 1) ? 1 : $clog2(N + 1);
    localparam integer POR_CYCLES   = (CLK_HZ / 1000) * POR_MS;
    localparam integer BENCH_CYCLES = CLK_HZ * BENCH_SECONDS;

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
    // Verification frame buffer
    // Captured in output-stream order
    // ------------------------------------------------------------
    (* DONT_TOUCH = "true", KEEP = "true" *)
    reg [7:0] verify_buf [0:N-1];

    reg [COUNT_W-1:0] verify_count = 0;

    // ------------------------------------------------------------
    // Feed control
    // ------------------------------------------------------------
    reg [ADDR_W-1:0] addr      = 0;
    reg              in_valid  = 1'b0;
    reg              frame_rst = 1'b0;

    wire [7:0] pixel_in  = rom[addr];
    wire       sobel_rst = rst | frame_rst;

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
    (* DONT_TOUCH = "true", KEEP = "true" *) reg [31:0] cycle_count   = 32'd0;
    (* DONT_TOUCH = "true", KEEP = "true" *) reg [15:0] valid_count   = 16'd0;
    (* DONT_TOUCH = "true", KEEP = "true" *) reg [15:0] edge_sum      = 16'd0;
    (* DONT_TOUCH = "true", KEEP = "true" *) reg [7:0]  activity_acc  = 8'd0;

    reg benchmark_done = 1'b0;

    // ------------------------------------------------------------
    // UART
    // Verification packet:
    // [0]  A5
    // [1]  5A
    // [2]  F1
    // [3]  W
    // [4]  H
    // [5]  THRESH
    // [6..] W*H image bytes
    //
    // Summary packet:
    // [0]  A5
    // [1]  5A
    // [2]  01
    // [3]  frame_count[7:0]
    // [4]  frame_count[15:8]
    // [5]  frame_count[23:16]
    // [6]  frame_count[31:24]
    // [7]  cycle_count[7:0]
    // [8]  cycle_count[15:8]
    // [9]  cycle_count[23:16]
    // [10] cycle_count[31:24]
    // ------------------------------------------------------------
    reg  [7:0] tx_data = 8'h00;
    reg        send    = 1'b0;
    wire       busy;

    uart_tx #(
        .CLK_HZ(CLK_HZ),
        .BAUD(BAUD)
    ) UTX (
        .clk(clk),
        .rst(rst),
        .data(tx_data),
        .send(send),
        .tx(uart_rxd_out),
        .busy(busy)
    );

    reg [COUNT_W:0] send_idx = 0;

    localparam [1:0]
        TX_LOAD      = 2'd0,
        TX_PULSE     = 2'd1,
        TX_WAIT_BUSY = 2'd2,
        TX_WAIT_DONE = 2'd3;

    reg [1:0] tx_state = TX_LOAD;

    localparam [2:0]
        S_VERIFY_RUN   = 3'd0,
        S_VERIFY_SEND  = 3'd1,
        S_BENCH_RESET  = 3'd2,
        S_BENCH_RUN    = 3'd3,
        S_SUMMARY_SEND = 3'd4,
        S_HALT         = 3'd5;

    reg [2:0] state = S_VERIFY_RUN;

    function [7:0] summary_byte;
        input [3:0] idx;
        begin
            case (idx)
                4'd0:  summary_byte = 8'hA5;
                4'd1:  summary_byte = 8'h5A;
                4'd2:  summary_byte = 8'h01;
                4'd3:  summary_byte = frame_count[7:0];
                4'd4:  summary_byte = frame_count[15:8];
                4'd5:  summary_byte = frame_count[23:16];
                4'd6:  summary_byte = frame_count[31:24];
                4'd7:  summary_byte = cycle_count[7:0];
                4'd8:  summary_byte = cycle_count[15:8];
                4'd9:  summary_byte = cycle_count[23:16];
                4'd10: summary_byte = cycle_count[31:24];
                default: summary_byte = 8'h00;
            endcase
        end
    endfunction

    function [7:0] verify_byte;
        input [COUNT_W:0] idx;
        begin
            if (idx == 0)          verify_byte = 8'hA5;
            else if (idx == 1)     verify_byte = 8'h5A;
            else if (idx == 2)     verify_byte = 8'hF1;
            else if (idx == 3)     verify_byte = W[7:0];
            else if (idx == 4)     verify_byte = H[7:0];
            else if (idx == 5)     verify_byte = THRESH;
            else                   verify_byte = verify_buf[idx - 6];
        end
    endfunction

    // ------------------------------------------------------------
    // Main control
    // ------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            addr           <= 0;
            in_valid       <= 1'b0;
            frame_rst      <= 1'b0;
            verify_count   <= 0;

            frame_count    <= 32'd0;
            cycle_count    <= 32'd0;
            valid_count    <= 16'd0;
            edge_sum       <= 16'd0;
            activity_acc   <= 8'd0;
            benchmark_done <= 1'b0;

            send           <= 1'b0;
            tx_data        <= 8'h00;
            send_idx       <= 0;
            tx_state       <= TX_LOAD;

            state          <= S_VERIFY_RUN;

        end else begin
            // defaults each cycle
            in_valid  <= 1'b0;
            frame_rst <= 1'b0;
            send      <= 1'b0;

            case (state)

                // ------------------------------------------------
                // Run one frame and capture output stream
                // ------------------------------------------------
                S_VERIFY_RUN: begin
                    // Capture output in stream order
                    if (out_valid && (verify_count < N)) begin
                        verify_buf[verify_count] <= pixel_out;
                        verify_count <= verify_count + 1'b1;
                    end

                    // Feed pixels using the original style
                    if (verify_count < N) begin
                        if (addr < N) begin
                            in_valid <= 1'b1;
                            addr <= addr + 1'b1;
                        end else begin
                            addr      <= 0;
                            frame_rst <= 1'b1;
                        end
                    end

                    // Once one full output frame has been captured, stop
                    if (out_valid && (verify_count == N-1)) begin
                        send_idx <= 0;
                        tx_state <= TX_LOAD;
                        state    <= S_VERIFY_SEND;
                    end
                end

                // ------------------------------------------------
                // Send one verification frame
                // ------------------------------------------------
                S_VERIFY_SEND: begin
                    case (tx_state)

                        TX_LOAD: begin
                            if (!busy) begin
                                tx_data <= verify_byte(send_idx);
                                tx_state <= TX_PULSE;
                            end
                        end

                        TX_PULSE: begin
                            send <= 1'b1;
                            tx_state <= TX_WAIT_BUSY;
                        end

                        TX_WAIT_BUSY: begin
                            if (busy)
                                tx_state <= TX_WAIT_DONE;
                        end

                        TX_WAIT_DONE: begin
                            if (!busy) begin
                                if (send_idx == (N + 5)) begin
                                    state <= S_BENCH_RESET;
                                end else begin
                                    send_idx <= send_idx + 1'b1;
                                end
                                tx_state <= TX_LOAD;
                            end
                        end

                        default: begin
                            tx_state <= TX_LOAD;
                        end
                    endcase
                end

                // ------------------------------------------------
                // Reset benchmark state cleanly
                // ------------------------------------------------
                S_BENCH_RESET: begin
                    addr           <= 0;
                    in_valid       <= 1'b0;
                    frame_rst      <= 1'b1;
                    verify_count   <= 0;

                    frame_count    <= 32'd0;
                    cycle_count    <= 32'd0;
                    valid_count    <= 16'd0;
                    edge_sum       <= 16'd0;
                    activity_acc   <= 8'd0;
                    benchmark_done <= 1'b0;

                    send_idx       <= 0;
                    tx_state       <= TX_LOAD;

                    state          <= S_BENCH_RUN;
                end

                // ------------------------------------------------
                // Timed benchmark, same style as before
                // ------------------------------------------------
                S_BENCH_RUN: begin
                    if (!benchmark_done) begin
                        cycle_count <= cycle_count + 1'b1;

                        if (out_valid) begin
                            valid_count  <= valid_count + 1'b1;
                            edge_sum     <= edge_sum + pixel_out;
                            activity_acc <= activity_acc ^ pixel_out ^ addr[7:0];
                        end

                        if (addr < N) begin
                            in_valid <= 1'b1;
                            addr <= addr + 1'b1;
                        end else begin
                            addr        <= 0;
                            frame_rst   <= 1'b1;
                            frame_count <= frame_count + 1'b1;
                            activity_acc <= activity_acc ^ frame_count[7:0];
                        end

                        if (cycle_count >= (BENCH_CYCLES - 1)) begin
                            benchmark_done <= 1'b1;
                            send_idx       <= 0;
                            tx_state       <= TX_LOAD;
                            state          <= S_SUMMARY_SEND;
                        end
                    end
                end

                // ------------------------------------------------
                // Send final summary packet
                // ------------------------------------------------
                S_SUMMARY_SEND: begin
                    case (tx_state)

                        TX_LOAD: begin
                            if (!busy) begin
                                tx_data <= summary_byte(send_idx[3:0]);
                                tx_state <= TX_PULSE;
                            end
                        end

                        TX_PULSE: begin
                            send <= 1'b1;
                            tx_state <= TX_WAIT_BUSY;
                        end

                        TX_WAIT_BUSY: begin
                            if (busy)
                                tx_state <= TX_WAIT_DONE;
                        end

                        TX_WAIT_DONE: begin
                            if (!busy) begin
                                if (send_idx == 10) begin
                                    state <= S_HALT;
                                end else begin
                                    send_idx <= send_idx + 1'b1;
                                end
                                tx_state <= TX_LOAD;
                            end
                        end

                        default: begin
                            tx_state <= TX_LOAD;
                        end
                    endcase
                end

                // ------------------------------------------------
                // Hold final state
                // ------------------------------------------------
                S_HALT: begin
                    // do nothing
                end

                default: begin
                    state <= S_VERIFY_RUN;
                end
            endcase
        end
    end

endmodule