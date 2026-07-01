module debouncer (
    input  wire clk,
    input  wire rst,
    input  wire raw,
    output reg clean
);


	reg [21:0] count = 0;
	always @(posedge clk) begin
		if (raw) begin
			if (count > 2_500_000) begin // 50 ms
				clean <= 1'b1;
				count <= 0;
			end
			else
				count <= count + 1'b1;
		end
		else begin
			count <= 0;
			clean <= 0;
		end
	end
	 


endmodule