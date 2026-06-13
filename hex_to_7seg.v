module hex_to_7seg (
    input  wire [3:0] num,
    output reg  [6:0] seg
);

    always @(*) begin
        case (num)

            //      abcdefg
            4'h0: seg = 7'b1111110;
            4'h1: seg = 7'b0110000;
            4'h2: seg = 7'b1101101;
            4'h3: seg = 7'b1111001;
            4'h4: seg = 7'b0110011;
            4'h5: seg = 7'b1011011;
            4'h6: seg = 7'b1011111;
            4'h7: seg = 7'b1110000;
            4'h8: seg = 7'b1111111;
            4'h9: seg = 7'b1111011;
            4'hA: seg = 7'b1110111;
            4'hB: seg = 7'b0011111;
            4'hC: seg = 7'b1001110;
            4'hD: seg = 7'b0111101;
            4'hE: seg = 7'b1001111;
            4'hF: seg = 7'b1000111;

            default: seg = 7'b0000000;

        endcase
    end

endmodule


module driver_2seg (
    input wire clk,

    input wire [3:0] seg0,
    input wire [3:0] seg1,

    output wire [6:0] out,
    output wire [1:0] power
);

    reg [17:0] count = 0;
    reg switch = 0;

    wire [3:0] current;

    assign current = (switch) ? seg1 : seg0;
	
	// Cátodo común (Enciende con power = 0)
    assign power[0] = switch;
    assign power[1] = ~switch;


    hex_to_7seg hs (
        .num(current),
        .seg(out)
    );

    always @(posedge clk) begin
        if (count == 50_000) begin
            count <= 0;
            switch <= ~switch;
        end else begin
            count <= count + 1;
        end
    end

endmodule






module driver_4seg (
    input wire clk,

    input wire [3:0] seg0,
    input wire [3:0] seg1,
    input wire [3:0] seg2,
    input wire [3:0] seg3,

    output wire [6:0] out,
    output wire [3:0] power
);

    reg [17:0] count = 0;
    reg [1:0] switch = 0;

    wire [3:0] current;

    assign current =
        (switch == 2'd0) ? seg0 :
        (switch == 2'd1) ? seg1 :
        (switch == 2'd2) ? seg2 :
                           seg3;

    assign power[0] = ~(switch == 2'd0);
    assign power[1] = ~(switch == 2'd1);
    assign power[2] = ~(switch == 2'd2);
    assign power[3] = ~(switch == 2'd3);

    hex_to_7seg hs (
        .num(current),
        .seg(out)
    );

    always @(posedge clk) begin
        if (count == 50_000) begin
            count <= 0;
            switch <= switch + 2'b1;
        end else begin
            count <= count + 10'b1;
        end
    end

endmodule









