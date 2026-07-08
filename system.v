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

	input wire closed_raw, // If the continuity circuit is closed, the system is locked
	output reg alarm, // To activate the buzzer when the system is manipulated

	output reg power_on = 1'b1, // Controls the power to the system, if 0, the system is off

	output wire error,

	output wire [6:0] segmentos,
	output wire [3:0] power
	
	);



	wire rst = ~rst_in;






	// I2C /////////////////////////////////////////////////////////////////////////////////////////////////
	reg [2:0] i2c_command = 0;
		// 0: INIT
		// 1: LOAD PASSWORD
		// 2: LOAD SENSITIVITY
		// 3: CHANGE PASSWORD
		// 4: CHANGE SENSITIVITY
		// 5: SLEEP
		// 6: WAKEUP
	reg i2c_enable = 0; // To confirm command
	wire i2c_busy; // To indicate that the driver is busy
	wire manipulation; // Alert from mpu
	reg prev_manipulation = 1'b1; // Previous state of manipulation
	reg [2:0] sensitivity_temp = 0; // Sensitivity meanwhile the user selects the sensitivity value
	reg [15:0] pass_sens_in = 16'hFFFF; // Input for the eemprom, password or sensitivity to be written
	wire [15:0] password; // Password read from eeprom or eeprom
	reg [15:0] password_temp = 0; // Password meanwhile the user enters the new password
	wire [2:0] sensitivity; // Sensitivity value read from eeprom

	localparam I2C_INIT = 3'd0;
	localparam I2C_LOAD_PASSWORD = 3'd1;
	localparam I2C_LOAD_SENSITIVITY = 3'd2;
	localparam I2C_CHANGE_PASSWORD = 3'd3;
	localparam I2C_CHANGE_SENSITIVITY = 3'd4;
	localparam I2C_SLEEP = 3'd5;
	localparam I2C_WAKEUP = 3'd6;



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
		// 9: FEEDBACK_PASSWORD
		// 10: FEEDBACK_SENSITIVITY
		// 11: PASSWORDS_DO_NOT_MATCH

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
	localparam LCD_FEEDBACK_PASSWORD = 4'd9;
	localparam LCD_FEEDBACK_SENSITIVITY = 4'd10;
	localparam LCD_PASSWORDS_DO_NOT_MATCH = 4'd11;
	


	// Keyboard ///////////////////////////////////////////////////////////////////////////////////////////////
	
	wire [3:0] key;
	wire key_pressed = (key != 4'd15); // 15 means no key pressed
	reg prev_key_pressed = 0;


	// Continuity circuit ///////////////
	wire closed;
	reg prev_closed = 0;
	debouncer closed_debouncer (
		.clk(clk),
		.rst(rst),
		.raw(closed_raw),
		.clean(closed)
	);



	// Wating times
	localparam TIME_LONG_WAIT = 32'd50_000_000;
	localparam INCORRECT_WAIT = 32'd50_000_000; // 1 second
	localparam CORRECT_WAIT = 32'd50_000_000; // 1 second
	localparam INCORRECT_WAIT_NO_TRIES = 32'd500_000_000; // 10 second
	localparam TIME_BREAK_ALARM = 32'd500_000_000; // 10 second
	localparam MAX_TIME_ALARM = {32{1'b1}}; // ~ 86 seconds 
	localparam MAX_TIME_AWAKE = 30'd500_000_000; // 10 seconds, time to wait before going to sleep when the system is locked
	localparam TIME_TO_SHUT_DOWN = 30'd1_000_000; // 20 seconds, time to wait before shutting down the system when it is unlocked


	// Other registers

	reg [31:0] counter = 0;

	reg [1:0] current_digit = 0; // Password digit being entered
	reg [1:0] tries = 2'd3; // Number of tries to enter the password

	reg [29:0] power_counter = 0; // Counter to go to sleep after a while of inactivity


	

	// STATES /////////////////////////////////////////////////////////////////////////////////////////////
	localparam LONG_WAIT = 5'd0;
	localparam INIT0 = 5'd1;
	localparam INIT1 = 5'd2;
	localparam WAIT  = 5'd3;
	localparam LOCKED_IDLE = 5'd4;
	localparam CIRCUIT_BROKEN = 5'd5;
	localparam UNLOCKED_IDLE_SELECTION   = 5'd6;
	localparam UNLOCKED_IDLE_SENSITIVITY = 5'd7;
	localparam SHOW_NEW_SENSITIVITY = 5'd8;
	localparam SAVE_SENSITIVITY = 5'd9;
	localparam UNLOCKED_IDLE_SET_PASSWORD = 5'd10;
	localparam CONFIRM_PASSWORD = 5'd11;
	localparam VERIFY_NEW_PASSWORD = 5'd12;
	localparam NEW_PASSWORD_FEEDBACK = 5'd13;
	localparam CHECK_PASSWORD = 5'd14;
	localparam CORRECT   = 5'd15;
	localparam INCORRECT = 5'd16;
	localparam SLEEP = 5'd17;




	reg [4:0] state = LONG_WAIT;
	reg [4:0] next_state = INIT0;


	// DEBUG CLK
	reg clk_debug = 0;
	localparam CLK_DEBUG_DIV = 25'd25_000_000; // 1 second
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
			state <= LONG_WAIT;
			next_state <= INIT0;
			counter <= 0;
			current_digit <= 0;
			tries <= 2'd3;
			alarm <= 1'b0;
			i2c_enable <= 1'b0;
			lcd_instruction <= LCD_TURN_OFF;
			lcd_enable <= 1'b1;
			alarm <= 1'b0;
			power_on <= 1'b1;

		end
		else begin
			prev_key_pressed <= key_pressed;
			prev_closed <= closed;
			prev_manipulation <= manipulation;

			case(state)

				LONG_WAIT: begin
					i2c_enable <= 1'b0;
					lcd_enable <= 1'b0;

					if (counter > TIME_LONG_WAIT) begin
						state <= next_state;
						counter <= 0;
					end else begin
						counter <= counter + 1'b1;
					end
				end

				INIT0: begin // Initialize eeprom, load password, load sensitivity
					if (~i2c_busy && lcd_done) begin
						i2c_command <= I2C_INIT;
						i2c_enable <= 1'b1;
						state <= WAIT;
						next_state <= INIT1;
					end
				end

				INIT1: begin // Set display according to the state of the system (locked or unlocked)
					sensitivity_temp <= sensitivity;
					state <= LONG_WAIT; // To stabilize the system 
					counter <= 0;
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


				LOCKED_IDLE: begin // Here the user can enter the password to unlock the system


					if ((prev_closed & ~closed) | (prev_manipulation & ~manipulation)) begin // Break or manipulation
						alarm <= 1'b1;
						lcd_instruction <= LCD_INCORRECT;
						lcd_enable <= 1'b1;
						state <= WAIT;
						next_state <= CIRCUIT_BROKEN;
						counter <= 0;
					end
					else begin
						if (alarm) begin // if the alarm has been sounded for too much time
							if (counter == MAX_TIME_ALARM) begin
								alarm <= 1'b0;
								counter <= 0;
							end
							else begin
								counter <= counter + 1'b1;
							end
						end
						

						if (key_pressed && ~prev_key_pressed) begin // A key has just been pressed
							power_counter <= 0; // Reset power counter

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
							end else begin // A number key has been pressed
								// Password input is stored in pass_sens_in
								lcd_instruction <= LCD_AUTHENTICATE;
								lcd_enable <= 1'b1;
								state <= WAIT;
								next_state <= LOCKED_IDLE;
								case (current_digit)
									2'd0: begin
										pass_sens_in[15:12] <= key;
										lcd_data <= "#___";
										current_digit <= 2'd1;
									end
									2'd1: begin
										pass_sens_in[11:8] <= key;
										lcd_data <= "##__";
										current_digit <= 2'd2;
									end
									2'd2: begin
										pass_sens_in[7:4] <= key;
										lcd_data <= "###_";
										current_digit <= 2'd3;
									end
									2'd3: begin
										pass_sens_in[3:0] <= key;
										lcd_enable <= 1'b0;
										state <= CHECK_PASSWORD;
									end
								endcase
							end
						end
						else if (power_counter >= MAX_TIME_AWAKE) begin // If the user has not pressed any key for a while, go to sleep
							lcd_instruction <= LCD_TURN_OFF;
							lcd_enable <= 1'b1;
							state <= WAIT;
							next_state <= SLEEP;
							power_counter <= 0;
							counter <= 0;
						end else begin
							power_counter <= power_counter + 1'b1;
						end
					end

				end


				CIRCUIT_BROKEN: begin // Circuit has been broken
					alarm <= 1'b1;
					tries <= 2'd0;
					if (counter > TIME_BREAK_ALARM) begin
						lcd_instruction <= LCD_AUTHENTICATE;
						lcd_data <= "____";
						current_digit <= 0;
						lcd_enable <= 1'b1;
						state <= WAIT;
						next_state <= LOCKED_IDLE;
						counter <= 0;
					end else begin
						counter <= counter + 1'b1;
					end
				end

				UNLOCKED_IDLE_SELECTION: begin // Selection between set sensitivity or set password
					alarm <= 1'b0; // Reset alarm
					tries <= 2'd3; // Reset tries
					if (closed & ~prev_closed) begin // Lock the system
						lcd_instruction <= LCD_AUTHENTICATE;
						lcd_data <= "____";
						lcd_enable <= 1'b1;
						state <= WAIT;
						next_state <= LOCKED_IDLE;
						current_digit <= 0;
					end
					else if (key_pressed && ~prev_key_pressed) begin // A key has just been pressed
						power_counter <= 0; // Reset power counter

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
								lcd_data <= {29'd0, sensitivity};
								next_state <= UNLOCKED_IDLE_SENSITIVITY;
							end
						end
					end
					else if (power_counter >= TIME_TO_SHUT_DOWN) begin // If the user has not pressed any key for a while, go to sleep
						power_counter <= 0;
						power_on <= 1'b0; // Turn off the system
					end else begin
						power_counter <= power_counter + 1'b1;
					end
				end


				UNLOCKED_IDLE_SENSITIVITY: begin // Set sensitivity
					alarm <= 1'b0; // Reset alarm
					tries <= 2'd3; // Reset tries
					if (closed & ~prev_closed) begin // Lock the system
						lcd_instruction <= LCD_AUTHENTICATE;
						lcd_data <= "____";
						lcd_enable <= 1'b1;
						state <= WAIT;
						next_state <= LOCKED_IDLE;
						current_digit <= 0;
					end
					else if (key_pressed && ~prev_key_pressed) begin // A key has just been pressed
						power_counter <= 0; // Reset power counter

						if (key == 4'd10) begin // '*' Cancel and return to selection
							sensitivity_temp <= sensitivity;
							lcd_instruction <= LCD_SELECT_SENSITIVITY;
							lcd_enable <= 1'b1;
							state <= WAIT;
							next_state <= UNLOCKED_IDLE_SELECTION;
						end
						if (key == 4'd11) begin // '#' Save sensitivity and return to selection
							state <= WAIT;
							if (sensitivity_temp != sensitivity) begin // If the user changed the sensitivity, load it to the eeprom
								pass_sens_in <= {13'd0, sensitivity_temp};
								i2c_command <= I2C_CHANGE_SENSITIVITY;
								i2c_enable <= 1'b1;

								lcd_instruction <= LCD_FEEDBACK_SENSITIVITY;
								lcd_enable <= 1'b1;
								next_state <= SAVE_SENSITIVITY;
							end
							else begin
								lcd_instruction <= LCD_SELECT_SENSITIVITY;
								lcd_enable <= 1'b1;
								next_state <= UNLOCKED_IDLE_SELECTION;
							end
						end
						else if (key <= 3'd1 || key == 4'd4 || key == 3'd7) begin // Decrease sensitivity
							if (sensitivity_temp > 3'd0) begin
								sensitivity_temp <= sensitivity_temp - 1'b1;
								state <= SHOW_NEW_SENSITIVITY;
							end
						end
						else if (key == 3'd3 || key == 4'd6 || key == 4'd9) begin // Increase sensitivity
							if (sensitivity_temp < 3'd7) begin
								sensitivity_temp <= sensitivity_temp + 1'b1;
								state <= SHOW_NEW_SENSITIVITY;
							end
						end
					end

					else if (power_counter >= TIME_TO_SHUT_DOWN) begin // If the user has not pressed any key for a while, go to sleep
						power_counter <= 0;
						power_on <= 1'b0; // Turn off the system
					end else begin
						power_counter <= power_counter + 1'b1;
					end
				end

				SHOW_NEW_SENSITIVITY: begin // Show new sensitivity
					lcd_instruction <= LCD_SENSITIVITY;
					lcd_data <= {29'd0, sensitivity_temp};
					lcd_enable <= 1'b1;
					state <= WAIT;
					next_state <= UNLOCKED_IDLE_SENSITIVITY;
				end

				SAVE_SENSITIVITY: begin // Wait 1 second to show the feedback message and return to selection
					if (counter > CORRECT_WAIT) begin
						lcd_instruction <= LCD_SELECT_SENSITIVITY;
						lcd_enable <= 1'b1;
						state <= WAIT;
						next_state <= UNLOCKED_IDLE_SELECTION;
						counter <= 0;
					end else begin
						counter <= counter + 1'b1;
					end
					
				end


				UNLOCKED_IDLE_SET_PASSWORD: begin // Change password
					alarm <= 1'b0; // Reset alarm
					tries <= 2'd3; // Reset tries
					if (closed & ~prev_closed) begin // Lock the system
						lcd_instruction <= LCD_AUTHENTICATE;
						lcd_data <= "____";
						lcd_enable <= 1'b1;
						state <= WAIT;
						next_state <= LOCKED_IDLE;
						current_digit <= 0;
					end
					else if (key_pressed && ~prev_key_pressed) begin // A key has just been pressed
						power_counter <= 0; // Reset power counter

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
									current_digit <= 2'd1;
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
									pass_sens_in[15:12] <= key;
									lcd_data <= "#___";
									current_digit <= 2'd1;
								end
								2'd1: begin
									pass_sens_in[11:8] <= key;
									lcd_data <= "##__";
									current_digit <= 2'd2;
								end
								2'd2: begin
									pass_sens_in[7:4] <= key;
									lcd_data <= "###_";
									current_digit <= 2'd3;
								end
								2'd3: begin
									pass_sens_in[3:0] <= key;
									lcd_instruction <= LCD_CONFIRM_PASSWORD;
									lcd_data <= "____";
									next_state <= CONFIRM_PASSWORD;
									current_digit <= 0;
								end
							endcase
						end
					end

					else if (power_counter >= TIME_TO_SHUT_DOWN) begin // If the user has not pressed any key for a while, go to sleep
						power_counter <= 0;
						power_on <= 1'b0; // Turn off the system
					end else begin
						power_counter <= power_counter + 1'b1;
					end
				end

				CONFIRM_PASSWORD: begin // Confirm new password
					alarm <= 1'b0; // Reset alarm
					tries <= 2'd3; // Reset tries
					if (closed & ~prev_closed) begin // Lock the system
						lcd_instruction <= LCD_AUTHENTICATE;
						lcd_data <= "____";
						lcd_enable <= 1'b1;
						state <= WAIT;
						next_state <= LOCKED_IDLE;
						current_digit <= 0;
					end
					else if (key_pressed && ~prev_key_pressed) begin // A key has just been pressed
						power_counter <= 0; // Reset power counter

						if (key == 4'd11) begin // '#' key to delete
							lcd_instruction <= LCD_CONFIRM_PASSWORD;
							lcd_enable <= 1'b1;
							state <= WAIT;
							next_state <= CONFIRM_PASSWORD;
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

						end else if (key == 4'd10) begin // '*' key to cancel and return to selection
							lcd_instruction <= LCD_SELECT_SET_PASSWORD;
							lcd_enable <= 1'b1;
							state <= WAIT;
							next_state <= UNLOCKED_IDLE_SELECTION;
							current_digit <= 0;

						end else begin
							lcd_instruction <= LCD_CONFIRM_PASSWORD;
							lcd_enable <= 1'b1;
							state <= WAIT;
							next_state <= CONFIRM_PASSWORD;
							case (current_digit)
								2'd0: begin
									password_temp[15:12] <= key;
									lcd_data <= "#___";
									current_digit <= 2'd1;
								end
								2'd1: begin
									password_temp[11:8] <= key;
									lcd_data <= "##__";
									current_digit <= 2'd2;
								end
								2'd2: begin
									password_temp[7:4] <= key;
									lcd_data <= "###_";
									current_digit <= 2'd3;
								end
								2'd3: begin
									password_temp[3:0] <= key;
									lcd_enable <= 1'b0; // No update lcd until checking password
									next_state <= VERIFY_NEW_PASSWORD;
									current_digit <= 0;
								end
							endcase
						end
					end

					else if (power_counter >= TIME_TO_SHUT_DOWN) begin // If the user has not pressed any key for a while, go to sleep
						power_counter <= 0;
						power_on <= 1'b0; // Turn off the system
					end else begin
						power_counter <= power_counter + 1'b1;
					end
				end

				VERIFY_NEW_PASSWORD: begin
					if (password_temp == pass_sens_in) begin // Passwords match
						// LCD
						lcd_instruction <= LCD_FEEDBACK_PASSWORD;
						lcd_enable <= 1'b1;

						// I2C
						i2c_command <= I2C_CHANGE_PASSWORD;
						i2c_enable <= 1'b1;

						state <= WAIT;
						next_state <= NEW_PASSWORD_FEEDBACK;
						counter <= 0;
					end else begin // Passwords do not match
						lcd_instruction <= LCD_PASSWORDS_DO_NOT_MATCH;
						lcd_enable <= 1'b1;
						state <= WAIT;
						next_state <= NEW_PASSWORD_FEEDBACK;
					end
				end

				NEW_PASSWORD_FEEDBACK: begin // Show message for a second and return to selection
					if (counter > CORRECT_WAIT) begin
						lcd_instruction <= LCD_SELECT_SET_PASSWORD;
						lcd_enable <= 1'b1;
						state <= WAIT;
						next_state <= UNLOCKED_IDLE_SELECTION;
						counter <= 0;
					end else begin
						counter <= counter + 1'b1;
					end
					
				end


				CHECK_PASSWORD: begin
					lcd_enable <= 1'b1;
					counter <= 0;
					if (pass_sens_in == password) begin
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



				SLEEP: begin
					if ((prev_closed & ~closed) | (prev_manipulation & ~manipulation)) begin // Break or manipulation
						alarm <= 1'b1;
						lcd_instruction <= LCD_INCORRECT;
						lcd_enable <= 1'b1;
						state <= WAIT;
						next_state <= CIRCUIT_BROKEN;
						counter <= 0;
					end
					else begin
						
						if (alarm) begin // if the alarm has been sounded for too much time
							if (counter == MAX_TIME_ALARM) begin
								alarm <= 1'b0;
								counter <= 0;
							end
							else begin
								counter <= counter + 1'b1;
							end
						end

						if (key_pressed && ~prev_key_pressed) begin // A key has just been pressed
							lcd_instruction <= LCD_AUTHENTICATE;
							lcd_data <= "____";
							lcd_enable <= 1'b1;
							state <= WAIT;
							next_state <= LOCKED_IDLE;
							current_digit <= 0;
						end
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
		.sensitivity_in(sensitivity_temp), // Sensitivity for manipulation detection.

		.pass_sens_in(pass_sens_in),
		.password_out(password),
		.sensitivity_out(sensitivity),

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

		.seg0(password[3:0]),
		.seg1(password[7:4]),
		.seg2(password[11:8]),
		.seg3(password[15:12]),

		.out(segmentos),
		.power(power)
	);


endmodule
