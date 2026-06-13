module debouncer (
    input  wire clk,
    input  wire rst,
    input  wire boton,
    output wire pulso
);


    reg estado_prev;
	 reg estado_estable;
    
	 reg [21:0] count = 0;
	 always @(posedge clk)
	 begin
		if (boton)
		begin
			if (count > 2_500_000)
			begin
				estado_estable <= 1'b1;
				count <= 0;
			end
			else
				count <= count + 1'b1;
		end
		else
			estado_estable <= 0;
	 end
	 



    always @(posedge clk) begin
        if (rst)
            estado_prev <= 1'b0;
        else
            estado_prev <= estado_estable;
    end

    // Pulso de un ciclo al presionar
    assign pulso = estado_estable & ~estado_prev;

endmodule