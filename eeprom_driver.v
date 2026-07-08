/*

INSTRUCTION SET
0: Read password
1: Write password
2: Read sensitivity
3: Write sensitivity
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
	output wire done,

	input [15:0] in, // 4 digitos. Cada digito 4 bits
	output reg [15:0] password_out = 0, // 4 digits password (decimal)
	output reg [2:0] sensitivity_out = 0 // Sensitivity value (0 to 7)

	);
	
	
	// Dirección de memoria donde se guarda la contraseña (928 = 0x03A0)
	// Correspondiente a la página 29 de la memoria eeprom
	localparam PASSWORD_ADD = 16'h03A0; // Página 29
	localparam SENSITIVITY_ADD = 16'h0C40; // Página 28


	// Registros
	reg prev_enable = 0;
	reg prev_i2c_busy = 0;

	reg [15:0] address = 0; // Dirección de memoria donde se guarda contraseña o sensibilidad

	reg sensitivity_action = 0; // Flag to indicate if the action is related to sensitivity (1) or password (0)

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


	assign done = (state == IDLE) && ~(enable && ~prev_enable); // Done when in IDLE and enable signal is not active


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
					if (enable && ~prev_enable) begin
						case (instruction)
							2'd0: begin
								address <= PASSWORD_ADD;
								sensitivity_action <= 1'b0;
								state <= READ0; // load password
							end
							2'd1: begin
								address <= PASSWORD_ADD;
								sensitivity_action <= 1'b0;
								state <= WRITE; // Change password
							end
							2'd2: begin
								address <= SENSITIVITY_ADD;
								sensitivity_action <= 1'b1;
								state <= READ0; // Read sensitivity
							end
							2'd3: begin
								address <= SENSITIVITY_ADD;
								sensitivity_action <= 1'b1;
								state <= WRITE; // Write sensitivity
							end
						endcase
					end
				end



				READ0: begin
					if (~i2c_busy) begin
						// Preparar la lectura de la contraseña
						start <= 1'b1;
						restart_pos <= 3'd2;
						data_amount <= 3'd3; // Enviar 4 bytes (menos 1)
						if (sensitivity_action) begin
							read_amount <= 8'd0; // Leer 1 bytes (menos 1) (1 byte de sensibilidad)
						end else begin
							read_amount <= 8'd1; // Leer 2 bytes (menos 1) (contraseña de 4 dígitos)
						end
						data_rw <= 3'd3; // Iniciar lectura después del byte 3
						// A0, dirección de memoria High y Low, (restart), A1, (Leer)
						i2c_data <= {8'hA1, address[7:0], address[15:8], 8'hA0}; // Dirección de memoria + datos vacíos

						state <= READ1;
						current_read_byte <= 1;
					end
				end

				READ1: begin
					start <= 1'b0;
					if (data_ready && ~prev_data_ready) begin
						case (current_read_byte)
							1: begin
								if (sensitivity_action) begin
									sensitivity_out <= i2c_result[2:0]; // Sensitivity value
									state <= IDLE; // Only one byte to read for sensitivity
								end else begin
									password_out[15:8] <= i2c_result[7:0]; // Primer y segundo dígito
								end
							end
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
						if (sensitivity_action) begin
							data_amount <= 3'd3; // Escribir 4 bytes (menos 1)
							i2c_data <= {in[7:0], address[7:0], address[15:8], 8'hA0}; // Dirección de memoria + sensibilidad
						end else begin
							data_amount <= 3'd4; // Escribir 5 bytes (menos 1)
							i2c_data <= {in[7:0], in[15:8], address[7:0], address[15:8], 8'hA0}; // Dirección de memoria + contraseña
						end
						
						read_amount <= 8'd0; // No leer nada
						data_rw <= 3'd7; // Solo escribir, no leer

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
						if (sensitivity_action) begin
							sensitivity_out <= in[2:0]; // Actualizar la sensibilidad leída con la nueva sensibilidad
						end else begin
							password_out <= in; // Actualizar la contraseña leída con la nueva contraseña
						end
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