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
localparam SC_BEGIN		= 8'h5E; // '^' (special character)
localparam SC_END		= 8'h24; // '$'
localparam SC_ANY		= 8'h2E; // '.'
localparam SC_ASTERISK	= 8'h2A; // '*'
localparam SC_SPACE		= 8'h20; // ' '

wire chardata_is_begin = (chardata == SC_BEGIN);
wire chardata_is_asterisk = (chardata == SC_ASTERISK);

reg [2:0] state, nxt_state;
localparam Idle		= 3'd0;
localparam ReadS	= 3'd1;
localparam ReadP1	= 3'd2;
localparam ReadP2_1	= 3'd3;
localparam ReadP2_2	= 3'd4;
localparam Compare2	= 3'd5;
localparam Compare1	= 3'd6;

reg [7:0] str [0:33]; // string
reg [5:0] sb; // string begin position
reg [7:0] pat1 [0:7]; // pattern 1 (before *) 
reg [2:0] pb1; // pattern 1 begin position
reg pat1_flag; // pattern 1 begin with SC_BEGIN ('^')
wire [3:0] pb1_len = 4'd8 - pb1;
reg [7:0] pat2 [0:6]; // pattern 2 (after *)
reg [2:0] pb2; // pattern 2 begin position
wire [2:0] pb2_len = 3'd7 - pb2;

reg [5:0] i2;
wire [5:0] i2_start_pos = 6'd34 - pb2_len;
wire [5:0] i2_sub_1 = i2 - 6'd1;
wire i2_end = (i2 <= sb + 6'd1);
reg [5:0] j;
wire [7:0] str_j_ = str[j];
wire [5:0] j_add_1 = j + 6'd1;
reg [2:0] k2;
wire [7:0] pat2_k2_ = pat2[k2];
wire [2:0] k2_add_1 = k2 + 3'd1;
wire k2_end = (k2 == 3'd6);
wire sj_eq_p2k2 = ((str_j_ == pat2_k2_) || (str_j_ != SC_END && pat2_k2_ == SC_ANY) || (str_j_ == SC_SPACE && pat2_k2_ == SC_END));

reg [5:0] i1;
wire [5:0] i1_add_1 = i1 + 6'd1;
wire i1_end = (i1 + pb1_len >= i2);
//reg [5:0] j1;
//wire [5:0] j1_add_1 = j + 6'd1;
reg [2:0] k1;
wire [7:0] pat1_k1_ = pat1[k1];
wire [2:0] k1_add_1 = k1 + 3'd1;
wire k1_end = (k1 == 3'd7);
wire sj_eq_p1k1 = ((str_j_ == pat1_k1_) || (str_j_ != SC_BEGIN && str_j_ != SC_END && pat1_k1_ == SC_ANY) || (str_j_ == SC_SPACE && (pat1_k1_ == SC_BEGIN || pat1_k1_ == SC_END)));

always @(*) begin // next state logic
	nxt_state <= state;
	case (state)
		Idle :
			if (isstring) nxt_state <= ReadS;
			else if (ispattern) begin
				if (chardata_is_asterisk) nxt_state <= ReadP2_1;
				else nxt_state <= ReadP1;
			end
		ReadS :
			if (ispattern) begin
				if (chardata_is_asterisk) nxt_state <= ReadP2_1;
				else nxt_state <= ReadP1;
			end
		ReadP1 :
			if (chardata_is_asterisk) nxt_state <= ReadP2_1;
			else if (!ispattern) nxt_state <= Compare1;
		ReadP2_1 :
			if (ispattern) nxt_state <= ReadP2_2;
			else nxt_state <= Compare1;
		ReadP2_2 :
			if (!ispattern) nxt_state <= Compare2;
		Compare2 :
			if (sj_eq_p2k2) begin
				if (k2_end) nxt_state <= Compare1;
			end
			else if (i2_end) nxt_state <= Idle;
		Compare1 :
			if (sj_eq_p1k1) begin
				if (k1_end) nxt_state <= Idle;
			end
			else if (i1_end) nxt_state <= Idle;
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
	case (state)
		Idle : begin
			pat1_flag <= 1'b0;
			if (isstring) begin
				str[31] <= SC_BEGIN;
				str[32] <= chardata;
				str[33] <= SC_END;
				sb <= 6'd31;
			end
			if (ispattern) begin
				if (chardata_is_asterisk) begin
					pat1[7] <= SC_BEGIN;
					pat1_flag <= 1'b1;
				end
				else begin
					pat1[7] <= chardata;
					if (chardata_is_begin) pat1_flag <= 1'b1;
				end
				pb1 <= 3'd7;
			end
		end
		ReadS : begin
			if (isstring) begin
				str[0:31] <= str[1:32];
				str[32] <= chardata;
				sb <= sb - 6'd1;
			end
			if (ispattern) begin
				if (chardata_is_asterisk) begin
					pat1[7] <= SC_BEGIN;
					pat1_flag <= 1'b1;
				end
				else begin
					pat1[7] <= chardata;
					if (chardata_is_begin) pat1_flag <= 1'b1;
				end
				pb1 <= 3'd7;
			end
		end
		ReadP1 : begin
			if (ispattern && !chardata_is_asterisk) begin
				pat1[0:6] <= pat1[1:7];
				pat1[7] <= chardata;
				pb1 <= pb1 - 3'd1;
			end
			i2 <= 6'd34;
			i1 <= sb;
			j <= sb;
			k1 <= pb1;
		end
		ReadP2_1 : begin
			if (ispattern) begin
				pat2[6] <= chardata;
				pb2 <= 3'd6;
			end
			i2 <= 6'd34;
			i1 <= sb;
			j <= sb;
			k1 <= pb1;
		end
		ReadP2_2 : begin
			if (ispattern) begin
				pat2[0:5] <= pat2[1:6];
				pat2[6] <= chardata;
				pb2 <= pb2 - 3'd1;
			end
			//else begin // OPT
				i2 <= i2_start_pos;
				j <= i2_start_pos;
				k2 <= pb2;
			//end
		end
		Compare2 : begin
			if (sj_eq_p2k2) begin
				if (k2_end) j <= i1;
				else j <= j_add_1;
				k2 <= k2_add_1;
			end
			else begin
				if (i2_end) begin // no match
					valid <= 1'b1;
				end
				i2 <= i2_sub_1;
				j <= i2_sub_1;
				k2 <= pb2;
			end
		end
		Compare1 : begin
			if (sj_eq_p1k1) begin
				if (k1_end) begin // match
					valid <= 1'b1;
					match <= 1'b1;
					match_index <= i1 - sb - !pat1_flag;
				end
				j <= j_add_1;
				k1 <= k1_add_1;
			end
			else begin
				if (i1_end) begin // no match
					valid <= 1'b1;
				end
				i1 <= i1_add_1;
				j <= i1_add_1;
				k1 <= pb1;
			end
		end
	endcase
end

endmodule
