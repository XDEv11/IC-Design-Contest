module SME(clk,reset,chardata,isstring,ispattern,valid,match,match_index);
input clk;
input reset;
input [7:0] chardata;
input isstring;
input ispattern;
output match;
output [4:0] match_index;
output valid;
reg match;
reg [4:0] match_index;
reg valid;
/* my design */
localparam SC_BEGIN	= 8'h5E; // '^' (special character)
localparam SC_END	= 8'h24; // '$'
localparam SC_ANY	= 8'h2E; // '.'
localparam SC_SPACE	= 8'h20; // ' '

wire chardata_is_begin = (chardata == SC_BEGIN);

reg [1:0] state, nxt_state;
localparam Idle		= 2'd0;
localparam ReadS	= 2'd1;
localparam ReadP	= 2'd2;
localparam Compare	= 2'd3;

reg [7:0] str [0:33]; // string
reg [5:0] sb; // string begin position
reg [7:0] pat [0:8]; // pattern
reg [3:0] pb; // pattern begin position
wire [3:0] pat_len = 4'd9 - pb;
reg pat_flag; // pattern begin with SC_BEGIN ('^')

reg [5:0] i;
wire [5:0] i_add_1 = i + 6'd1;
wire i_end = (i + pat_len >= 6'd34);
reg [5:0] j;
wire [7:0] str_j_ = str[j];
wire [5:0] j_add_1 = j + 6'd1;
reg [3:0] k;
wire [7:0] pat_k_ = pat[k];
wire [3:0] k_add_1 = k + 4'd1;
wire k_end = (k == 4'd8);
wire sj_eq_pk = ((str_j_ == pat_k_) || (str_j_ != SC_BEGIN && str_j_ != SC_END && pat_k_ == SC_ANY) || (str_j_ == SC_SPACE && (pat_k_ == SC_BEGIN || pat_k_ == SC_END)));

always @(*) begin // next state logic
	nxt_state <= state;
	case (state)
		Idle :
			if (isstring) nxt_state <= ReadS;
			else if (ispattern) nxt_state <= ReadP;
		ReadS :
			if (!isstring) nxt_state <= ReadP;
		ReadP :
			if (!ispattern) nxt_state <= Compare;
		Compare :
			if (sj_eq_pk) begin
				if (k_end) nxt_state <= Idle;
			end
			else if (i_end) nxt_state <= Idle;
	endcase
end

always @(posedge clk/* or posedge reset*/) begin
	if (reset) state <= Idle;
	else state <= nxt_state;
end

always @(posedge clk) begin
	valid <= 1'b0;
	match <= 1'b0;
	match_index <= 5'bx;
	str[33] <= SC_END; // OPT
	if (isstring) str[32] <= chardata; // OPT
	if (ispattern) pat[8] <= chardata; // OPT
	case (state)
		Idle : begin
			pat_flag <= 1'b0;
			if (isstring) begin
				str[31] <= SC_BEGIN;
				str[32] <= chardata;
				str[33] <= SC_END;
				sb <= 6'd31;
			end
			if (ispattern) begin
				pat[8] <= chardata;
				if (chardata_is_begin) pat_flag <= 1'b1;
				pb <= 4'd8;
			end
		end
		ReadS : begin
			if (isstring) begin
				str[0:31] <= str[1:32];
				str[32] <= chardata;
				sb <= sb - 6'd1;
			end
			if (ispattern) begin
				pat[8] <= chardata;
				if (chardata_is_begin) pat_flag <= 1'b1;
				pb <= 4'd8;
			end
		end
		ReadP : begin
			if (ispattern) begin
				pat[0:7] <= pat[1:8];
				pat[8] <= chardata;
				pb <= pb - 4'd1;
			end
			//else begin // OPT
				i <= sb;
				j <= sb;
				k <= pb;
			//end
		end
		Compare : begin
			if (sj_eq_pk) begin
				if (k_end) begin // match
					valid <= 1'b1;
					match <= 1'b1;
					match_index <= i - sb - !pat_flag;
				end
				j <= j_add_1;
				k <= k_add_1;
			end
			else begin
				if (i_end) begin // no match
					valid <= 1'b1;
				end
				i <= i_add_1;
				j <= i_add_1;
				k <= pb;
			end
		end
	endcase
end

endmodule
