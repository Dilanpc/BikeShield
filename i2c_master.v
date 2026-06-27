module i2c_master (
	input clk,
	inout sda,
	output reg scl = 1,
	
	input start,
	input stop_reading,
	
	input wire [2:0] restart_pos,  // Después de cuál byte se hace restart. 7 para no hacer restart
	
	input wire [2:0] data_amount, // 0 cuenta como 1 byte, 1 como 2 bytes...
	input wire [7:0] read_amount, // Cantidad de bytes a leer, 0 cuenta como 1 byte, 1 como 2 bytes...
	input wire [2:0] data_rw, // Después de cuál byte iniciar lectura. 7 para solo escribir, el primer byte siempre se escribe (dirección)
	input wire [63:0] data_in, // Hasta 8 bytes. Primer byte es dirección + R/W
	output reg [8:0] data_out = 0, // bit 8 indica que el byte está listo
	
	
	output reg ack = 0,
	output reg error = 0,
	output wire busy
	
	// output wire [3:0] leds // Debug

	);
	
	// Debug
	// assign leds[3] = ~scl;
	// assign leds[2] = ~sda;
	// assign leds[1] = ~start;
	// assign leds[0] = ~busy;
	
	
	reg prev_start = 0;
	
	reg prev_stop_reading = 0;
	reg stop_reading_flag = 0;
	
	
	reg [7:0] data_to_send = 8'b0;
	
	
	// Open Drain
	reg sda_low = 0;
	assign sda = sda_low ? 1'b0 : 1'bz;
	
	
	
	// scl parametrers
	reg scl_active = 0;
	reg prev_scl = 1;
	// reg [26:0] scl_cnt = 0; // Debug
	reg [7:0] scl_cnt = 0;
	// localparam MAX_SCL_CNT = 10_000_000; // Debug
	localparam MAX_SCL_CNT = 250;
	
	
	// bytes
	reg [2:0] current_byte = 1'b0; // Para datos enviados
	reg [2:0] bit_index = 3'b111;
	reg [7:0] current_read_byte = 1'b0; // Para datos recibidos

	// Restart parametrers
	reg restart_done = 0;

	
	
	
	// State machine parametrers
	localparam IDLE = 1'b0;
	localparam START = 1'b1;
	localparam SEND_BYTE = 7'd2;
	localparam GET_ACK0 = 7'd3;
	localparam GET_ACK1 = 7'd4;
	localparam NEXT_BYTE0 = 7'd5;
	localparam NEXT_BYTE1 = 7'd6;
	localparam READ_BYTE = 7'd7;
	localparam SEND_ACK0 = 7'd8;
	localparam SEND_ACK1 = 7'd9;
	localparam STOP0 = 7'd10;
	localparam STOP1 = 7'd11;
	localparam RESTART = 7'd12;
	
	
	reg [7:0] state = IDLE;
	
	assign busy = (state != IDLE);
	
	
	always @(posedge clk) begin

	
	
		// SCL
		prev_scl <= scl;
		if (scl_active) begin
			if (scl_cnt == MAX_SCL_CNT) begin
				scl_cnt <= 0;
				scl <= ~scl;
			end
			else begin
				scl_cnt <= scl_cnt + 1'b1;
			end
		end
		else begin
			scl <= 1;
		end
		
		// start
		prev_start <= start;
		
		
		// Reading stop
		prev_stop_reading <= stop_reading;
		if (stop_reading & ~prev_stop_reading) begin
			stop_reading_flag <= 1;
		end
		
		
		case(state)
			IDLE: begin
				if (start & ~prev_start) begin
					state <= START;
					error <= 0;
					current_byte <= 1'b0;
					current_read_byte <= 1'b0;
					restart_done <= 0;
					stop_reading_flag <= 0;
				end
			end
			
			START: begin // Eperar medio ciclo para asegurar que el dispositivo detecte el start
				if (scl_cnt == MAX_SCL_CNT) begin
					scl_active <= 1'b1;
					scl_cnt <= 0;
					
					sda_low <= 1'b1;
					

					ack <= 0;

					bit_index <= 3'b111;
					
					if (restart_done) begin // Continuar con secuencia luego del restart
						state <= NEXT_BYTE0;
					end
					else begin
						state <= SEND_BYTE;
						data_to_send <= data_in[7:0]; // Dirección + R/W
					end
					

				end
				else begin
					scl_cnt <= scl_cnt + 1'b1;
					sda_low <= 0;
				end
			end
			

			
			
			SEND_BYTE: begin
				if (~scl & prev_scl) begin // Esperar negedge scl
					ack <= 0;
					sda_low <= ~data_to_send[bit_index];
					bit_index <= bit_index - 1'b1;
					if (bit_index == 1'b0) begin
						bit_index <= 3'd7;
						state <= GET_ACK0;
					end
				end
			end
			
			
			
			GET_ACK0: begin // Soltar línea
				if (~scl & prev_scl) begin // Esperar negedge scl
					sda_low <= 0; // Soltar sda
					state <= GET_ACK1;
				end
			end
			
			GET_ACK1: begin
				if (scl & ~prev_scl) begin // Esperar posedge scl
					ack <= ~(sda);
					if (sda) begin // NACK
						error <= 1;
						state <= STOP0;
					end
					else begin
						state <= NEXT_BYTE0;
					end
				end
			end
			

			NEXT_BYTE0: begin
				if ((current_byte == restart_pos) && (~restart_done)) begin // Hacer restart
					state <= RESTART;
				end else
				begin
					if (current_byte == data_rw) begin // Si se llega al punto de lectura
						state <= READ_BYTE;
						sda_low <= 0; //Solar sda
					end
					else begin
						state <= NEXT_BYTE1;
					end
					current_byte <= current_byte + 1'b1;
					
				end
			end
			
			NEXT_BYTE1: begin  // Cargar siguiente byte
				if ((current_byte > data_amount) || // Ya se enviaron todos
					(current_byte == 0)) begin // Si se reinicia por overflow
					state <= STOP0;
				end
				else
				begin // Pasar al siguiente byte
					// Escribir
					data_to_send <= data_in[current_byte*8 +: 8];
					state <= SEND_BYTE;
				end

			end
			
			
			
			READ_BYTE: begin
				if (scl & ~prev_scl) begin // Esperar posedge scl
					if (bit_index == 1'b0) begin // Pasar a ACK
						data_out[0] <= sda;
						bit_index <= 3'd7;
						current_read_byte <= current_read_byte + 1'b1;
						state <= SEND_ACK0;
						data_out[8] <= 1; // Indicar que el byte está listo
						
					end else begin
						data_out[8] <= 0; // Indicar que el byte no está listo
						ack <= 0;
						data_out[bit_index] <= sda;
						bit_index <= bit_index - 1'b1;
					end
				end
			
			end
			
			
			
			SEND_ACK0: begin // Preparar ACK
				if (~scl & prev_scl) begin // Esperar negedge scl
					if (stop_reading_flag ||
						current_read_byte > read_amount ||
						current_read_byte == 0) begin // Detener lectura: enviar NACK
						ack <= 0; // Enviar NACK
						sda_low <= 0; // Soltar sda
					end else begin
						ack <= 1; // Enviar ACK
						sda_low <= 1; // Bajar sda
					end
					state <= SEND_ACK1;
				end
			end


			SEND_ACK1: begin
				if (~scl & prev_scl) begin // Esperar negedge scl
					sda_low <= 0; // Soltar sda
					if (ack) begin // Continuar leyendo
						state <= READ_BYTE;
					end else
					begin
						state <= STOP0;
					end

				end
			end


			STOP0: begin // Preparar STOP
				sda_low <= 1; // Bajar sda
				if (scl & ~prev_scl) begin // Esperar posedge scl
					state <= STOP1;
					scl_active <= 0; // Scl se queda en 1
					scl_cnt <= 0;
				end
			end

			STOP1: begin // Eperar medio ciclo para asegurar que el dispositivo detecte el STOP
				if (scl_cnt == MAX_SCL_CNT) begin
					sda_low <= 0; // Soltar sda
					scl_cnt <= 0;
					ack <= 0;
					state <= IDLE;
				end else
				begin
					scl_cnt <= scl_cnt + 1'b1;
				end
			end


			RESTART: begin
				sda_low <= 0; // Soltar sda
				if (scl & ~prev_scl) begin // Esperar posedge scl
					state <= START;
					scl_active <= 0; // Scl se queda en 1
					scl_cnt <= 0;
					restart_done <= 1;
				end
			end

			
		
		
		endcase
	
	end
	
	
	
	
	
	
	
	
	
	
	
endmodule