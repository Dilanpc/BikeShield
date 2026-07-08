module lcd (
	input clk,
	input wire [7:0] data,
	input awake,
	input enable,
	input is_command,
	
	output wire rs_out,
	output wire e_out,
	output wire [3:0] d_out,
	output wire ready,

	// Debug
	output wire [3:0] current_state
);
	
	assign current_state = {awake, enable, ready, e_out};
	// assign current_state = state;

	reg prev_awake = 0;
	reg prev_enable = 0;

	
	reg rs = 0;
	reg e = 0;
	reg [3:0] d = 0;

    // Salidas alta impedancia
	assign rs_out = awake ? rs : 1'bz;
	assign e_out = awake ? e : 1'bz;
	assign d_out = awake ? d : 4'bzzzz;

	

	
	
	// Tiempos de espera
	localparam CYCLES_INIT_WAIT_0 = 20'd1_000_000; 
	localparam CYCLES_INIT_WAIT_1 = 20'd250_000; 
	localparam CYCLES_INIT_WAIT_2 = 20'd10_000; 
	localparam MICRO_1 = 20'd50;
	localparam MICRO_40 = 20'd2_000;
	localparam MILLI_2 = 20'd100_000;
	
	// DEBUG
//	localparam CYCLES_INIT_WAIT_0 = 5; 
//	localparam CYCLES_INIT_WAIT_1 = 5; 
//	localparam CYCLES_INIT_WAIT_2 = 5; 
//	localparam MICRO_1 = 1;
//	localparam MICRO_40 = 3;
//	localparam MILLI_2 = 5;
	////////


	localparam IDLE       = 4'd0;
	localparam INIT       = 4'd1;
	localparam INIT_WAIT  = 4'd2;
	localparam SHORT_WAIT = 4'd3;
	localparam LONG_WAIT  = 4'd4;
	localparam SEND_HIGH  = 4'd5;
	localparam SEND_LOW   = 4'd6;
	
	reg [3:0] state = IDLE;
	reg [3:0] prev_state = IDLE;


	reg [7:0] data_to_send = 0;
	reg [19:0] cnt = 0;
	wire [19:0] init_cnt;
	reg [3:0] init_state = 0;
	reg [5:0] e_cnt = 0;
	
	//             Esperando       Que no se acabe de iniciar   Que no se este inicializando
	assign ready = (state == IDLE) & awake & prev_awake &     (init_state == 4'd0);

	assign init_cnt = (init_state == 4'd1) ? CYCLES_INIT_WAIT_0 :
							(init_state == 4'd2) ? CYCLES_INIT_WAIT_1 :
							(init_state == 4'd3) ? CYCLES_INIT_WAIT_2 : CYCLES_INIT_WAIT_2;
	
	
	//// FSM
	always @(posedge clk or negedge awake) begin
		if (~awake) begin
			state <= IDLE;
			prev_state <= IDLE;
			prev_awake <= 0;
			init_state <= 0;
			cnt <= 0;
			e_cnt <= 0;
			rs <= 0;
			e <= 0;
			d <= 0;
		end else begin
			prev_enable <= enable;
			prev_awake <= awake;
			case(state)
				IDLE:
				begin
					
					if ((awake && ~prev_awake) || (init_state != 4'd0))
					begin
						state <= INIT;
						prev_state <= IDLE;

					end
					else if (enable & ~prev_enable)
					begin
						data_to_send <= data;
						rs <= ~is_command;
						state <= SEND_HIGH;
						prev_state <= IDLE;
						prev_enable <= 1;
					end
				end
				
				
				
				INIT: begin
					if (init_state == 4'd0)
					begin
						rs <= 0; // Para enviar comandos
						init_state <= 4'd1;
						state <= INIT_WAIT;
						cnt <= 0;

					end else if (init_state == 4'd1 || init_state == 4'd2 || init_state == 4'd3) // Confi modo 4 bits
					begin
						d <= 4'b0011;
					
						if (cnt == MICRO_1) // 1 us esperar que d y rs sea estable
						begin
							cnt <= 0;
							e <= 1;
							init_state <= init_state + 4'b1;
							state <= INIT_WAIT;
						end else begin
							cnt <= cnt + 20'b1;
						end
					
					end
					else if (init_state == 4'd4)
					begin
						d <= 4'b0010; // Ya queda modo 4 bits
						if (cnt == MICRO_1) // 1 us esperar que d sea estable
						begin
							cnt <= 0;
							e <= 1;
							init_state <= init_state + 4'b1;
							state <= LONG_WAIT;
						end else begin
							cnt <= cnt + 20'b1;
						end
					end
				
					else if (init_state == 5) // Function set
					begin
						data_to_send <= 8'h28;
						state <= SEND_HIGH;
						init_state <= init_state + 4'b1;
					end
				
					else if (init_state == 6) // Display ON
					begin
						data_to_send <= 8'h0C;
						state <= SEND_HIGH;
						init_state <= init_state + 4'b1;
					end
				
					else if (init_state == 7) // Entry mode set
					begin
						data_to_send <= 8'h06;
						state <= SEND_HIGH;
						init_state <= init_state + 4'b1;
					end
				
					else if (init_state == 8) // Clear
					begin
						data_to_send <= 8'h01;
						state <= SEND_HIGH;
						init_state <= init_state + 4'b1;
					end
				
				
					else
					begin
						init_state <= 0;
						state <= IDLE;
					end
				end
				
				
				
				
				
				
				INIT_WAIT: // 20ms
				begin
					if (e)
					begin
						if (e_cnt == MICRO_1) // 1us para enable en HIGH
						begin
							e_cnt <= 0;
							e <= 0;
						end else
						begin
							e_cnt <= e_cnt + 6'b1;
						end
					end
					else if (cnt == init_cnt)
					begin
						cnt <= 0;
						state <= INIT;
					end
					else
						cnt <= cnt + 20'b1;
				end
				
				
				SHORT_WAIT: // 40 us
				begin
					if (e)
					begin
						if (e_cnt == MICRO_1) // 1us para enable en HIGH
						begin
							e_cnt <= 0;
							e <= 0;
						end else
						begin
							e_cnt <= e_cnt + 6'b1;
						end
					end else if (cnt == MICRO_40) // 40 us esperar que se muestre el dato
					begin
						cnt <= 0;
						if (prev_state == SEND_HIGH)
						begin
							state <= SEND_LOW;
						end
						else if (prev_state == SEND_LOW)
						begin
							state <= IDLE;
							prev_state <= IDLE;
						end

					end
					else begin
						cnt <= cnt + 1'b1;
					end
				
				
				end
				
				
				
				
				LONG_WAIT: // 2 ms
				begin
					if (e)
					begin
						if (e_cnt == MICRO_1) // 1us para enable en HIGH
						begin
							e_cnt <= 0;
							e <= 0;
						end else
						begin
							e_cnt <= e_cnt + 6'b1;
						end
					end
					
					if (cnt == MILLI_2) // 2 ms
					begin
						cnt <= 0;

						if (prev_state == SEND_HIGH)
						begin
							state <= SEND_LOW;
						end
						else // Prev state SEND_LOW o INIT
						begin
							state <= IDLE;
							prev_state <= IDLE;
						end

					end
					else
						cnt <= cnt + 20'b1;
				
				end
				
				SEND_HIGH: begin
					d <= data_to_send[7:4];

					
					if (cnt == MICRO_1) // 1 us esperar que d sea estable
					begin
						cnt <= 0;
						e <= 1;
						prev_state <= SEND_HIGH;
						state <= SHORT_WAIT;
					end else begin
						cnt <= cnt + 20'b1;
					end
				
				end
				
				
				
				
				SEND_LOW: begin
					d <= data_to_send[3:0];
					
					if (cnt == MICRO_1) // 1 us esperar que d sea estable
					begin
						cnt <= 0;
						e <= 1;
						prev_state <= SEND_LOW;
						if (data_to_send == 8'h01 ||
							data_to_send == 8'h02 ||
							data_to_send == 8'h03
							)
						begin
							state <= LONG_WAIT;
						end
						else begin
							state <= SHORT_WAIT;
						end
						
					end else begin
						cnt <= cnt + 20'b1;
					end
				
				end
				
				

			endcase
		end
	end
	





endmodule
