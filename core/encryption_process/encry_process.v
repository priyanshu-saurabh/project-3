
// Receiving data from PC through UART
module uart_receiver (
    input wire clk,
    input wire rst,
    input wire rx,
    output reg [7:0] data_out,
    output reg data_valid
);
    parameter BAUD_RATE = 115200;
    parameter CLK_FREQ = 50000000;
    parameter SAMPLES_PER_BIT = CLK_FREQ / BAUD_RATE;

    reg [3:0] bit_index = 0;
    reg [15:0] sample_counter = 0;
    reg [7:0] rx_shift_reg = 0;
    reg [1:0] state = 0;  // 0: IDLE, 1: START, 2: DATA, 3: STOP

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            data_out <= 0;
            data_valid <= 0;
            bit_index <= 0;
            sample_counter <= 0;
            rx_shift_reg <= 0;
            state <= 0;
        end else begin
            data_valid <= 0;

            case (state)
                0: begin  // IDLE
                    if (!rx) begin  // Start bit detected
                        state <= 1;          //Seq cir, NON Blocking state <= 1
                        sample_counter <= SAMPLES_PER_BIT / 2;
                    end
                end

                1: begin  // START bit
                    if (sample_counter == 0) begin
                        if (!rx) begin  // Confirm still low
                            state <= 2;
                            bit_index <= 0;
                            sample_counter <= SAMPLES_PER_BIT - 1;
                        end else begin
                            state <= 0;  // False start
                        end
                    end else begin
                        sample_counter <= sample_counter - 1;
                    end
                end

                2: begin  // DATA bits
                    if (sample_counter == 0) begin
                        rx_shift_reg[bit_index] <= rx;
                        bit_index <= bit_index + 1;
                        sample_counter <= SAMPLES_PER_BIT - 1;

                        if (bit_index == 7) begin
                            state <= 3;
                        end
                    end else begin
                        sample_counter <= sample_counter - 1;
                    end
                end

                3: begin  // STOP bit
                    if (sample_counter == 0) begin
                        if (rx) begin  // Stop bit must be high
                            data_out <= rx_shift_reg;
                            data_valid <= 1;
                        end
                        state <= 0;  // Return to IDLE
                    end else begin
                        sample_counter <= sample_counter - 1;
                    end
                end
            endcase
        end
    end
endmodule

// BRAM Controller Module with XOR Encryption, KEY is 8 - bit hex 'AA'
module bram_controller (
    input wire clk,
    input wire rst,
    input wire [7:0] data_in,
    input wire data_valid,
    
    output reg done
);
    reg [7:0] bram [0:16383]; 
    reg [13:0] addr;
    parameter [7:0] XOR_KEY = 8'hAA; // Example encryption key

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            addr <= 0;
            done <= 0;
        end else if (data_valid) begin
            bram[addr] <= data_in ^ XOR_KEY; // XOR encryption
            addr <= addr + 1;
            if (addr == 16383) begin
                done <= 1; // Memory full
            end
        end
    end
endmodule

// Top Module
module uart_bram_top (
    input wire clk,
    input wire rst,
    input wire rx,
  //  output wire [7:0] debug_data,
    output wire led0_r,
output wire led0_g,
output wire led1_r,
output wire led1_g,
output wire led1_b
);
    wire [7:0] data_out;
    wire data_valid;
    wire done;

assign led0_g = ~done;
assign led1_r = ~data_out[7];
assign led1_g = ~data_out[0];
assign led1_b = ~rx;


        // RX line for monitoring


//    assign led0_r = data_valid;
//    assign led0_g = done;
//    assign led1_r = led_reg[7]; // MSB of encrypted byte
//    assign led1_g = led_reg[0]; // LSB of encrypted byte
//    assign led1_b = rx;         // Monitor UART RX line
    
    
//    assign led0_r = data_valid;       // Red LED blinks when a byte is received
//assign led0_g = 1'b0;
//assign led1_r = 1'b0;
//assign led1_g = 1'b0;
//assign led1_b = rx;               // Keep RX monitoring
//-----------------------------------------------------

    // Delay logic to slow down LED update

//-------------------------------------------------------
reg [3:0] valid_cnt = 0;
always @(posedge clk) begin
    if (data_valid)
        valid_cnt <= 4'd15;
    else if (valid_cnt != 0)
        valid_cnt <= valid_cnt - 1;
end

assign led0_r = ~(valid_cnt != 0);


// assign debug_data = data_out ^ 8'hAA; // Shows encrypted byte (XOR key is 0xAA)

    uart_receiver uart_inst (
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .data_out(data_out),
        .data_valid(data_valid)
    );

    bram_controller bram_inst (
        .clk(clk),
        .rst(rst),
        .data_in(data_out),
        .data_valid(data_valid),
        .done(done)
    );

endmodule
