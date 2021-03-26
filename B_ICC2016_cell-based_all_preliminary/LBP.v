
`timescale 1ns/10ps
module LBP ( clk, reset, gray_addr, gray_req, gray_ready, gray_data, lbp_addr, lbp_valid, lbp_data, finish);
input			clk;
input			reset;
output [13:0]	gray_addr;
output			gray_req;
input			gray_ready;
input [7:0]		gray_data;
output [13:0]	lbp_addr;
output			lbp_valid;
output [7:0]	lbp_data;
output			finish;
//====================================================================
reg [13:0]		gray_addr;
reg				gray_req;
reg	[13:0]		lbp_addr;
reg				lbp_valid;
reg [7:0]		lbp_data;
reg				finish;
/* my design */

reg [2:0] state, nxt_state;
parameter Idle =	3'd0;
parameter Readur =	3'd1;
parameter Readr =	3'd2;
parameter Readdr =	3'd3;
parameter Write =	3'd4;
parameter Finish =	3'd5;

reg [7:0] data [0:8];
reg [13:0] pos;
wire [7:0] pos_row	= pos[13:7];
wire [7:0] pos_col	= pos[6:0];
wire pos_is_firstc = (pos_col == 7'h0);
wire pos_is_lastc = (pos_col == 7'h7F);
wire pos_is_folc = (pos_is_firstc || pos_is_lastc);
wire [13:0] pos_rur	= pos - {7'h0, 7'h7E};
wire [13:0] pos_r	= pos + {7'h0, 7'h1};
wire [13:0] pos_dr	= pos + {7'h1, 7'h1};

always @(*) begin // next state logic
	nxt_state <= state;
	case (state)
		Idle :
			if (gray_ready == 1'b1) nxt_state <= Readur;
		Readur : nxt_state <= Readr;
		Readr : nxt_state <= Readdr;
		Readdr : nxt_state <= Write;
		Write :
			if (pos_row == 7'h7F) nxt_state <= Finish;
			else nxt_state <= Readur;
	endcase
end

always @(posedge clk/* or posedge reset*/) begin // FSM
	if (reset == 1'b1) state <= Idle;
	else state <= nxt_state;
end

always @(posedge clk) begin
	gray_req <= 1'b1;
	gray_addr <= 14'hx;
	lbp_valid <= 1'b0;
	lbp_addr <= 14'hx;
	lbp_data <= 8'hx;
	finish <= 1'b0;
	case (state)
		Idle : begin
			pos <= {7'h0, 7'h7F};
			gray_addr <= {7'h0, 7'h0};
		end
		Readur : begin
			data[2] <= gray_data;
			gray_addr <= pos_r;
		end
		Readr : begin
			data[5] <= gray_data;
			gray_addr <= pos_dr;
		end
		Readdr : begin
			data[8] <= gray_data;
		end
		Write : begin
			lbp_valid <= !pos_is_folc;
			lbp_addr <= pos;
			lbp_data[0] <= (data[0] >= data[4]);
			lbp_data[1] <= (data[1] >= data[4]);
			lbp_data[2] <= (data[2] >= data[4]);
			lbp_data[3] <= (data[3] >= data[4]);
			lbp_data[4] <= (data[5] >= data[4]);
			lbp_data[5] <= (data[6] >= data[4]);
			lbp_data[6] <= (data[7] >= data[4]);
			lbp_data[7] <= (data[8] >= data[4]);

			data[0] <= data[1];
			data[1] <= data[2];
			data[3] <= data[4];
			data[4] <= data[5];
			data[6] <= data[7];
			data[7] <= data[8];
			pos <= pos_r;
			gray_addr <= pos_rur;
		end
		Finish : begin
			finish <= 1'b1;
		end
	endcase
end

endmodule
