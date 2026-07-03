// Intruccions:
// 0: TURN OFF
// 1: TURN ON
// 2: AUTHENTICATION + 4 characters to show
// 3: UNLOCKED
// 4: INCORRECT
// 5: SET SENSIBILITY + value to set the bar 0 - 15
// 6: CLEAR


module lcd_driver (
	input clk,
	input rst,

	// Control signals
	input [2:0] instruction,
	input wire [31:0] data, // Additional data for instructions that require it. Keep until done
	input enable,
	output wire done,

	// Parallel connections
	output wire rs,
	output wire e,
	output wire [3:0] d,
	output reg awake = 0


	);
	
	reg [7:0] lcd_data;
	reg lcd_enable = 0;
	reg is_command = 0;
	wire ready;


	// Register
	reg prev_enable = 0;
	reg prev_ready = 0;
	reg [4:0] counter = 5'b0;

	assign done = (state == IDLE);


	// STATES
	localparam IDLE = 3'd0;
	localparam AUTHENTICATION = 3'd1;
	localparam UNLOCKED = 3'd2;
	localparam INCORRECT = 3'd3;
	localparam SENSIBILITY0 = 3'd4;
	localparam SENSIBILITY1 = 3'd5;
	localparam CLEAR = 3'd6;
	localparam WAIT = 3'd7;


	reg [2:0] state = IDLE;
	reg [2:0] next_state = IDLE;

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
						case (instruction)
							0: begin
								awake <= 0; // TURN OFF
							end
							1: begin
								awake <= 1; // TURN ON
							end
							2: begin // AUTHENTICATION
								state <= CLEAR;
								next_state <= AUTHENTICATION;
								awake <= 1;
							end
							3: begin // UNLOCKED
								state <= CLEAR;
								next_state <= UNLOCKED;
								awake <= 1;
							end
							4: begin // INCORRECT
								state <= CLEAR;
								next_state <= INCORRECT;
								awake <= 1;
							end
							5: begin // SET SENSIBILITY
								state <= CLEAR;
								next_state <= SENSIBILITY0;
								awake <= 1;
							end
							6: begin // CLEAR
								state <= CLEAR;
								next_state <= IDLE;
								awake <= 1;
							end
						endcase
					end
				end


				AUTHENTICATION: begin
					if (ready) begin
						counter <= counter + 1;
						is_command <= 0;
						lcd_enable <= 1;
						state <= WAIT;
						next_state <= AUTHENTICATION;

						case (counter)
							5'd0: begin
								lcd_data  <= 8'h84; // Set position 
								is_command <= 1;
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
								lcd_data <= 8'hC6; // Set position
								is_command <= 1;
							end
							5'd10: lcd_data <= data[31:24]; // First character
							5'd11: lcd_data <= data[23:16]; // Second character
							5'd12: lcd_data <= data[15:8]; // Third character
							5'd13: begin 
								lcd_data <= data[7:0]; // Fourth character
								counter <= 0;
								next_state <= IDLE;
							end

							
						endcase
						
					end
				end


				UNLOCKED: begin
					if (ready) begin
						counter <= counter + 1;
						is_command <= 0;
						lcd_enable <= 1;
						state <= WAIT;
						next_state <= UNLOCKED;

						case (counter)
							5'd0: begin
								lcd_data  <= 8'h84; // Set position 
								is_command <= 1;
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
						counter <= counter + 1;
						is_command <= 0;
						lcd_enable <= 1;
						state <= WAIT;
						next_state <= INCORRECT;

						case (counter)
							5'd0: begin
								lcd_data  <= 8'h85; // Set position 
								is_command <= 1;
							end
							5'd1: lcd_data <= "W";
							5'd2: lcd_data <= "R";
							5'd3: lcd_data <= "O";
							5'd4: lcd_data <= "N";
							5'd5: lcd_data <= "G";
							5'd6: begin
								lcd_data <= 8'hC4; // Set position
								is_command <= 1;
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


				SENSIBILITY0: begin
					if (ready) begin
						counter <= counter + 1;
						is_command <= 0;
						lcd_enable <= 1;
						state <= WAIT;
						next_state <= SENSIBILITY0;

						case (counter)
							5'd0: begin
								lcd_data  <= 8'h82; // Set position 
								is_command <= 1;
							end
							5'd1:  lcd_data <= "S";
							5'd2:  lcd_data <= "E";
							5'd3:  lcd_data <= "N";
							5'd4:  lcd_data <= "S";
							5'd5:  lcd_data <= "I";
							5'd6:  lcd_data <= "B";
							5'd7:  lcd_data <= "I";
							5'd8:  lcd_data <= "L";
							5'd9:  lcd_data <= "I";
							5'd10: lcd_data <= "T";
							5'd11: lcd_data <= "Y";
							5'd12: begin
								lcd_data <= 8'hC0; // Set position
								is_command <= 1;
								next_state <= SENSIBILITY1;
								counter <= 0;
							end

						endcase
					end
				end

				SENSIBILITY1: begin // Create bar based on the value of data[3:0]
					if (ready) begin
						counter <= counter + 1;
						is_command <= 0;
						lcd_enable <= 1;
						state <= WAIT;
						next_state <= SENSIBILITY1;

						if (counter <= data[3:0]) begin
							lcd_data <= 8'hFF;
						end else begin
							state <= IDLE;
							counter <= 0;
						end
					end
				end




				CLEAR: begin
					if (ready) begin
						lcd_data <= 8'h01; // CLEAR
						is_command <= 1;
						lcd_enable <= 1;
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
		.ready(ready)
	);
	
endmodule