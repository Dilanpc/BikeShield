module debouncer (
    input  wire clk,
    input  wire rst,
    input  wire raw,
    output reg clean
);

	localparam HIGH = 1'b1;
	localparam LOW = 1'b0;
	reg setting = HIGH;


	reg [24:0] count = 0;
	always @(posedge clk) begin
		if (rst) begin
			count <= 0;
			clean <= raw;
			setting <= raw;
		end
		else if (raw) begin // Set clean to 1 if raw is 1 for 500 ms
			if (setting == LOW) begin // Reset count
				setting <= HIGH;
				count <= 0;
			end
			else begin
				if (count > 25_000_000) begin // 500 ms
					clean <= 1'b1;
					count <= 0;
				end
				else begin
					count <= count + 1'b1;
				end
			end
		end
		else begin // Set clean to 0 if raw is 0 for 500 ms
			if (setting == HIGH) begin // Reset count
				setting <= LOW;
				count <= 0;
			end
			else begin
				if (count > 25_000_000) begin // 500 ms
					clean <= 1'b0;
					count <= 0;
				end
				else begin
					count <= count + 1'b1;
				end
			end
		end
	end
	 


endmodule