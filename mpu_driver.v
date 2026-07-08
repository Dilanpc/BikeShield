/*

Recibe una intrucción que se ejecuta con enable.
Entrega datos necesarios para que la acción se ejecute en el mpu a través de i2c

INTRUCCIONES
1: Init
2: Get Acceleration

*/



module mpu_driver (
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

	output reg [15:0] accelX,
	output reg [15:0] accelY,
	output reg [15:0] accelZ

	);


	localparam NO_APPLY = 3'd7; // Master entiende 7 como "no aplicar restart" o "no aplicar lectura"
	
	
	// ENABLE
	reg prev_enable = 0;
	reg prev_i2c_busy = 0;

	
	


	// STATES
	localparam IDLE = 0;
	localparam INIT = 1;
	localparam GET_ACCEL = 2;
	localparam READ = 3;
	localparam WAIT = 10;
	
	reg [7:0] state = IDLE;
	
	
	reg [7:0] current_read_byte = 0;

	// READY
	wire data_ready = i2c_result[8];
	reg prev_data_ready = 0;
	
	
	
	always @(posedge clk or posedge rst) begin
		if (rst) begin
			state <= IDLE;
			current_read_byte <= 0;
		end else begin

	
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
							GET_ACCEL: begin
								state <= GET_ACCEL;
							end
						
						endcase
					end
				
				end
			
				
				INIT: begin
					if (~i2c_busy) begin
					// Datos para el maestro
						start <= 1'b1; // Iniciar la comunicación
						restart_pos <= NO_APPLY; // No hay restart
						data_amount <= 2'd3 - 2'd1; // Cantidad de bytes a escribir (menos 1)
						read_amount <= 0; // No se leerá nada (El valor da igual)
						data_rw <= NO_APPLY;
						//           Confi, Reg confi, Dirección+W.   0x08 -> temp disable
						i2c_data <= {8'h08, 8'h6B, 8'hD0};

						state <= WAIT;
					end
				end


				GET_ACCEL: begin
					if (~i2c_busy) begin
						// Datos para el maestro
						start <= 1'b1; // Iniciar la comunicación
						restart_pos <= 3'd1; // Hacer restart después de escribir el registro a leer
						data_amount <= 2'd3 - 2'd1; // Cantidad de bytes a leer (menos 1)
						read_amount <= 8'd6 - 8'd1; // Cantidad de bytes a leer (menos 1)
						data_rw <= 2'd2; // Lectura
						//          Dirección+R, Reg acc, Dirección+W
						i2c_data <= {8'hD1, 8'h3B, 8'hD0};

						// Datos internos
						current_read_byte <= 0;
						state <= READ;
					end
				end
			


				WAIT: begin
					start <= 1'b0; // Solo se necesita un pulso de start
					if (~i2c_busy & prev_i2c_busy) begin // Esperar a que el maestro termine la operación
						state <= IDLE;
					end
				end

				READ: begin
					start <= 1'b0; // Solo se necesita un pulso de start
					if (data_ready & ~prev_data_ready) begin // Si el byte leído está listo
						case(current_read_byte)
							0: accelX[15:8] <= i2c_result[7:0];
							1: accelX[7:0]  <= i2c_result[7:0];
							2: accelY[15:8] <= i2c_result[7:0];
							3: accelY[7:0]  <= i2c_result[7:0];
							4: accelZ[15:8] <= i2c_result[7:0];
							5: begin
								accelZ[7:0]  <= i2c_result[7:0];
								state <= IDLE;
							end
						endcase
						
						current_read_byte <= current_read_byte + 1'b1;
					end
				end
			
			
			endcase
		end
	end
	
	
	
	
	
	
	
	
	
endmodule



