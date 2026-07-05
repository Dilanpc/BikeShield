module system (
	input clk,
	input rst_in,

	// I2C
	output scl,
	inout sda,

	// LCD
	output lcd_rs,
	output lcd_e,
	output [3:0] lcd_d,
	output lcd_awake,

	// Keyboard
	output [3:0] row,
	input [2:0] col,

	input wire closed, // If the continuity circuit is closed, the system is locked
	output reg alarm, // To activate the buzzer when the system is manipulated

	output wire error,

	output wire [6:0] segmentos,
	output wire [3:0] power,

	output [3:0] leds
	);

	assign leds = ~{error, manipulation, alarm, closed};

	wire rst = ~rst_in;

	// I2C /////////////////////////////////////////////////////////////////////////////////////////////////
	reg [2:0] i2c_command = 0; // 1: INIT, 2: LOAD PASSWORD, 3: CHANGE PASSWORD, 4: SLEEP, 5: WAKEUP
	reg i2c_enable = 0; // To confirm command
	wire i2c_busy; // To indicate that the driver is busy
	wire manipulation; // Alert from mpu
	reg [2:0] sensitivity = 3'd3; // Sensitivity for manipulation detection.
	reg [15:0] password_in = 16'hFFFF;
	wire [15:0] password;

	localparam I2C_INIT = 3'd1;
	localparam I2C_LOAD_PASSWORD = 3'd2;
	localparam I2C_CHANGE_PASSWORD = 3'd3;
	localparam I2C_SLEEP = 3'd4;
	localparam I2C_WAKEUP = 3'd5;



	// LCD /////////////////////////////////////////////////////////////////////////////////////////////////
	reg [3:0] lcd_instruction = 0;
		// 0:TURN OFF
		// 1: AUTHENTICATION + 4 characters to show
		// 2: UNLOCKED
		// 3: INCORRECT
		// 4: SET SENSITIVITY + value to set the bar 0 - 15
		// 5: SELECT SENSITIVITY
		// 6: SET PASSWORD + 4 characters to show
		// 7: CONFIRM PASSWORD + 4 characters to show
		// 8: SELECT SET PASSWORD

	reg [31:0] lcd_data = 0; // Additional data for instructions that require it. Keep until done
	reg lcd_enable = 0;
	wire lcd_done;

	localparam LCD_TURN_OFF = 4'd0;
	localparam LCD_AUTHENTICATE = 4'd1;
	localparam LCD_UNLOCKED = 4'd2;
	localparam LCD_INCORRECT = 4'd3;
	localparam LCD_SENSITIVITY = 4'd4;
	localparam LCD_SELECT_SENSITIVITY = 4'd5;
	localparam LCD_SET_PASSWORD = 4'd6;
	localparam LCD_CONFIRM_PASSWORD = 4'd7;
	localparam LCD_SELECT_SET_PASSWORD = 4'd8;


	// Keyboard ///////////////////////////////////////////////////////////////////////////////////////////////
	
	wire [3:0] key;
	wire key_pressed = (key != 4'd15); // 15 means no key pressed
	reg prev_key_pressed = 0;


	// Other registers
	localparam INITIAL_WAIT = 50_000_000;
	localparam INCORRECT_WAIT = 50_000_000; // 1 second
	localparam CORRECT_WAIT = 50_000_000; // 1 second
	localparam INCORRECT_WAIT_NO_TRIES = 500_000_000; // 10 second


	reg [28:0] counter = 0;

	reg [1:0] current_digit = 0; // Password digit being entered
	reg [1:0] tries = 2'd3; // Number of tries to enter the password


	

	// STATE
	localparam INIT0 = 4'd0;
	localparam INIT1 = 4'd1;
	localparam INIT2 = 4'd2;
	localparam WAIT  = 4'd3;
	localparam LOCKED_IDLE = 4'd4;
	localparam UNLOCKED_IDLE_SELECTION   = 4'd5;
	localparam UNLOCKED_IDLE_SENSITIVITY = 4'd6;
	localparam LOAD_NEW_SENSITIVITY = 4'd7;
	localparam UNLOCKED_IDLE_SET_PASSWORD    = 4'd8;
	localparam CONFIRM_PASSWORD = 4'd9;
	localparam LOAD_NEW_PASSWORD = 4'd10;
	localparam CHECK_PASSWORD = 4'd11;
	localparam CORRECT   = 4'd12;
	localparam INCORRECT = 4'd13;


	reg [3:0] state = INIT0;
	reg [3:0] next_state = INIT0;


	// DEBUG CLK
	reg clk_debug = 0;
	localparam CLK_DEBUG_DIV = 25_000_000; // 1 second
	reg [24:0] clk_debug_counter = 0;
	always @(posedge clk) begin
		if (clk_debug_counter >= CLK_DEBUG_DIV) begin
			clk_debug <= ~clk_debug;
			clk_debug_counter <= 0;
		end else begin
			clk_debug_counter <= clk_debug_counter + 1'b1;
		end
	end

	


	always @(posedge clk or posedge rst) begin
		if (rst) begin
			state <= INIT0;
			counter <= 0;
			current_digit <= 0;
			tries <= 2'd3;
			alarm <= 1'b0;
			i2c_enable <= 1'b0;
			lcd_instruction <= LCD_TURN_OFF;
			lcd_enable <= 1'b1;


		end
		else begin
			prev_key_pressed <= key_pressed;

			case(state)
				INIT0: begin
					i2c_enable <= 1'b0;
					lcd_enable <= 1'b0;

					if (counter > INITIAL_WAIT) begin
						state <= INIT1;
						counter <= 0;
					end else begin
						counter <= counter + 1'b1;
					end
				end

				INIT1: begin // Initialize eeprom, load password
					if (~i2c_busy && lcd_done) begin
						i2c_command <= I2C_INIT;
						i2c_enable <= 1'b1;
						state <= WAIT;
						next_state <= INIT2;
					end
				end

				INIT2: begin
					state <= WAIT;
					current_digit <= 0;
					lcd_enable <= 1'b1;
					lcd_data <= "____";
					if (closed == 0) begin // Change password or set sensitivity
						lcd_instruction <= LCD_SELECT_SET_PASSWORD;
						next_state <= UNLOCKED_IDLE_SELECTION;
					end else begin // Locked
						lcd_instruction <= LCD_AUTHENTICATE;
						next_state <= LOCKED_IDLE;
					end
				end
				
				WAIT: begin
					i2c_enable <= 1'b0;
					lcd_enable <= 1'b0;
					if (~i2c_busy && lcd_done) begin
						state <= next_state;
					end
				end


				LOCKED_IDLE: begin
					if (key_pressed && ~prev_key_pressed) begin // A key has just been pressed
						
						if (key == 4'd11) begin // '#' key to delete 
							lcd_instruction <= LCD_AUTHENTICATE;
							lcd_enable <= 1'b1;
							state <= WAIT;
							next_state <= LOCKED_IDLE;
							case (current_digit)
								2'd0: lcd_data <= "____";
								2'd1:  begin 
									lcd_data <= "____";
									current_digit <= 2'd0;
								end
								2'd2: begin 
									lcd_data <= "#___";
									current_digit <= 2'd1;
								end
								2'd3: begin 
									lcd_data <= "##__";
									current_digit <= 2'd2;
								end
							endcase

						end else if (key == 4'd10) begin // '*' Delete all
							lcd_instruction <= LCD_AUTHENTICATE;
							lcd_enable <= 1'b1;
							state <= WAIT;
							next_state <= LOCKED_IDLE;
							lcd_data <= "____";
							current_digit <= 0;
						end else begin
							lcd_instruction <= LCD_AUTHENTICATE;
							lcd_enable <= 1'b1;
							state <= WAIT;
							next_state <= LOCKED_IDLE;
							case (current_digit)
								2'd0: begin
									password_in[15:12] <= key;
									lcd_data <= "#___";
									current_digit <= 2'd1;
								end
								2'd1: begin
									password_in[11:8] <= key;
									lcd_data <= "##__";
									current_digit <= 2'd2;
								end
								2'd2: begin
									password_in[7:4] <= key;
									lcd_data <= "###_";
									current_digit <= 2'd3;
								end
								2'd3: begin
									password_in[3:0] <= key;
									lcd_enable <= 1'b0;
									state <= CHECK_PASSWORD;
								end
							endcase
						end
					end
				end


				UNLOCKED_IDLE_SELECTION: begin // Selection between set sensitivity or set password
					alarm <= 1'b0; // Reset alarm
					tries <= 2'd3; // Reset tries
					if (key_pressed && ~prev_key_pressed) begin // A key has just been pressed
						if (key == 4'd10 || key == 4'd11) begin // '*' or '#' Switch password/sensitivity
							lcd_enable <= 1'b1;
							state <= WAIT;
							next_state <= UNLOCKED_IDLE_SELECTION;
							if (lcd_instruction == LCD_SELECT_SET_PASSWORD) begin // Switch to select set sensitivity
								lcd_instruction <= LCD_SELECT_SENSITIVITY;
							end else begin // Switch to select set password
								lcd_instruction <= LCD_SELECT_SET_PASSWORD;
							end
						end
						else if (key == 4'd0) begin // '0' Select option
							lcd_enable <= 1'b1;
							state <= WAIT;
							if (lcd_instruction == LCD_SELECT_SET_PASSWORD) begin // Switch to set password
								current_digit <= 0;
								lcd_instruction <= LCD_SET_PASSWORD;
								lcd_data <= "____";
								next_state <= UNLOCKED_IDLE_SET_PASSWORD;
							end else begin // Switch to set sensitivity
								lcd_instruction <= LCD_SENSITIVITY;
								lcd_data <= sensitivity;
								next_state <= UNLOCKED_IDLE_SENSITIVITY;
							end
						end
					end
				end


				UNLOCKED_IDLE_SENSITIVITY: begin // Set sensitivity
					alarm <= 1'b0; // Reset alarm
					tries <= 2'd3; // Reset tries
					if (key_pressed && ~prev_key_pressed) begin // A key has just been pressed
						if (key == 4'd10 || key == 4'd11) begin // '*' or '#' Return to selection
							lcd_instruction <= LCD_SELECT_SENSITIVITY;
							lcd_enable <= 1'b1;
							state <= WAIT;
							next_state <= UNLOCKED_IDLE_SELECTION;
						end
						else if (key <= 3'd1 || key == 4'd4 || key == 3'd7) begin // Decrease sensitivity
							if (sensitivity > 3'd0) begin
								sensitivity <= sensitivity - 1'b1;
								state <= LOAD_NEW_SENSITIVITY;
							end
						end
						else if (key == 3'd3 || key == 4'd6 || key == 4'd9) begin // Increase sensitivity
							if (sensitivity < 3'd7) begin
								sensitivity <= sensitivity + 1'b1;
								state <= LOAD_NEW_SENSITIVITY;
							end
						end
					end
				end

				LOAD_NEW_SENSITIVITY: begin // Load new sensitivity
					lcd_instruction <= LCD_SENSITIVITY;
					lcd_data <= sensitivity;
					lcd_enable <= 1'b1;
					state <= WAIT;
					next_state <= UNLOCKED_IDLE_SENSITIVITY;
				end


				UNLOCKED_IDLE_SET_PASSWORD: begin // Change password
					alarm <= 1'b0; // Reset alarm
					tries <= 2'd3; // Reset tries
					if (key_pressed && ~prev_key_pressed) begin // A key has just been pressed
						if (key == 4'd11) begin // '#' key to delete
							lcd_instruction <= LCD_SET_PASSWORD;
							lcd_enable <= 1'b1;
							state <= WAIT;
							next_state <= UNLOCKED_IDLE_SET_PASSWORD;
							case (current_digit)
								2'd0: lcd_data <= "____";
								2'd1:  begin 
									lcd_data <= "____";
									current_digit <= 2'd0;
								end
								2'd2: begin 
									lcd_data <= "#___";
									current_digit <= 2'd3;
								end
								2'd3: begin 
									lcd_data <= "##__";
									current_digit <= 2'd2;
								end
							endcase

						end else if (key == 4'd10) begin // '*' key to cancel and return to selection
							lcd_instruction <= LCD_SELECT_SET_PASSWORD;
							lcd_enable <= 1'b1;
							state <= WAIT;
							next_state <= UNLOCKED_IDLE_SELECTION;
							current_digit <= 0;
						end else begin
							lcd_instruction <= LCD_SET_PASSWORD;
							lcd_enable <= 1'b1;
							state <= WAIT;
							next_state <= UNLOCKED_IDLE_SET_PASSWORD;
							case (current_digit)
								2'd0: begin
									password_in[15:12] <= key;
									lcd_data <= "#___";
									current_digit <= 2'd1;
								end
								2'd1: begin
									password_in[11:8] <= key;
									lcd_data <= "##__";
									current_digit <= 2'd2;
								end
								2'd2: begin
									password_in[7:4] <= key;
									lcd_data <= "###_";
									current_digit <= 2'd3;
								end
								2'd3: begin
									password_in[3:0] <= key;
									lcd_instruction <= LCD_CONFIRM_PASSWORD;
									lcd_data <= "____";
									next_state <= CONFIRM_PASSWORD;
									current_digit <= 0;
								end
							endcase
						end
					end
				end

				CONFIRM_PASSWORD: begin // Confirm new password
					
				end

				LOAD_NEW_PASSWORD: begin
					
				end

				CHECK_PASSWORD: begin
					lcd_enable <= 1'b1;
					counter <= 0;
					if (password_in == password) begin
						lcd_instruction <= LCD_UNLOCKED;
						state <= WAIT;
						next_state <= CORRECT;
					end else begin
						lcd_instruction <= LCD_INCORRECT;
						if (tries != 0) begin
							tries <= tries - 1'b1;
						end
						state <= WAIT;
						next_state <= INCORRECT;
					end
				end


				CORRECT: begin // SHOW CORRECT MESSAGE FOR A SECONDS
					if (counter > CORRECT_WAIT) begin
						lcd_instruction <= LCD_SELECT_SENSITIVITY;
						lcd_enable <= 1'b1;
						current_digit <= 0;
						state <= WAIT;
						next_state <= UNLOCKED_IDLE_SELECTION;
						counter <= 0;
					end else begin
						counter <= counter + 1'b1;
					end
				end


				INCORRECT: begin // SHOW INCORRECT MESSAGE FOR A SECONDS
					if (tries == 0) begin
						alarm <= 1'b1;
						if (counter > INCORRECT_WAIT_NO_TRIES) begin
							lcd_instruction <= LCD_AUTHENTICATE;
							lcd_data <= "____";
							lcd_enable <= 1'b1;
							current_digit <= 0;
							state <= WAIT;
							next_state <= LOCKED_IDLE;
							counter <= 0;
						end else begin
							counter <= counter + 1'b1;
						end
					
					end else if (counter > INCORRECT_WAIT) begin
						lcd_instruction <= LCD_AUTHENTICATE;
						lcd_data <= "____";
						lcd_enable <= 1'b1;
						current_digit <= 0;
						state <= WAIT;
						next_state <= LOCKED_IDLE;
						counter <= 0;
					end else begin
						counter <= counter + 1'b1;
					end
				end

			endcase

		end
		
		
	end


	i2c_driver i2c_driver_inst (
		.clk(clk),
		.rst(rst),
		
		.sda(sda),
		.scl(scl),

		.command(i2c_command), // 0: IDLE, 1: INIT, 2: GET_ACCEL, 3: CHANGE PASSWORD, 4: SLEEP, 5: WAKEUP
		.enable(i2c_enable), // To confirm command
		.busy(i2c_busy), // To indicate that the driver is busy

		.manipulation(manipulation), // Alert from mpu
		.sensitivity(sensitivity), // Sensitivity for manipulation detection.

		.password_in(password_in),
		.password_out(password),

		.error(error),
		.ackled() // Not required
	);

	lcd_driver lcd_driver_inst (
		.clk(clk),
		.rst(rst),

		.instruction(lcd_instruction),
		.data(lcd_data),
		.enable(lcd_enable),
		.done(lcd_done),

		.rs(lcd_rs),
		.e(lcd_e),
		.d(lcd_d),
		.awake(lcd_awake)
	);


	keyboard keyboard_inst (
		.clk(clk),

		.row(row),
		.col(col),

		.out(key)
	);

	driver_4seg driver_4seg_inst (
		.clk(clk),

		.seg0({1'd0, next_state}),
		.seg1({1'd0, state}),
		.seg2({2'd0, tries}),
		.seg3(password[3:0]),

		.out(segmentos),
		.power(power)
	);


endmodule