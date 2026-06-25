module eeprom24lc64(

    input wire clk,      // 50 MHz
	 input tick,    //debug
    input wire rst,
	 
	 input wire read,
	 input wire start,
	 	 
	 input wire [15:0] mem_addr,
	 input wire [7:0] data_byte,

    inout wire sda,
    output reg scl,
	 
	 output reg [15:0] out,
	 output reg done,
	 output reg error,
	 output reg led

);

    //--------------------------------------------------
    // Divisor de reloj
    //--------------------------------------------------

    reg [22:0] div_cnt;
//    reg tick;

//    always @(posedge clk or posedge rst)
//    begin
//        if(rst)
//        begin
//            div_cnt <= 0;
//            tick <= 0;
//        end
//        else
//        begin
//            //if(div_cnt == 124)
//				if (div_cnt == 5_000_000) //debug
//            begin
//                div_cnt <= 0;
//                tick <= 1;
//            end
//            else
//            begin
//                div_cnt <= div_cnt + 22'b1;
//                tick <= 0;
//            end
//        end
//    end

    //--------------------------------------------------
    // Fases I²C
    //--------------------------------------------------

    reg [1:0] phase;

    always @(posedge clk or posedge rst)
    begin
        if(rst)
            phase <= 0;
        else if(tick)
            phase <= phase + 2'b1;
    end

    //--------------------------------------------------
    // SCL
    //--------------------------------------------------
	
	 reg scl_enable = 0;
	 always @(*)
	 begin
 
	 	if(!scl_enable)
	 	begin
         scl = 1;
	 	end
	 	else
	 	begin
	 		case(phase)
             2'd0: scl = 0;
             2'd1: scl = 1;
             2'd2: scl = 1;
             2'd3: scl = 0;
         endcase
     end

end

    //--------------------------------------------------
    // SDA Open Drain
    //--------------------------------------------------

	 
	 reg sda_low;
	 assign sda = sda_low ? 1'b0 : 1'bz;

	 
	 
	 
	 //--------------------------------------------------
	 // Estados
	 //--------------------------------------------------
 
	 localparam IDLE      = 0;
	 localparam START     = 1;
	 localparam SEND_BYTE = 2;
	 localparam GET_ACK   = 3;
	 localparam LOAD_BYTE = 4;
	 localparam READ_BYTE = 5;
	 localparam SEND_ACK  = 6;
	 localparam SEND_NACK = 7;
	 localparam STOP      = 8;
	 localparam DONE      = 9;
 
	 reg [3:0] state = 0;
	 reg start_done = 0;
	 
	 reg reading = 0;
 
	 //--------------------------------------------------
	 // Registros I2C
	 //--------------------------------------------------
	
	 reg rd_byte;
	 reg [7:0] tx_byte;
	 reg [3:0] bit_cnt;
	 reg [16:0] done_cnt;
	 reg ack;
	 


	 reg [1:0] byte_index = 0;
	 
	 
	always @(posedge clk or posedge rst)
	begin
	 
		if(rst)
		begin
			state <= IDLE;
			scl_enable <= 0;
			start_done <= 0;
			reading <= 0;
			tx_byte <= 8'hA0;    // dirección EEPROM escritura
			rd_byte <= 0;
			bit_cnt <= 4'd7;
			byte_index <= 0;
			ack <= 0;
			sda_low <= 0;
			done <= 1;
			error <= 0;
			led <= 1;
		end
		else if(start && (state == IDLE))
		begin
			state <= START;
			led <= 0;
		end
		else if(tick)
		begin
	 
			case(state)
	 
				IDLE:
				begin
					scl_enable <= 0; 
				end
	 
				START:
				begin
					scl_enable <= 1;
					out <= 0;
					done <= 0;
					if(phase == 1 && !start_done)
					begin
						sda_low <= 1;
						start_done <= 1;
					end
					else if(phase == 3 && start_done)
					begin
						start_done <= 0;
						state <= SEND_BYTE;
					end
				end
					 
					 
				SEND_BYTE:
				begin
					//--------------------------------------------------
					// Fase 0: colocar dato en SDA
					//--------------------------------------------------

					if(phase == 0)
					begin
						if(tx_byte[bit_cnt])
							sda_low = 0;      // enviar 1 -> liberar SDA
						else
							sda_low = 1;      // enviar 0 -> tirar SDA a GND
					end
		
					//--------------------------------------------------
					// Fase 3: avanzar al siguiente bit
					//--------------------------------------------------

					if(phase == 3)
					begin

						if(bit_cnt == 0)
						begin
							sda_low <= 0;      // liberar SDA para ACK
							state <= GET_ACK;
						end
						else
						begin
							bit_cnt <= bit_cnt - 4'b1;
						end
					end
				end	
					
					
					
				GET_ACK:
				begin
					//--------------------------------------------------
					// Leer ACK cuando SCL está alto
					//--------------------------------------------------
					 
					if(phase == 2)
					begin
						ack <= (sda == 1'b0);
					end
					
					else if (phase == 3)
					begin
						if (!ack)
						begin
							state <= STOP;
							error <= 1;
						end
						else begin
							if(byte_index == 3)
								state <= STOP;
							if (reading)
							begin
								state <= READ_BYTE;
								bit_cnt <= 7;
							end
							else
							begin
								if (read && (byte_index == 2)) // Justo antes de enviar dato a guardar, restart para read
								begin
									state <= START;
									tx_byte <= 8'hA1;
									byte_index <= 0;
									reading <= 1;
								end
								else begin
									case(byte_index)
										  0: tx_byte <= mem_addr[15:8];
										  1: tx_byte <= mem_addr[7:0];
										  2: tx_byte <= data_byte;
										  3: tx_byte <= 8'hA0;
									endcase

									bit_cnt <= 7;
									state <= SEND_BYTE;
									byte_index <= byte_index + 2'b1;
								end
							end
						end
					end
				end
					
					
					
				READ_BYTE:
				begin
					if (phase == 2)
					begin
						out[bit_cnt + (rd_byte ? 0 : 4'b1000)] <= sda; // Leer
						
					end
					
					
					if(phase == 3)
					begin
						if(bit_cnt == 0)
						begin
							if (rd_byte)
							begin
								state <= SEND_NACK;
							end
							else begin
								state <= SEND_ACK;
							end
						end
						else
						begin
							bit_cnt <= bit_cnt - 4'b1;
						end
					end
				end
					
				
				
				SEND_ACK:
				begin
					if (phase == 0)
					begin
						sda_low <= 1;
					end
					
					if (phase == 3)
					begin
						state <= READ_BYTE;
						sda_low <= 0;
						bit_cnt <= 7;
						rd_byte <= 1;
					end
				end
				
				
				
				
				SEND_NACK:
				begin
					if (phase == 0)
					begin
						sda_low <= 0; // Solo para asegurar
					end
					if (phase == 3)
					begin
						state <= STOP;
						bit_cnt <= 7;
						rd_byte <= 0;
					end
				
				
				end
				
				
				
					
					
					
				STOP:
				begin
					tx_byte <= 0;
					if(phase == 0)
					begin
						sda_low <= 1;      // SDA en 0
					end

					else if(phase == 1)
					begin
						sda_low <= 0;      // SDA liberada -> STOP
						state <= DONE;
					end
				end

					
					
				DONE:
				begin
					//if (done_cnt == 9'd500) // Esperar memoria
					if (done_cnt == 17'd4) //debug
					begin
						state <= IDLE;
						done <= 1;
						scl_enable <= 0;
						start_done <= 0;
						reading <= 0;
						tx_byte <= 8'hA0;    // dirección EEPROM escritura
						rd_byte <= 0;
						bit_cnt <= 4'd7;
						byte_index <= 0;
						ack <= 0;
						sda_low <= 0;
						done_cnt <= 0;
					end
					else
					begin
						done_cnt <= done_cnt + 17'b1;
					end
				end
										
	 
			endcase
	 
		end
	 
	end
	 
	 
	 
	 
	
	 
	 

endmodule