module keyboard (
	input clk,
	output reg [3:0] row = 0,
	input [2:0] col, // Pull-down resistors

	output reg [3:0] out, // 4-bit output for the key pressed, 10 = *, 11 = #, 15 = no key pressed

	// Debug
	output wire [3:0] leds

	);
	
	assign leds = ~{pressed_row, pressed_col}; 

	// REFRESH RATE (important because of capacitances)
	localparam REFRESH_RATE = 50_000; // 1 ms at 50 MHz
	reg [15:0] counter = 0;
	
	
	// Registers
	reg [2:0] detected_col = 0;
	reg [1:0] current_row = 0;
	reg [1:0] pressed_row = 0;
	reg [1:0] pressed_col = 0;
	reg pressed = 0; // Flag to indicate if a key is pressed
	reg [3:0] preout = 0; // out before debouncing

	

	// STATES
	localparam READ = 2'd0;
	localparam SET_ROW = 2'd1;
	localparam VERIFY_PRESS = 2'd2;

	reg [1:0] state = READ;


	always @(posedge clk) begin
		if (counter == REFRESH_RATE) begin
			counter <= 0;
		
			case (state)

				READ: begin
					if (col != 3'b000) begin
						pressed_row <= current_row;
						detected_col <= col;
						pressed <= 1'b1;
					end

					if (current_row == 2'b11) begin // After scanning all rows
						state <= VERIFY_PRESS;
					end else begin
						state <= SET_ROW;
					end
				end

				SET_ROW: begin
					current_row <= current_row + 2'b1;
					state <= READ;
				end

				VERIFY_PRESS: begin
					if (pressed) begin
						pressed <= 1'b0; // Reset the pressed flag
					end else begin
						detected_col <= 3'b000;
					end
					current_row <= current_row + 2'b1;
					state <= READ; // Go back to scanning rows
				end

			endcase
		end else begin
			counter <= counter + 1'b1;
		end
	end
	





	// Decoders
	always @(*) begin
		case (current_row)
			2'b00: row = 4'b0001;
			2'b01: row = 4'b0010;
			2'b10: row = 4'b0100;
			2'b11: row = 4'b1000;
			default: row = 4'b0000; 
		endcase

		case (detected_col)
			3'b001: pressed_col = 2'b00; // Column 0
			3'b010: pressed_col = 2'b01; // Column 1
			3'b100: pressed_col = 2'b10; // Column 2
			default: pressed_col = 2'b11; // No column detected
		endcase


		case ({pressed_row, pressed_col})
			4'b0000: preout = 4'd1;
			4'b0001: preout = 4'd2;
			4'b0010: preout = 4'd3;

			4'b0100: preout = 4'd4;
			4'b0101: preout = 4'd5;
			4'b0110: preout = 4'd6;

			4'b1000: preout = 4'd7;
			4'b1001: preout = 4'd8;
			4'b1010: preout = 4'd9;

			4'b1100: preout = 4'd10; // *
			4'b1101: preout = 4'd0;
			4'b1110: preout = 4'd11; // #

			default: preout = 4'd15; // No key pressed
		endcase
	end


// DEBOUNCE
reg [21:0] db_cnt = 0;
localparam DB_CNT_MAX = 2_500_000; // 50 ms

reg [3:0] prev_preout = 0;

always @(posedge clk) begin
	prev_preout <= preout;
	if (preout == prev_preout) begin
		if (db_cnt > DB_CNT_MAX) begin // 50 ms
			out <= preout;
			db_cnt <= 0;
		end
		else begin
			db_cnt <= db_cnt + 1'b1;
		end
	end
	else begin
		db_cnt <= 0;
	end
end

	
endmodule