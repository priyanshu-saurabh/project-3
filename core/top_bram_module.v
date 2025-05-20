module uart_bram_top(
    input wire clk,              // 100 MHz clock
    input wire rst,              // Active high reset
    input wire uart_rx_in,       // UART RX from PC
    output wire uart_tx_out,     // UART TX to PC
    input wire sw0,              // Mode switch: 0 = Encrypt, 1 = Transmit
    output reg green_led,        // Indicates encryption mode
    output reg red_led           // Indicates transmit mode
);

// Parameters
parameter CLK_FREQ = 100_000_000;
parameter BAUD_RATE = 9600;

// === UART Signals ===
wire [7:0] rx_data;
wire rx_done;
reg [7:0] tx_data;
reg tx_start = 0;
wire tx_busy;

// === BRAM ===
reg [7:0] bram [0:4095];
reg [15:0] write_addr = 0;
reg [15:0] read_addr = 0;
reg [15:0] data_count = 0;

// === LFSR PRNG ===
reg [7:0] lfsr = 8'h1;
wire lfsr_feedback = lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3];

// === RX State ===
reg rx_done_d;

// === LED & Mode Logic ===
always @(posedge clk or posedge rst) begin
    if (rst) begin
        green_led <= 0;
        red_led <= 0;
    end else begin
        green_led <= ~sw0;  // Encrypt mode
        red_led <= sw0;     // Transmit mode
    end
end

// === LFSR Update ===
always @(posedge clk or posedge rst) begin
    if (rst) begin
        lfsr <= 8'h1;  // Reset seed
    end else if (~sw0 && (rx_done && ~rx_done_d)) begin
        lfsr <= {lfsr[6:0], lfsr_feedback};  // Advance key
    end
end

// === Encrypt and Store ===
always @(posedge clk or posedge rst) begin
    if (rst) begin
        write_addr <= 0;
        data_count <= 0;
        rx_done_d <= 0;
    end else begin
        rx_done_d <= rx_done;

        if (~sw0 && rx_done && ~rx_done_d) begin
            bram[write_addr] <= rx_data ^ lfsr;
            write_addr <= write_addr + 1;
            data_count <= data_count + 1;
        end
    end
end

// === Transmit Logic ===
always @(posedge clk or posedge rst) begin
    if (rst) begin
        read_addr <= 0;
        tx_start <= 0;
    end else if (sw0) begin
        if (~tx_busy && read_addr < data_count) begin
            tx_data <= bram[read_addr];
            tx_start <= 1;
            read_addr <= read_addr + 1;
        end else begin
            tx_start <= 0;
        end
    end else begin
        read_addr <= 0;
        tx_start <= 0;
    end
end

// === UART RX ===
uart_rx #(
    .CLK_FREQ(CLK_FREQ),
    .BAUD_RATE(BAUD_RATE)
) uart_rx_inst (
    .clk(clk),
    .rst(rst),
    .rx(uart_rx_in),
    .data_out(rx_data),
    .rx_done(rx_done)
);

// === UART TX ===
uart_tx #(
    .CLK_FREQ(CLK_FREQ),
    .BAUD_RATE(BAUD_RATE)
) uart_tx_inst (
    .clk(clk),
    .rst(rst),
    .start(tx_start),
    .data_in(tx_data),
    .tx(uart_tx_out),
    .busy(tx_busy)
);

endmodule


// =======================
// UART Receiver Module
// =======================
module uart_rx #(
    parameter CLK_FREQ = 100_000_000,
    parameter BAUD_RATE = 9600
)(
    input wire clk,
    input wire rst,
    input wire rx,
    output reg [7:0] data_out,
    output reg rx_done
);

localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
localparam HALF_CLKS = CLKS_PER_BIT / 2;

reg [3:0] state = 0;
reg [15:0] clk_cnt = 0;
reg [2:0] bit_idx = 0;
reg [7:0] rx_shift = 0;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= 0;
        clk_cnt <= 0;
        bit_idx <= 0;
        rx_done <= 0;
    end else begin
        case (state)
            0: begin // IDLE
                rx_done <= 0;
                if (~rx) state <= 1; // start bit
            end
            1: begin // START
                if (clk_cnt == HALF_CLKS) begin
                    clk_cnt <= 0;
                    state <= 2;
                end else clk_cnt <= clk_cnt + 1;
            end
            2: begin // DATA BITS
                if (clk_cnt == CLKS_PER_BIT) begin
                    clk_cnt <= 0;
                    rx_shift[bit_idx] <= rx;
                    if (bit_idx == 7) state <= 3;
                    else bit_idx <= bit_idx + 1;
                end else clk_cnt <= clk_cnt + 1;
            end
            3: begin // STOP BIT
                if (clk_cnt == CLKS_PER_BIT) begin
                    data_out <= rx_shift;
                    rx_done <= 1;
                    clk_cnt <= 0;
                    bit_idx <= 0;
                    state <= 0;
                end else clk_cnt <= clk_cnt + 1;
            end
        endcase
    end
end

endmodule

// =======================
// UART Transmitter Module
// =======================
module uart_tx #(
    parameter CLK_FREQ = 100_000_000,
    parameter BAUD_RATE = 9600
)(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [7:0] data_in,
    output reg tx,
    output reg busy
);

localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

reg [3:0] state = 0;
reg [15:0] clk_cnt = 0;
reg [2:0] bit_idx = 0;
reg [7:0] data_buf = 0;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= 0;
        tx <= 1;
        busy <= 0;
        clk_cnt <= 0;
        bit_idx <= 0;
    end else begin
        case (state)
            0: begin // IDLE
                tx <= 1;
                busy <= 0;
                if (start) begin
                    data_buf <= data_in;
                    busy <= 1;
                    state <= 1;
                end
            end
            1: begin // START
                tx <= 0;
                if (clk_cnt == CLKS_PER_BIT-1) begin
                    clk_cnt <= 0;
                    state <= 2;
                end else clk_cnt <= clk_cnt + 1;
            end
            2: begin // DATA
                tx <= data_buf[bit_idx];
                if (clk_cnt == CLKS_PER_BIT-1) begin
                    clk_cnt <= 0;
                    if (bit_idx == 7) state <= 3;
                    else bit_idx <= bit_idx + 1;
                end else clk_cnt <= clk_cnt + 1;
            end
            3: begin // STOP
                tx <= 1;
                if (clk_cnt == CLKS_PER_BIT-1) begin
                    clk_cnt <= 0;
                    bit_idx <= 0;
                    state <= 0;
                end else clk_cnt <= clk_cnt + 1;
            end
        endcase
    end
end

endmodule

