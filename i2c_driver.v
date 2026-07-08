
// Comands
// 0: INIT reads password, reads sensitivity, initializes mpu, sends to wakeup state
// 1: LOAD PASSWORD update password_out
// 2: LOAD SENSITIVITY update sensitivity_out
// 3: CHANGE PASSWORD
// 4: CHANGE SENSITIVITY
// 5: SLEEP stops i2c communication
// 6: WAKEUP continues i2c communication

// Recommendations
// Send commands in negedge busy

module i2c_driver(
	input clk,
	input rst,
	
	inout sda,
	output scl,

	input [2:0] command,
	input enable, // To confirm command
	output busy, // To indicate that the driver is busy

	output manipulation, // Alert from mpu
	input wire [2:0] sensitivity_in, // Sensitivity for manipulation detection.

	input wire [15:0] pass_sens_in,
	output wire [15:0] password_out,
	output wire [2:0] sensitivity_out, // Given value from eeprom

	output error,
	output wire ackled

	);





	// i2c master interface, conexions ////////////////////////////////////////
	localparam EEPROM = 1'b0;// 0: eeprom_driver
	localparam MPU = 1'b1;// 1: mpu_driver
	reg selector = 0; // Selector

	wire mpu_start; // MPU controls this signal
	wire eeprom_start; // EEPROM controls this signal
	wire start = selector ? mpu_start : eeprom_start; // Signal to be sent to i2c_master

	wire [2:0] mpu_restart_pos;
	wire [2:0] eeprom_restart_pos;
	wire [2:0] restart_pos = selector ? mpu_restart_pos : eeprom_restart_pos;

	wire [7:0] mpu_data_amount;
	wire [7:0] eeprom_data_amount;
	wire [7:0] data_amount = selector ? mpu_data_amount : eeprom_data_amount;

	wire [7:0] mpu_read_amount;
	wire [7:0] eeprom_read_amount;
	wire [7:0] read_amount = selector ? mpu_read_amount : eeprom_read_amount;

	wire [2:0] mpu_data_rw;
	wire [2:0] eeprom_data_rw;
	wire [2:0] data_rw = selector ? mpu_data_rw : eeprom_data_rw;

	wire [63:0] mpu_i2c_data;
	wire [63:0] eeprom_i2c_data;
	wire [63:0] i2c_data = selector ? mpu_i2c_data : eeprom_i2c_data;

	// I2C master outputs ///////////////////
	wire [8:0] i2c_result;
	wire ack;
	wire i2c_busy;

	// Control signals /////////////////////
	reg driver_enable = 0;
	wire mpu_enable = driver_enable & (selector == MPU);
	wire eeprom_enable = driver_enable & (selector == EEPROM);

	reg [1:0] instruction = 0; // It works for both drivers
	wire eeprom_done;
	wire mpu_done;

	// Special outputs/inputs ////////////////
	wire signed [15:0] accX;
	wire signed [15:0] accY;
	wire signed [15:0] accZ;

	wire [15:0] abs_accX = accX < 0 ? -accX : accX;
	wire [15:0] abs_accY = accY < 0 ? -accY : accY;
	wire [15:0] abs_accZ = accZ < 0 ? -accZ : accZ;

	// Manipulation detection ///////////////
	localparam CHECK_MANIPULATION_MAX = 5_000_000; // 10 Hz
	reg [22:0] check_manipulation_counter = 0;

	reg [15:0] prev_accX; // It will probably generate a manipulation alert when the mpu is initialized
	reg [15:0] prev_accY;
	reg [15:0] prev_accZ;

	///////////// SENSITIVITY THRESHOLD /////////////////////////////////////////////////////////////
	wire signed [15:0] TH = sensitivity_in == 3'd7 ? 16'sd400 : // Sensitivity threshold for each axis
		sensitivity_in == 3'd6 ? 16'sd1000 :
		sensitivity_in == 3'd5 ? 16'sd2000 :
		sensitivity_in == 3'd4 ? 16'sd4000 : 
		sensitivity_in == 3'd3 ? 16'sd6000 :
		sensitivity_in == 3'd2 ? 16'sd8000 :
		sensitivity_in == 3'd1 ? 16'sd10_000 : 16'sd15_000;
	

	// STATES //////////////////////////////
	localparam SLEEP = 4'd0;
	localparam INIT0 = 4'd1;
	localparam INIT1 = 4'd2;
	localparam INIT2 = 4'd3;
	localparam LOAD_PASSWORD = 4'd4;
	localparam LOAD_SENSITIVITY = 4'd5;
	localparam CHANGE_PASSWORD = 4'd6;
	localparam CHANGE_SENSITIVITY = 4'd7;
	localparam AWAKE = 4'd8; // Checks for commands and manipulation counter
	localparam CHECK_MANIPULATION = 4'd9;
	localparam WAIT_DONE = 4'd10;

	reg [3:0] state = SLEEP;
	reg [3:0] next_state = SLEEP;

	assign busy = ~(((state == SLEEP) || (state == AWAKE)) && ~(enable & ~driver_enable)); // Busy when not in sleep or awake with enable signal

	// Registers 
	reg prev_enable = 0;
	reg prev_done = 0;





/////////////////////////////////////////////////////
	always @(posedge clk or posedge rst) begin
		if (rst) begin
			state <= SLEEP;
			check_manipulation_counter <= 0;
		end else begin
			prev_enable <= enable;

			case (state)
				SLEEP: begin
					if (enable & ~prev_enable) begin
						case (command)
							0: begin
								state <= INIT0;
							end
							1: begin
								state <= LOAD_PASSWORD;
							end
							2: begin
								state <= LOAD_SENSITIVITY;
							end
							3: begin
								state <= CHANGE_PASSWORD;
							end
							4: begin
								state <= CHANGE_SENSITIVITY;
							end
							5: begin
								state <= SLEEP;
							end
							6: begin
								state <= AWAKE;
							end
						endcase
					end
				end


				INIT0: begin // Load password
					selector <= EEPROM;
					instruction <= 2'd0; // READ PASSWORD
					driver_enable <= 1'b1;
					prev_done <= eeprom_done;
					state <= WAIT_DONE;
					next_state <= INIT1;
				end

				INIT1: begin // Load sensitivity
					selector <= EEPROM;
					instruction <= 2'd2; // READ SENSITIVITY
					driver_enable <= 1'b1;
					prev_done <= eeprom_done;
					state <= WAIT_DONE;
					next_state <= INIT2;
				end

				INIT2: begin // Set mpu
					selector <= MPU;
					instruction <= 2'd1; // INIT
					driver_enable <= 1'b1;
					prev_done <= mpu_done;
					state <= WAIT_DONE;
					next_state <= AWAKE;
				end


				LOAD_PASSWORD: begin
					selector <= EEPROM;
					instruction <= 2'd0; // READ PASSWORD
					driver_enable <= 1'b1;
					state <= WAIT_DONE;
					next_state <= AWAKE;
				end

				LOAD_SENSITIVITY: begin
					selector <= EEPROM;
					instruction <= 2'd2; // READ SENSITIVITY
					driver_enable <= 1'b1;
					state <= WAIT_DONE;
					next_state <= AWAKE;
				end

				CHANGE_PASSWORD: begin
					selector <= EEPROM;
					instruction <= 2'd1; // CHANGE PASSWORD
					driver_enable <= 1'b1;
					state <= WAIT_DONE;
					next_state <= AWAKE;
				end

				CHANGE_SENSITIVITY: begin
					selector <= EEPROM;
					instruction <= 2'd3; // CHANGE SENSITIVITY
					driver_enable <= 1'b1;
					state <= WAIT_DONE;
					next_state <= AWAKE;
				end


				AWAKE: begin
					if (enable & ~prev_enable) begin
						case (command)
							0: begin
								state <= INIT0;
							end
							1: begin
								state <= LOAD_PASSWORD;
							end
							2: begin
								state <= LOAD_SENSITIVITY;
							end
							3: begin
								state <= CHANGE_PASSWORD;
							end
							4: begin
								state <= CHANGE_SENSITIVITY;
							end
							5: begin
								state <= SLEEP;
							end
							6: begin
								state <= AWAKE;
							end
						endcase

					end else if (check_manipulation_counter > CHECK_MANIPULATION_MAX) begin // Manipulation
						check_manipulation_counter <= 0;
						state <= CHECK_MANIPULATION;
					end else begin
						check_manipulation_counter <= check_manipulation_counter + 1'b1;
					end
				end


				CHECK_MANIPULATION: begin // Send request to mpu to read accelerometer data
					prev_accX <= abs_accX;
					prev_accY <= abs_accY;
					prev_accZ <= abs_accZ;

					selector <= MPU;
					instruction <= 2'd2; // GET_ACCEL
					driver_enable <= 1'b1;
					state <= WAIT_DONE;
					next_state <= AWAKE;
				end



				WAIT_DONE: begin
					driver_enable <= 1'b0;
					prev_done <= eeprom_done & mpu_done;
					if ((eeprom_done && mpu_done) && ~prev_done) begin
						state <= next_state;
					end
				end

			endcase
		end
	end	



	// Manipulation detection (Combinational logic)
	reg signed [15:0] accX_diff = 0;
	reg signed [15:0] accY_diff = 0;
	reg signed [15:0] accZ_diff = 0;

	assign manipulation = (accX_diff > TH) || (accY_diff > TH) || (accZ_diff > TH);

	always @(*) begin
		if (abs_accX >= prev_accX) begin
			accX_diff = abs_accX - prev_accX;
		end else begin
			accX_diff = prev_accX - abs_accX;
		end

		if (abs_accY >= prev_accY) begin
			accY_diff = abs_accY - prev_accY;
		end else begin
			accY_diff = prev_accY - abs_accY;
		end

		if (abs_accZ >= prev_accZ) begin
			accZ_diff = abs_accZ - prev_accZ;
		end else begin
			accZ_diff = prev_accZ - abs_accZ;
		end


	end


	// DRIVERS ///////////////////////////////////////////

	eeprom_driver memory_driver (
		.clk(clk),
		.rst(rst),

		// i2c master interface
		.start(eeprom_start),
		.restart_pos(eeprom_restart_pos),
		.data_amount(eeprom_data_amount),
		.read_amount(eeprom_read_amount),
		.data_rw(eeprom_data_rw),
		.i2c_data(eeprom_i2c_data),

		.i2c_result(i2c_result),
		.i2c_busy(i2c_busy),

		// User
		.instruction(instruction),
		.enable(eeprom_enable),
		.done(eeprom_done),

		.in(pass_sens_in),
		.password_out(password_out),
		.sensitivity_out(sensitivity_out)
	);



	mpu_driver accelerometer_driver(
		.clk(clk),
		.rst(rst),

		// i2c master interface
		.start(mpu_start),
		.restart_pos(mpu_restart_pos),
		.data_amount(mpu_data_amount),
		.read_amount(mpu_read_amount),
		.data_rw(mpu_data_rw),
		.i2c_data(mpu_i2c_data),

		.i2c_result(i2c_result),
		.i2c_busy(i2c_busy),

		// User
		.instruction(instruction),
		.enable(mpu_enable),
		.done(mpu_done),

		.accelX(accX),
		.accelY(accY),
		.accelZ(accZ)

	);


	i2c_master i2c(
		.clk(clk),
		.sda(sda),
		.scl(scl),

		.start(start),
		.stop_reading(1'b0), // Will not be used in this module

		.restart_pos(restart_pos),
		.data_amount(data_amount),
		.read_amount(read_amount),
		.data_rw(data_rw),
		.data_in(i2c_data),
		.data_out(i2c_result),

		
		.ack(ackled),
		.error(error),
		.busy(i2c_busy)
	);


endmodule