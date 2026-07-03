module lcd_driver_test (
	input clk,
	
	output scl,
	inout sda,

	// LCD
	output wire rs,
	output wire e,
	output wire [3:0] d,
	output wire awake,

	
	output wire error,
	
	
	//Debug
	output wire [3:0] leds,
	output ackled,
	output wire [6:0] segmentos,
	output wire [3:0] power,

	
	input rst_in
	);

	wire rst = ~rst_in;

	assign leds[3:0] = ~{1'b1, ~error, done, enable};

	reg [31:0] data = 0;

	wire done;

	// Registers
	reg [2:0] instruction = 0;
	reg [26:0] cnt = 0;
	reg enable = 0;

	// STATES
	localparam INITIAL_WAIT = 3'd0;
	localparam WAIT0 = 3'd1;
	localparam WAIT1 = 3'd2;
	localparam WAIT2 = 3'd3;
	localparam IDLE = 3'd4;

	reg [2:0] state = INITIAL_WAIT;




	always @(posedge clk or posedge rst) begin
		if (rst) begin
			state <= INITIAL_WAIT;
			cnt <= 0;
			instruction <= 0;
			enable <= 0;
		end else begin
			case (state)
				INITIAL_WAIT: begin
					if (cnt == 100_000_000) begin
						state <= WAIT0;
						instruction <= 3'd2; // Authentication
						data <= "##__";
						enable <= 1'b1;
						cnt <= 0;
					end else begin
						cnt <= cnt + 1'b1;
					end
				end

				WAIT0: begin
					enable <= 1'b0;
					if (done) begin
						if (cnt == 100_000_000) begin
							state <= WAIT1;
							enable <= 1'b1;
							instruction <= 3'd3; // Unlocked
							cnt <= 0;
						end else begin
							cnt <= cnt + 1'b1;
						end
					end
				end


				WAIT1: begin
					enable <= 1'b0;
					if (done) begin
						if (cnt == 100_000_000) begin
							state <= WAIT2;
							enable <= 1'b1;
							instruction <= 3'd4; // Incorrect
							cnt <= 0;
						end else begin
							cnt <= cnt + 1'b1;
						end
					end
				end


				WAIT2: begin
					enable <= 1'b0;
					if (done) begin
						if (cnt == 100_000_000) begin
							state <= IDLE;
							enable <= 1'b1;
							instruction <= 3'd5; // Set Sensibility
							data <= {29'd0, 3'd3};
							cnt <= 0;
						end else begin
							cnt <= cnt + 1'b1;
						end
					end
				end

				IDLE: begin
					enable <= 1'b0;
				end
			endcase
		end
					
	end




	lcd_driver lcd_driver_inst (
		.clk(clk),
		.rst(rst),

		// Control signals
		.instruction(instruction),
		.data(data), 
		.enable(enable), // To confirm command
		.done(done), // To indicate that the driver is done

		// Parallel connections
		.rs(rs),
		.e(e),
		.d(d),
	);

	driver_4seg drvseg(
		.clk(clk),

		.seg0({1'b0, state}),
		.seg1(4'd0),
		.seg2(4'd0),
		.seg3(4'd0),

		.out(segmentos),
		.power(power)
	);


endmodule







module eeprom_mpu_test (
	input clk,
	
	output scl,
	inout sda,
	
	output wire error,
	
	
	//Debug
	output wire [3:0] leds,
	output ackled,
	output wire [6:0] segmentos,
	output wire [3:0] power,

	
	input rst_in
	);


	wire rst = ~rst_in;

	reg [2:0] command = 0;
	reg enable = 0;
	wire busy;
	wire manipulation;
	wire [15:0] password;


	// STATES
	localparam INITIAL_WAIT = 3'd0;
	localparam INIT = 3'd1;
	localparam IDLE = 3'd2;

	reg [2:0] state = INITIAL_WAIT;

	reg prev_busy = 0;
	reg [25:0] counter = 0;
	
	reg manipulated = 0;

	always @(posedge clk or posedge rst) begin
		if (rst) begin
			state <= INITIAL_WAIT;
			counter <= 0;
			manipulated <= 0;
			enable <= 0;
		end else begin
			prev_busy <= busy;
			case (state)
				INITIAL_WAIT: begin
					if (counter == 50_000_000) begin
						state <= INIT;
						counter <= 0;
					end else begin
						counter <= counter + 1'b1;
					end
				end

				INIT: begin
					if (~busy) begin 
						state <= IDLE;
						command <= 3'd1; // INIT
						enable <= 1'b1;
					end else begin
						enable <= 1'b0;
					end
				end

				IDLE: begin
					if (manipulation) begin
						manipulated <= 1'b1;
					end
				end
			endcase
		end
	end

	assign leds[1:0] = ~{manipulated, manipulation};
	wire [1:0] asd;

	wire [15:0] accX_db;
	i2c_driver driver(
		.clk(clk),
		.rst(rst),
		
		.sda(sda),
		.scl(scl),

		.command(command), // 0: IDLE, 1: INIT, 2: GET_ACCEL, 3: CHANGE PASSWORD, 4: SLEEP, 5: WAKEUP
		.enable(enable), // To confirm command
		.busy(busy), // To indicate that the driver is busy

		.manipulation(manipulation), // Alert from mpu
		.sensitivity(3'd3), // Sensitivity for manipulation detection.

		.password_in(),
		.password_out(password),

		.error(error),
		.ackled(ackled)
	);

	driver_4seg drvseg(
		.clk(clk),

		.seg0(password[3:0]),
		.seg1(password[7:4]),
		.seg2(password[11:8]),
		.seg3(password[15:12]),

		.out(segmentos),
		.power(power)
	);



endmodule









module keyboard_test (
	input clk,
	
	output scl,
	inout sda,

	output [3:0] row,
	input [2:0] col, // Pull-down resistors
	
	output wire error,
	
	
	//Debug
	output wire [3:0] leds,
	output ackled,
	output wire [6:0] segmentos,
	output wire [3:0] power,

	
	input rst_in
	);


	wire rst = ~rst_in;


	wire [3:0] key_out;

	keyboard keyboard_driver (
		.clk(clk),
		.row(row),
		.col(col),
		.out(key_out),
		.leds(leds)
	);

	driver_4seg drvseg(
		.clk(clk),

		.seg0(key_out),
		.seg1(key_out),
		.seg2(key_out),
		.seg3(key_out),

		.out(segmentos),
		.power(power)
	);



endmodule









module memory_test1 (
	input clk,
	
	output scl,
	inout sda,
	
	output wire error,
	
	
	//Debug
	output wire [3:0] leds,
	output ackled,
	output wire [6:0] segmentos,
	output wire [3:0] power,

	
	input rst_in
	);

	// assign leds[3] = ~scl;
	// assign leds[2] = ~sda;
	// assign leds[1] = 1'b1;
	// assign leds[0] = 1'b1;
	// assign leds = {1'b1, ~state};

	wire rst = ~rst_in;

	reg [1:0] instruction = 0;
	reg enable = 0;
	wire done;
	reg [15:0] password_in = {4'd1, 4'd2, 4'd3, 4'd4}; // 1234
	wire [15:0] password_out;

	reg prev_done = 0;

	// STATES
	localparam INIT = 0;
	localparam IDLE = 1;
	localparam READ = 2;
	localparam WRITE = 3;

	reg [2:0] state = INIT;


	reg [25:0] counter = 0;

	always @(posedge clk or posedge rst) begin

		if (rst) begin
			state <= INIT;
			instruction <= 2'd0; // IDLE
			enable <= 1'b0;
			counter <= 0;
		end else begin
			prev_done <= done;

			case (state)
				INIT: begin
					state <= INIT;
					enable <= 1'b0;
					if (counter == 50_000_000) begin
						state <= WRITE;
						instruction <= 2'd2; // WRITE
						enable <= 1'b1;
						counter <= 0;
					end else begin
						counter <= counter + 1'b1;
					end
				end

				IDLE: begin
					state <= IDLE;
					instruction <= 2'd0; // IDLE
					enable <= 1'b0;
				end

				READ: begin
					enable <= 1'b0;
					if (done && ~prev_done) begin
						state <= IDLE;
					end
				end

				WRITE: begin
					enable <= 1'b0;
					if (done && ~prev_done) begin
						state <= READ;
						instruction <= 2'd1; // READ
						enable <= 1'b1;
					end
				end
			endcase
		end
	end



	// Conexiones
	wire start;
	wire stop_reading;
	wire [2:0] restart_pos;
	wire [2:0] data_amount;
	wire [7:0] read_amount;
	wire [2:0] data_rw;
	wire [63:0] i2c_data;
	wire [8:0] i2c_result;
	wire i2c_busy;

	eeprom_driver memory_driver (
		.clk(clk),
		.rst(rst),

		// i2c master interface
		.start(start),
		.stop_reading(stop_reading),
		.restart_pos(restart_pos),
		.data_amount(data_amount),
		.read_amount(read_amount),
		.data_rw(data_rw),
		.i2c_data(i2c_data),

		.i2c_result(i2c_result),
		.i2c_busy(i2c_busy),

		// User
		.instruction(instruction),
		.enable(enable),
		.done(done),

		.password_in(password_in),
		.password_out(password_out)

		// Debug
		// .leds(leds)
	);

	i2c_master driveri2c(
		.clk(clk),
		.sda(sda),
		.scl(scl),
		.start(start),
		.stop_reading(stop_reading),
		.restart_pos(restart_pos),
		.data_amount(data_amount),
		.read_amount(read_amount),
		.data_rw(data_rw),
		
		.data_in(i2c_data),
		.data_out(i2c_result),
		
		.ack(ackled),
		.error(error),
		.busy(i2c_busy)

		// .leds(leds)
	);

	driver_4seg drvseg(
		.clk(clk),

		.seg0(password_out[3:0]),
		.seg1(password_out[7:4]),
		.seg2(password_out[11:8]),
		.seg3(password_out[15:12]),

		.out(segmentos),
		.power(power)
	);


endmodule











module mpu_driver_test (
	input clk,
	
	output scl,
	inout sda,
	
	output wire error,
	
	
	//Debug
	output wire [3:0] leds,
	output ackled,
	output wire [6:0] segmentos,
	output wire [3:0] power,

	
	input rst_in

	);

	wire [15:0] accXwire;
	wire [15:0] accYwire;
	wire [15:0] accZwire;

	reg [2:0] display_sel = 2;
	wire [15:0] display = display_sel == 0 ? accXwire : 
						display_sel == 1 ? accYwire : 
						display_sel == 2 ? accZwire : 16'b0;

	reg [7:0] instruction = 0;
	reg MPU_enable = 0;
	wire MPU_done;
	reg prev_MPU_done = 0;


	localparam IDLE = 0;
	localparam INIT = 1;
	localparam READ = 2;


	reg [7:0] state = IDLE;
	

	reg [25:0] counter = 0;


	always @(posedge clk) begin
		prev_MPU_done <= MPU_done;
		case(state)
			IDLE: begin // Esperar 1 segundo antes de iniciar la comunicación I2C
				if (counter == 50_000_000) begin
					state <= INIT;
					instruction <= 1'b1; // INIT
					MPU_enable <= 1'b1;
				end else begin
					counter <= counter + 1'b1;
				end
			end
			
			INIT: begin
				MPU_enable <= 1'b0;
				if (MPU_done && ~prev_MPU_done) begin
					state <= READ;
					MPU_enable <= 1'b1;
					instruction <= 2'd2; // GET_ACCEL
				end
			end

			READ: begin
				if (MPU_done && ~prev_MPU_done) begin
					MPU_enable <= 1'b1;
				end else begin
					MPU_enable <= 1'b0;
				end

				if (counter == 50_000_000) begin
					counter <= 0;
					//display_sel <= display_sel + 1'b1;
				end else begin
					counter <= counter + 1'b1;
				end
			end
		endcase
	end


	// Conexiones entre el driver y el maestro I2C
	wire start;
	wire stop_reading;
	wire [2:0] restart_pos;
	wire [2:0] data_amount;
	wire [7:0] read_amount;
	wire [2:0] data_rw;
	wire [63:0] i2c_data;
	wire [8:0] i2c_result;
	wire i2c_busy;

	mpu_driver driver(
		.clk(clk),
		
		// i2c master interface
		.start(start),
		.stop_reading(stop_reading),
		.restart_pos(restart_pos),
		.data_amount(data_amount),
		.read_amount(read_amount),
		.data_rw(data_rw),
		.i2c_data(i2c_data),
		.i2c_result(i2c_result),
		.i2c_busy(i2c_busy),

		// User
		.instruction(instruction),
		.enable(MPU_enable),
		.done(MPU_done),

		.accelX(accXwire),
		.accelY(accYwire),
		.accelZ(accZwire)

		// .leds(leds)
	);



	i2c_master driveri2c(
		.clk(clk),
		.sda(sda),
		.scl(scl),
		.start(start),
		.stop_reading(stop_reading),
		.restart_pos(restart_pos),
		.data_amount(data_amount),
		.read_amount(read_amount),
		.data_rw(data_rw),
		
		.data_in(i2c_data),
		.data_out(i2c_result),
		
		.ack(ackled),
		.error(error),
		.busy(i2c_busy)

		// .leds(leds)
	);

	driver_4seg drvseg(
		.clk(clk),

		.seg0(display[3:0]),
		.seg1(display[7:4]),
		.seg2(display[11:8]),
		.seg3(display[15:12]),

		.out(segmentos),
		.power(power)
	);
	
	
	
endmodule

















module memory_test0 (
	input clk,
	
	output scl,
	inout sda,
	
	output wire error,
	
	
	//Debug
	output wire [3:0] leds,
	output ackled,
	output wire [6:0] segmentos,
	output wire [3:0] power,
	
	
	
	input rst_in
	
	);
	
	wire ackWire;
	assign ackled = ackWire;
	
	
	wire rst = ~rst_in;
	
	reg [26:0] start_cnt = 0;
	reg start = 0;
	
	
	always @(posedge clk) begin
	
		if (rst) begin
			start_cnt <= 1'b0;
			start <= 1'b0;
			
		end
		else begin
			if (start_cnt == 100_000_000) begin
				start <= 1;
			end
			else if (~start) begin
				start_cnt <= start_cnt + 1'b1;
			end
		end
		
		
		
		
	end
	
	reg [15:0] mem_read = 0;
	wire [7:0] reader;
	reg low = 0;
	wire ready;
	always @(posedge ready) begin
		if (low) begin
			mem_read[7:0] <= reader;
			
		end else begin
			mem_read[15:8] <= reader;
			low <= 1;
		end
	end
	
	i2c_master driveri2c(
		.clk(clk),
		.sda(sda),
		.scl(scl),
		.start(start),
		.stop_reading(0),
		.restart_pos(3'd2),
		.data_amount(3'd3),
		.read_amount(2'd1),
		.data_rw(3'd3),
		
		//.data_in(8'b11010001), // MPU
		.data_in({8'hA1, 8'h00, 8'h00, 8'hA0}), // EEPROM Read
		// .data_in({8'h1A, 8'hd7, 8'h00, 8'h00, 8'hA0}), // EEPROM Write
		
		.data_out({ready, reader}),
		
		.ack(ackWire),
		.error(error),
		.busy(),
		.leds(leds)
	);
	
	
	
	driver_4seg drvseg(
		.clk(clk),

		.seg0(mem_read[3:0]),
		.seg1(mem_read[7:4]),
		.seg2(mem_read[11:8]),
		.seg3(mem_read[15:12]),

		.out(segmentos),
		.power(power)
	);
	

endmodule
































module lcd_test (
	input clk,
	
	output rs,
	output e,
	output [3:0] d

	);
	

	reg [23:0] clk_cnt = 0;
	
	
	reg [7:0] data = 0;
	reg is_command = 0;
	reg enable = 0;
	wire ready;
	reg awake = 0;

	
	reg [25:0] cnt_awake = 0;
	
	reg [4:0] index = 0;
	reg ended = 0;
	
	always @(posedge clk)
	begin
		if (cnt_awake == 50_000_000-1) begin
			awake <= 1;
		end else
		begin
			cnt_awake <= cnt_awake + ~awake;
		end
		
		if (~ended) begin
			if (ready & ~enable) begin
				index <= index + 1;
				enable <= 1;
				clk_cnt <= 0;
				case(index)
					0:begin
						is_command <= 1;
						data <= 8'h01;
					end
					1:begin
						data <= 8'h14;
					end
					
					5: begin
						is_command <= 0;
						data <= "P";
					end
					6: begin
						data <= "A";
					end
					7: begin
						data <= "S";
					end
					8: begin
						data <= "S";
					end
					9: begin
						data <= "W";
					end
					10: begin
						data <= "O";
					end
					11: begin
						data <= "R";
					end
					12: begin
						data <= "D";
					end
					13: begin
						is_command <= 1;
						data <= 8'hC0;
					end
					14: begin
						data <= 8'h14;
					end
					
					20: begin
						is_command <= 0;
						data <= "_";
					end

					23: begin
						ended <= 1;
					end
					
				endcase
			end else
				enable <= 0;
		end
		else if (~ended) begin
			//clk_cnt <= clk_cnt + 1;
		end
	
	
	
	end
	
	
	

	lcd screen(
		.clk(clk),
		.data(data),
		.awake(awake),
		.enable(enable),
		.is_command(is_command),
		
		.rs(rs),
		.e(e),
		.d(d),
		.ready(ready)
	);
	
	
	
	
endmodule
 
