/*

Recibe una intrucción que se ejecuta con enable.
Entrega datos necesarios para que la acción se ejecute en el mpu a través de i2c

INTRUCCIONES
1: Init
2: Get Acceleration

*/

module mpu_driver (
	input clk,
	
	// i2c master interface
	output reg start,
	output reg stop_reading,
	ouput reg restart_pos,
	output reg data_amount,
	output reg data_rw,
	output reg [63:0] i2c_data,
	input reg [8:0] i2c_result,
	input wire i2c_busy,

	// User
	input instruction,
	input enable,
	output reg done = 1

	output reg [15:0] accelX,
	output reg [15:0] accelY,
	output reg [15:0] accelZ

	);
	
	
	reg prev_enable = 0;
	reg prev_i2c_busy = 0;

	
	localparam NO_APPLY = 3'd7; // Master entiende 7 como "no aplicar restart" o "no aplicar lectura"
	
	localparam IDLE = 0;
	localparam INIT = 1;
	localparam GET_ACCEL = 2;
	
	localparam WAIT = 10;
	
	reg [7:0] state = IDLE;
	
	
	reg [7:0] current_read_byte = 0;

	wire data_ready = i2c_result[8];
	reg prev_data_ready = 0;
	
	
	
	always @(posedge clk) begin
		

	
		prev_enable <= enable;
		prev_i2c_busy <= i2c_busy;
		prev_data_ready <= data_ready;
	
	
		case (state)
			IDLE: begin
			
				done <= 1'b1;
				if (enable & ~prev_enable) begin
					done <= 0;
					case(instruction)
						INIT: begin
							state <= INIT;
						end
					
					endcase
				end
			
			end
		
			
			INIT: begin
				// Datos para el maestro
				start <= 1'b1; // Iniciar la comunicación
				stop_reading <= 1'b0; // No se usará en INIT
				restart_pos <= NO_APPLY; // No hay restart
				data_amount <= 2'd3 - 2'd1; // Cantidad de bytes a escribir (menos 1)
				data_rw <= NO_APPLY;
				//           Confi, Reg confi, Dirección+W
				i2c_data <= {8'h00, 8'h3B, 8'b11010000};

				// Datos internos
				current_read_byte <= 0;
				amount_to_read <= 0;
				current_write_byte <= 0;
				state <= WAIT;
			end


			GET_ACCEL: begin
				// Datos para el maestro
				start <= 1'b1; // Iniciar la comunicación
				stop_reading <= 1'b0; // Se usará 
				restart_pos <= 2'b2 - 2'b1; // Hacer restart después de escribir el registro a leer
				data_amount <= 2'd6 - 2'd1; // Cantidad de bytes a leer (menos 1)
				data_rw <= 2'b3 - 2'b1; // Lectura
				//            Dirección+R, Reg acc, Dirección+W
				i2c_data <= { 8'b11010001, 8'h3B, 8'b11010000};

				// Datos internos
				current_read_byte <= 0;
				state <= READ;
			end
		


			WAIT: begin
				start <= 1'b0; // Solo se necesita un pulso de start
				if (~i2c_busy & prev_i2c_busy) begin // Esperar a que el maestro termine la operación
					state <= IDLE;
				end
			end

			READ: begin
				if (data_ready & ~prev_data_ready) begin // Si el byte leído está listo
					case(current_read_byte)
						0: accelX[15:8] <= i2c_result[7:0];
						1: accelX[7:0] <= i2c_result[7:0];
						2: accelY[15:8] <= i2c_result[7:0];
						3: accelY[7:0] <= i2c_result[7:0];
						4: begin
							stop_reading <= 1'b1; // Detener lectura después de leer el último byte
							accelZ[15:8] <= i2c_result[7:0];
						end
						5: accelZ[7:0] <= i2c_result[7:0];
						6: begin
							done <= 1'b1; // Indicar que se terminó de leer
							stop_reading <= 1'b0; // Resetear la señal de stop_reading
							state <= IDLE;
						end
					endcase
					
					current_read_byte <= current_read_byte + 1;
				end
			end
		
		
		endcase
	end
	
	
	
	
	
	
	
	
	
endmodule