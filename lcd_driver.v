// Intruccions:
// 0: TURN OFF
// 1: AUTHENTICATION + 4 characters to show
// 2: UNLOCKED
// 3: INCORRECT
// 4: SET SENSITIVITY + value to set the bar 0 - 7
// 5: SELECT SET SENSITIVITY 
// 6: SET PASSWORD + 4 characters to show
// 7: CONFIRM PASSWORD + 4 characters to show
// 8: SELECT SET PASSWORD
// 9: FEEDBACK_PASSWORD
// 10: FEEDBACK_SENSITIVITY


module lcd_driver (
	input clk,
	input rst,

	// Control signals
	input [3:0] instruction,
	input wire [31:0] data, // Additional data for instructions that require it. Keep until done
	input enable,
	output wire done,

	// Parallel connections
	output wire rs,
	output wire e,
	output wire [3:0] d,
	output reg awake = 0,
	// Debug
	output wire [3:0] current_state,
	output wire [3:0] lcd_state


	);

	assign current_state = state;

	
	reg [7:0] lcd_data;
	reg lcd_enable = 0;
	reg is_command = 0;
	wire ready;


	// Register
	reg prev_enable = 0;
	reg prev_ready = 0;
	reg [4:0] counter = 5'b0;

	assign done = (state == IDLE) && ~(enable && ~prev_enable);


	// STATES
	localparam IDLE = 4'd0;
	localparam AUTHENTICATION = 4'd1;
	localparam UNLOCKED = 4'd2;
	localparam INCORRECT = 4'd3;
	localparam SENSITIVITY0 = 4'd4;
	localparam SENSITIVITY1 = 4'd5;
	localparam SELECT_SENSITIVITY = 4'd6;
	localparam SET_PASSWORD = 4'd7;
	localparam SELECT_SET_PASSWORD = 4'd8;
	localparam CONFIRM_PASSWORD = 4'd9;
	localparam FEEDBACK_PASSWORD = 4'd10;
	localparam FEEDBACK_SENSITIVITY = 4'd11;
	localparam CLEAR = 4'd12;
	localparam WAIT = 4'd13;


	reg [3:0] state = IDLE;
	reg [3:0] next_state = IDLE;

	always @(posedge clk or posedge rst) begin
		if (rst) begin
			state <= IDLE;
		end
		else begin
			prev_enable <= enable;
			prev_ready <= ready;

			case (state)
				IDLE: begin
					if (enable && ~prev_enable) begin
						counter <= 0;
						awake <= 1; // Turn on the LCD when an instruction is received
						case (instruction)
							0: begin
								awake <= 0; // TURN OFF
							end
							1: begin // AUTHENTICATION
								state <= CLEAR;
								next_state <= AUTHENTICATION;
								awake <= 1;
							end
							2: begin // UNLOCKED
								state <= CLEAR;
								next_state <= UNLOCKED;
								awake <= 1;
							end
							3: begin // INCORRECT
								state <= CLEAR;
								next_state <= INCORRECT;
								awake <= 1;
							end
							4: begin // SET SENSITIVITY
								state <= CLEAR;
								next_state <= SENSITIVITY0;
								awake <= 1;
							end
							5: begin // SELECTION SET SENSITIVITY
								state <= CLEAR;
								next_state <= SELECT_SENSITIVITY;
								awake <= 1;
							end
							6: begin // SET PASSWORD
								state <= CLEAR;
								next_state <= SET_PASSWORD;
								awake <= 1;
							end
							7: begin // CONFIRM PASSWORD
								state <= CLEAR;
								next_state <= CONFIRM_PASSWORD;
								awake <= 1;
							end
							8: begin // SELECTION SET PASSWORD
								state <= CLEAR;
								next_state <= SELECT_SET_PASSWORD;
								awake <= 1;
							end
							9: begin // FEEDBACK PASSWORD
								state <= CLEAR;
								next_state <= FEEDBACK_PASSWORD;
								awake <= 1;
							end
							10: begin // FEEDBACK SENSITIVITY
								state <= CLEAR;
								next_state <= FEEDBACK_SENSITIVITY;
								awake <= 1;
							end
						endcase
					end
				end


				AUTHENTICATION: begin
					if (ready) begin
						counter <= counter + 1'b1;
						is_command <= 0;
						lcd_enable <= 1'b1;
						state <= WAIT;
						next_state <= AUTHENTICATION;

						case (counter)
							5'd0: lcd_data  <= "x";
							5'd1: begin
								lcd_data  <= 8'h84; // Set position 
								is_command <= 1'b1;
							end
							5'd2: lcd_data <= "P";
							5'd3: lcd_data <= "A";
							5'd4: lcd_data <= "S";
							5'd5: lcd_data <= "S";
							5'd6: lcd_data <= "W";
							5'd7: lcd_data <= "O";
							5'd8: lcd_data <= "R";
							5'd9: lcd_data <= "D";
							5'd10: begin
								lcd_data <= 8'h8F; // Set position
								is_command <= 1'b1;
							end
							5'd11: lcd_data <= 8'h7F; // Left arrow
							5'd12: begin
								lcd_data <= 8'hC0; // Set position
								is_command <= 1'b1;
							end
							5'd13: lcd_data <= "*";
							5'd14: begin 
								lcd_data <= 8'hC6; // Set position
								is_command <= 1'b1;
							end
							5'd15: lcd_data <= data[31:24]; // First character
							5'd16: lcd_data <= data[23:16]; // Second character
							5'd17: lcd_data <= data[15:8]; // Third character
							5'd18: lcd_data <= data[7:0]; // Fourth character
							5'd19: begin 
								lcd_data <= 8'hCF; // Set position
								is_command <= 1'b1;
							end
							5'd20: begin 
								lcd_data <= "#";
								counter <= 0;
								next_state <= IDLE;
							end

							
						endcase
						
					end
				end


				UNLOCKED: begin
					if (ready) begin
						counter <= counter + 1'b1;
						is_command <= 0;
						lcd_enable <= 1'b1;
						state <= WAIT;
						next_state <= UNLOCKED;

						case (counter)
							5'd0: begin
								lcd_data  <= 8'h84; // Set position 
								is_command <= 1'b1;
							end
							5'd1: lcd_data <= "U";
							5'd2: lcd_data <= "N";
							5'd3: lcd_data <= "L";
							5'd4: lcd_data <= "O";
							5'd5: lcd_data <= "C";
							5'd6: lcd_data <= "K";
							5'd7: lcd_data <= "E";
							5'd8: begin
								lcd_data <= "D";
								counter <= 0;
								next_state <= IDLE;
							end
						endcase
					end
				end


				INCORRECT: begin
					if (ready) begin
						counter <= counter + 1'b1;
						is_command <= 0;
						lcd_enable <= 1'b1;
						state <= WAIT;
						next_state <= INCORRECT;

						case (counter)
							5'd0: begin
								lcd_data  <= 8'h85; // Set position 
								is_command <= 1'b1;
							end
							5'd1: lcd_data <= "W";
							5'd2: lcd_data <= "R";
							5'd3: lcd_data <= "O";
							5'd4: lcd_data <= "N";
							5'd5: lcd_data <= "G";
							5'd6: begin
								lcd_data <= 8'hC4; // Set position
								is_command <= 1'b1;
							end
							5'd7:  lcd_data <= "P";
							5'd8:  lcd_data <= "A";
							5'd9:  lcd_data <= "S";
							5'd10: lcd_data <= "S";
							5'd11: lcd_data <= "W";
							5'd12: lcd_data <= "O";
							5'd13: lcd_data <= "R";
							5'd14: begin
								lcd_data <= "D";
								counter <= 0;
								next_state <= IDLE;
							end
						endcase
					end
				end


				SENSITIVITY0: begin
					if (ready) begin
						counter <= counter + 1'b1;
						is_command <= 0;
						lcd_enable <= 1'b1;
						state <= WAIT;
						next_state <= SENSITIVITY0;

						case (counter)
							5'd0: begin
								lcd_data  <= 8'h80; // Set position 
								is_command <= 1'b1;
							end
							5'd1:  lcd_data <= "x";
							5'd2:  lcd_data <= " ";
							5'd3:  lcd_data <= " ";
							5'd4:  lcd_data <= "<";
							5'd5:  begin 
								lcd_data <= 8'h8C; // Set position
								is_command <= 1'b1;
							end
							5'd6:  lcd_data <= ">";
							5'd7:  lcd_data <= " ";
							5'd8:  lcd_data <= " ";
							5'd9:  lcd_data <= 8'h7E; // Right arrow
							5'd10: begin
								lcd_data <= 8'hC0; // Set position
								is_command <= 1'b1;
							end
							5'd11: lcd_data <= "*";
							5'd12: lcd_data <= " ";
							5'd13: lcd_data <= " ";
							5'd14: lcd_data <= "4";
							5'd15: begin
								lcd_data <= 8'hCC; // Set position
								is_command <= 1'b1;
							end
							5'd16: lcd_data <= "6";
							5'd17: lcd_data <= " ";
							5'd18: lcd_data <= " ";
							5'd19: lcd_data <= "8";
							5'd20: begin
								lcd_data <= 8'h84; // Set position
								is_command <= 1'b1;
								next_state <= SENSITIVITY1;
								counter <= 0;
							end

						endcase
					end
				end

				SENSITIVITY1: begin // Create bar based on the value of data[2:0]
					if (ready) begin
						counter <= counter + 1'b1;
						is_command <= 0;
						lcd_enable <= 1'b1;
						state <= WAIT;
						next_state <= SENSITIVITY1;

						if (counter <= data[2:0]) begin
							lcd_data <= 8'hFF;
						end else begin
							state <= IDLE;
							lcd_enable <= 0;
							counter <= 0;
						end
					end
				end

				SELECT_SENSITIVITY: begin
					if (ready) begin
						counter <= counter + 1'b1;
						is_command <= 0;
						lcd_enable <= 1'b1;
						state <= WAIT;
						next_state <= SELECT_SENSITIVITY;

						case (counter)
							5'd0: begin
								lcd_data  <= 8'h80; // Set position 
								is_command <= 1'b1;
							end
							5'd1: lcd_data <= "<";
							5'd2: lcd_data <= " ";
							5'd3: lcd_data <= "S";
							5'd4: lcd_data <= "E";
							5'd5: lcd_data <= "N";
							5'd6: lcd_data <= "S";
							5'd7: lcd_data <= "I";
							5'd8: lcd_data <= "T";
							5'd9: lcd_data <= "I";
							5'd10: lcd_data <= "V";
							5'd11: lcd_data <= "I";
							5'd12: lcd_data <= "T";
							5'd13: lcd_data <= "Y";
							5'd14: lcd_data <= " ";
							5'd15: lcd_data <= " ";
							5'd16: lcd_data <= ">";
							5'd17: begin
								lcd_data <= 8'hC0; // Set position
								is_command <= 1'b1;
							end
							5'd18: lcd_data <= "*";
							5'd19: begin
								lcd_data <= 8'hC7; // Set position
								is_command <= 1'b1;
							end
							5'd20: lcd_data <= "0";
							5'd21: begin
								lcd_data <= 8'hCF; // Set position
								is_command <= 1'b1;
							end
							5'd22: begin
								lcd_data <= "#";
								counter <= 0;
								next_state <= IDLE;
							end

							
						endcase
						
					end
				end


				SET_PASSWORD: begin
					if (ready) begin
						counter <= counter + 1'b1;
						is_command <= 0;
						lcd_enable <= 1'b1;
						state <= WAIT;
						next_state <= SET_PASSWORD;

						case (counter)
							5'd0: lcd_data <= "x";
							5'd1: lcd_data <= " ";
							5'd2: lcd_data <= "S";
							5'd3: lcd_data <= "E";
							5'd4: lcd_data <= "T";
							5'd5: lcd_data <= " ";
							5'd6: lcd_data <= "P";
							5'd7: lcd_data <= "A";
							5'd8: lcd_data <= "S";
							5'd9: lcd_data <= "S";
							5'd10: lcd_data <= "W";
							5'd11: lcd_data <= "O";
							5'd12: lcd_data <= "R";
							5'd13: lcd_data <= "D";
							5'd14: begin
								lcd_data <= 8'hC0; // Set position
								is_command <= 1'b1;
							end
							5'd15: lcd_data <= "*";
							5'd16: begin
								lcd_data <= 8'hC6; // Set position
								is_command <= 1'b1;
							end
							5'd17: lcd_data <= data[31:24]; // First character
							5'd18: lcd_data <= data[23:16]; // Second character
							5'd19: lcd_data <= data[15:8]; // Third character
							5'd20: begin 
								lcd_data <= data[7:0]; // Fourth character
								counter <= 0;
								next_state <= IDLE;
							end

							
						endcase
						
					end
				end


				CONFIRM_PASSWORD: begin
					if (ready) begin
						counter <= counter + 1'b1;
						is_command <= 0;
						lcd_enable <= 1'b1;
						state <= WAIT;
						next_state <= CONFIRM_PASSWORD;

						case (counter)
							5'd0: begin
								lcd_data  <= 8'h84; // Set position 
								is_command <= 1'b1;
							end
							5'd1: lcd_data <= "C";
							5'd2: lcd_data <= "O";
							5'd3: lcd_data <= "N";
							5'd4: lcd_data <= "F";
							5'd5: lcd_data <= "I";
							5'd6: lcd_data <= "R";
							5'd7: lcd_data <= "M";
							5'd8: begin
								lcd_data <= 8'hC6; // Set position
								is_command <= 1'b1;
							end
							5'd9:  lcd_data <= data[31:24]; // First character
							5'd10: lcd_data <= data[23:16]; // Second character
							5'd11: lcd_data <= data[15:8]; // Third character
							5'd12: begin 
								lcd_data <= data[7:0]; // Fourth character
								counter <= 0;
								next_state <= IDLE;
							end

							
						endcase
						
					end
				end


				SELECT_SET_PASSWORD: begin
					if (ready) begin
						counter <= counter + 1'b1;
						is_command <= 0;
						lcd_enable <= 1'b1;
						state <= WAIT;
						next_state <= SELECT_SET_PASSWORD;

						case (counter)
							5'd0: begin
								lcd_data  <= 8'h80; // Set position 
								is_command <= 1'b1;
							end
							5'd1: lcd_data <= "<";
							5'd2: lcd_data <= " ";
							5'd3: lcd_data <= "S";
							5'd4: lcd_data <= "E";
							5'd5: lcd_data <= "T";
							5'd6: lcd_data <= " ";
							5'd7: lcd_data <= "P";
							5'd8: lcd_data <= "A";
							5'd9: lcd_data <= "S";
							5'd10: lcd_data <= "S";
							5'd11: lcd_data <= "W";
							5'd12: lcd_data <= "O";
							5'd13: lcd_data <= "R";
							5'd14: lcd_data <= "D";
							5'd15: lcd_data <= " ";
							5'd16: lcd_data <= ">";
							5'd17: begin
								lcd_data <= 8'hC0; // Set position
								is_command <= 1'b1;
							end
							5'd18: lcd_data <= "*";
							5'd19: begin
								lcd_data <= 8'hC7; // Set position
								is_command <= 1'b1;
							end
							5'd20: lcd_data <= "0";
							5'd21: begin
								lcd_data <= 8'hCF; // Set position
								is_command <= 1'b1;
							end
							5'd22: begin
								lcd_data <= "#";
								counter <= 0;
								next_state <= IDLE;
							end

							
						endcase
						
					end
				end


				FEEDBACK_PASSWORD: begin
					if (ready) begin
						counter <= counter + 1'b1;
						is_command <= 0;
						lcd_enable <= 1'b1;
						state <= WAIT;
						next_state <= FEEDBACK_PASSWORD;

						case (counter)
							5'd0: begin
								lcd_data  <= 8'h84; // Set position 
								is_command <= 1'b1;
							end
							5'd1: lcd_data <= "P";
							5'd2: lcd_data <= "A";
							5'd3: lcd_data <= "S";
							5'd4: lcd_data <= "S";
							5'd5: lcd_data <= "W";
							5'd6: lcd_data <= "O";
							5'd7: lcd_data <= "R";
							5'd8: lcd_data <= "D";
							5'd9: begin
								lcd_data <= 8'hC4; // Set position
								is_command <= 1'b1;
							end
							5'd10: lcd_data <= "C";
							5'd11: lcd_data <= "H";
							5'd12: lcd_data <= "A";
							5'd13: lcd_data <= "N";
							5'd14: lcd_data <= "G";
							5'd15: lcd_data <= "E";
							5'd16: begin
								lcd_data <= "D";
								counter <= 0;
								next_state <= IDLE;
							end
						endcase
					end
				end



				FEEDBACK_SENSITIVITY: begin
					if (ready) begin
						counter <= counter + 1'b1;
						is_command <= 0;
						lcd_enable <= 1'b1;
						state <= WAIT;
						next_state <= FEEDBACK_SENSITIVITY;

						case (counter)
							5'd0: begin
								lcd_data  <= 8'h83; // Set position 
								is_command <= 1'b1;
							end
							5'd1: lcd_data <= "S";
							5'd2: lcd_data <= "E";
							5'd3: lcd_data <= "N";
							5'd4: lcd_data <= "S";
							5'd5: lcd_data <= "I";
							5'd6: lcd_data <= "T";
							5'd7: lcd_data <= "I";
							5'd8: lcd_data <= "V";
							5'd9: lcd_data <= "I";
							5'd10: lcd_data <= "T";
							5'd11: lcd_data <= "Y";
							5'd12: begin
								lcd_data <= 8'hC4; // Set position
								is_command <= 1'b1;
							end
							5'd13: lcd_data <= "C";
							5'd14: lcd_data <= "H";
							5'd15: lcd_data <= "A";
							5'd16: lcd_data <= "N";
							5'd17: lcd_data <= "G";
							5'd18: lcd_data <= "E";
							5'd19: begin
								lcd_data <= "D";
								counter <= 0;
								next_state <= IDLE;
							end
						endcase
					end
				end



				CLEAR: begin
					if (ready) begin
						lcd_data <= 8'h01; // CLEAR
						is_command <= 1'b1;
						lcd_enable <= 1'b1;
						state <= WAIT;
					end
				end

				WAIT: begin
					lcd_enable <= 0;
					if (ready && ~prev_ready) begin // Wait for ready
						state <= next_state;
					end
				end

			endcase




		end
	end


	lcd lcd_connection(
		.clk(clk),
		.data(lcd_data),
		.awake(awake),
		.enable(lcd_enable),
		.is_command(is_command),
		
		.rs(rs),
		.e(e),
		.d(d),
		.ready(ready),
		.current_state(lcd_state)
	);
	
endmodule