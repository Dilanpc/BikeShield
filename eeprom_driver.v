/*

INSTRUCTION SET
1: Read password
2: Write password
*/


module eeprom_driver (
	input clk,
	input rst,

	// i2c master interface
	output reg start,
	output reg [2:0] restart_pos,
	output reg [2:0] data_amount,
	output reg [7:0] read_amount,
	output reg [2:0] data_rw,
	output reg [63:0] i2c_data,

	input wire [8:0] i2c_result,
	input wire i2c_busy,

	// User
	input [1:0] instruction,
	input enable,
	output reg done = 1,

	input [15:0] password_in, // 4 digitos. Cada digito 4 bits
	output reg [15:0] password_out = 0 // 4 digits password (decimal)

	// Debug
	// output wire [3:0] leds

	);
	// Debug
	// assign leds = {~i2c_busy, ~state};

	// Dirección de memoria donde se guarda la contraseña (928 = 0x03A0)
	// Correspondiente a la página 29 de la memoria eeprom
	localparam PASSWORD_ADD = 16'h03A0; 


	// Registros
	reg prev_enable = 0;
	reg prev_i2c_busy = 0;
	// Data
	wire data_ready = i2c_result[8];
	reg prev_data_ready = 0;
	reg current_read_byte = 0;
	// WAIT
	localparam MAX_WAIT_COUNTER = 19'd300_000; // 6 ms de espera para que la memoria eeprom escriba los datos
	reg [18:0] wait_counter = 0;


	// STATES
	localparam IDLE  = 0;
	localparam READ0 = 1;
	localparam READ1 = 2;
	localparam WRITE = 3;
	localparam WAIT0 = 4;
	localparam WAIT1 = 5;

	reg [2:0] state = IDLE;




	always @(posedge clk or posedge rst) begin
		
		if (rst) begin
			state <= IDLE;
			start <= 1'b0;
			restart_pos <= 3'd7;
		end else begin
			prev_enable <= enable;
			prev_i2c_busy <= i2c_busy;
			prev_data_ready <= data_ready;


			case (state)
				IDLE: begin
					done <= 1'b1;
					if (enable && ~prev_enable) begin
						done <= 1'b0;
						case (instruction)
							2'd1: state <= READ0; // load password
							2'd2: state <= WRITE; // Change password
						endcase
					end
				end



				READ0: begin
					if (~i2c_busy) begin
						// Preparar la lectura de la contraseña
						start <= 1'b1;
						restart_pos <= 3'd2;
						data_amount <= 3'd3; // Enviar 4 bytes (menos 1)
						read_amount <= 8'd1; // Leer 2 bytes (menos 1) (contraseña de 4 dígitos)
						data_rw <= 3'd3; // Iniciar lectura después del byte 3
						// A0, dirección de memoria High y Low, (restart), A1, (Leer)
						i2c_data <= {8'hA1, PASSWORD_ADD[7:0], PASSWORD_ADD[15:8], 8'hA0}; // Dirección de memoria + datos vacíos

						state <= READ1;
						current_read_byte <= 1;
					end
				end

				READ1: begin
					start <= 1'b0;
					if (data_ready && ~prev_data_ready) begin
						case (current_read_byte)
							1: password_out[15:8] <= i2c_result[7:0]; // Primer y segundo dígito
							0: begin 
								password_out[7:0] <= i2c_result[7:0]; // Tercer y cuarto dígito
								state <= IDLE;
							end
						endcase
						current_read_byte <= current_read_byte - 1'b1;
					end

				end



				WRITE: begin
					if (~i2c_busy) begin
						// Preparar la escritura de la contraseña
						start <= 1'b1;
						restart_pos <= 3'd7; // No hacer restart
						data_amount <= 3'd4; // Escribir 5 bytes (menos 1)
						read_amount <= 8'd0; // No leer nada
						data_rw <= 3'd7; // Solo escribir, no leer
						i2c_data <= {password_in[7:0], password_in[15:8], PASSWORD_ADD[7:0], PASSWORD_ADD[15:8], 8'hA0}; // Dirección de memoria + contraseña

						state <= WAIT0;
					end
				end


				WAIT0: begin
					start <= 1'b0;
					if (~i2c_busy && prev_i2c_busy) begin // Esperar a que el maestro termine la operación
						state <= WAIT1;
					end;
				end

				WAIT1: begin
					if (wait_counter == MAX_WAIT_COUNTER) begin // Esperar a que la memoria eeprom escriba los datos
						password_out <= password_in; // Actualizar la contraseña leída con la nueva contraseña
						state <= IDLE;
						wait_counter <= 0;
					end
					else begin
						wait_counter <= wait_counter + 1'b1;
					end

				end



			endcase
		end


	end




endmodule