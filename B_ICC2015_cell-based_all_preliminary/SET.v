module SET (clk ,rst, en,central,radius, mode, busy, valid, candidate);
input clk;
input rst;
input en;
input [23:0] central;
input [11:0] radius;
input [1:0] mode;
output busy;
output valid;
output [7:0] candidate;
//====================================================================
reg busy;
reg valid;
reg [7:0] candidate;
/* my design */

reg [1:0] mode_r;
reg [3:0] xa, ya, ra, xb, yb, rb, xc, yc, rc;

reg state, nxt_state;
localparam Idle = 1'b0;
localparam Run = 1'b1;

reg [5:0] cnt;
wire [3:0] x = cnt[5:3] + 4'd1;
wire [3:0] y = cnt[2:0] + 4'd1;
wire [8:0] xy2a = (x - xa) * (x - xa) + (y - ya) * (y - ya);
wire [8:0] xy2b = (x - xb) * (x - xb) + (y - yb) * (y - yb);
wire [8:0] xy2c = (x - xc) * (x - xc) + (y - yc) * (y - yc);
wire in_a = (xy2a <= ra * ra) ? 1 : 0;
wire in_b = (xy2b <= rb * rb) ? 1 : 0;
wire in_c = (xy2c <= rc * rc) ? 1 : 0;

wire is [0:3];
assign is[0] = in_a;
assign is[1] = in_a & in_b;
assign is[2] = in_a ^ in_b;
assign is[3] = (in_a + in_b + in_c == 2'd2);

always @(*) begin // next state logic
	nxt_state <= state;
	case (state)
		Idle :
			if (en) nxt_state <= Run;
		default :
			if (cnt == 6'd63) nxt_state <= Idle;
	endcase 
end

always @(posedge clk/* or posedge rst*/) begin // FSM
	if (rst) state <= Idle;
	else state <= nxt_state;
end

always @(posedge clk) begin
	case (state)
		Idle : begin
			valid <= 0;
			busy <= 0;
			cnt <= 6'd0;
			candidate <= 8'd0;
			if (en) begin
				busy <= 1;
				xa <= central[23:20];
				ya <= central[19:16];
				ra <= radius[11:8];
				xb <= central[15:12];
				yb <= central[11:8];
				rb <= radius[7:4];
				xc <= central[7:4];
				yc <= central[3:0];
				rc <= radius[3:0];
				mode_r <= mode;
			end
		end
		Run : begin
			cnt <= cnt + 6'd1;
			if (is[mode_r]) candidate <= candidate + 8'd1;
			if (cnt == 6'd63) begin
				valid <= 1;
				busy <= 0;
			end
		end
	endcase
end

endmodule
