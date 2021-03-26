`timescale 1ns/10ps
module RFILE(clk, rst, A_x, A_y, B_x, B_y, C_x, C_y, rssiA, rssiB, rssiC, valueA, valueB, valueC, expA, expB, expC, busy, out_valid, xt, yt);
input           clk;
input           rst;
input  [7:0]    A_x;
input  [7:0]    A_y; 
input  [7:0]    B_x; 
input  [7:0]    B_y; 
input  [7:0]    C_x; 
input  [7:0]    C_y;
input signed [19:0]   rssiA;
input signed [19:0]   rssiB;
input signed [19:0]   rssiC;
input  [15:0]   valueA;
input  [15:0]   valueB;
input  [15:0]   valueC;
output [11:0]   expA;
output [11:0]   expB;
output [11:0]   expC;
output          busy;
output          out_valid;
output     [7:0] xt;
output     [7:0] yt;
/* my design */
wire request;
wire den;
wire [7:0]  xa;
wire [15:0] xa2;
wire [7:0]  ya;
wire [15:0] ya2;
wire [17:0] da2;
wire [7:0]  xb;
wire [15:0] xb2;
wire [7:0]  yb;
wire [15:0] yb2;
wire [17:0] db2;
wire [7:0]  xc;
wire [15:0] xc2;
wire [7:0]  yc;
wire [15:0] yc2;
wire [17:0] dc2;

RFILE_D rfile_d(clk, rst, A_x, A_y, B_x, B_y, C_x, C_y, rssiA, rssiB, rssiC, valueA, valueB, valueC, expA, expB, expC, busy,
		request, den, xa, xa2, ya, ya2, da2, xb, xb2, yb, yb2, db2, xc, xc2, yc, yc2, dc2);

RFILE_XY rfile_xy(clk, rst, request, den, xa, xa2, ya, ya2, da2, xb, xb2, yb, yb2, db2, xc, xc2, yc, yc2, dc2, out_valid, xt, yt);

endmodule

module RFILE_D(clk, rst, A_x, A_y, B_x, B_y, C_x, C_y, rssiA, rssiB, rssiC, valueA, valueB, valueC, expA, expB, expC, busy,
	   request, den, xa, xa2, ya, ya2, da2, xb, xb2, yb, yb2, db2, xc, xc2, yc, yc2, dc2);
input clk;
input rst;
input [7:0] A_x;
input [7:0] A_y; 
input [7:0] B_x; 
input [7:0] B_y; 
input [7:0] C_x; 
input [7:0] C_y;
input signed [19:0] rssiA;
input signed [19:0] rssiB;
input signed [19:0] rssiC;
input [15:0] valueA;
input [15:0] valueB;
input [15:0] valueC;
output [11:0] expA;
output [11:0] expB;
output [11:0] expC;
output reg busy;
input request;
output reg den;
output reg [7:0]  xa;
output reg [15:0] xa2;
output reg [7:0]  ya;
output reg [15:0] ya2;
output reg [17:0] da2;
output reg [7:0]  xb;
output reg [15:0] xb2;
output reg [7:0]  yb;
output reg [15:0] yb2;
output reg [17:0] db2;
output reg [7:0]  xc;
output reg [15:0] xc2;
output reg [7:0]  yc;
output reg [15:0] yc2;
output reg [17:0] dc2;
//
localparam alpha = 6'h3B; // 'd59
localparam tenxn = 5'h14; // 'd20 (10 * n)

reg [2:0] state, nxt_state;
localparam Idle		= 3'd0;
localparam S0		= 3'd1;
localparam S1		= 3'd2;
localparam S2		= 3'd3;
localparam S3		= 3'd4;
localparam S4		= 3'd5;
localparam Output	= 3'd6;

reg first_flag;

wire [18:0] abs_rssiA = -rssiA;
wire [18:0] abs_rssiB = -rssiB;
wire [18:0] abs_rssiC = -rssiC;

wire [18:0] abs_rssiA_sub_alpha = {abs_rssiA[18:12] - alpha, abs_rssiA[11:0]};
wire [18:0] abs_rssiB_sub_alpha = {abs_rssiB[18:12] - alpha, abs_rssiB[11:0]};
wire [18:0] abs_rssiC_sub_alpha = {abs_rssiC[18:12] - alpha, abs_rssiC[11:0]};

reg [13:0] totexpA;
reg [13:0] totexpB;
reg [13:0] totexpC;
reg totexpA_start;
wire totexpA_finish;
wire [18:0] totexpA_quotient;
DIV#(.dividend_size(19), .divisor_size(5)) totexpA_div_19_5(clk, rst, totexpA_start, abs_rssiA_sub_alpha, tenxn, totexpA_finish, totexpA_quotient);
reg totexpB_start;
wire totexpB_finish;
wire [18:0] totexpB_quotient;
DIV#(.dividend_size(19), .divisor_size(5)) totexpB_div_19_5(clk, rst, totexpB_start, abs_rssiB_sub_alpha, tenxn, totexpB_finish, totexpB_quotient);
reg totexpC_start;
wire totexpC_finish;
wire [18:0] totexpC_quotient;
DIV#(.dividend_size(19), .divisor_size(5)) totexpC_div_19_5(clk, rst, totexpC_start, abs_rssiC_sub_alpha, tenxn, totexpC_finish, totexpC_quotient);

assign expA = totexpA[11:0];
assign expB = totexpB[11:0];
assign expC = totexpC[11:0];

reg [20:0] da;
reg [20:0] db;
reg [20:0] dc;
always @(*) begin
	case (totexpA[13:12])
		2'd0 : da <= valueA;
		2'd1 : da <= valueA * 4'd10; // (valueA << 3) + (valueA << 1)
		2'd2 : da <= valueA * 7'd100; // (valueA << 6) + (valueA << 5) + (valueA << 2)
		default : da <= 21'bx;
	endcase
	case (totexpB[13:12])
		2'd0 : db <= valueB;
		2'd1 : db <= valueB * 4'd10; // (valueB << 3) + (valueB << 1)
		2'd2 : db <= valueB * 7'd100; // (valueB << 6) + (valueB << 5) + (valueB << 2)
		default : db <= 21'bx;
	endcase
	case (totexpC[13:12])
		2'd0 : dc <= valueC;
		2'd1 : dc <= valueC * 4'd10; // (valueC << 3) + (valueC << 1)
		2'd2 : dc <= valueC * 7'd100; // (valueC << 6) + (valueC << 5) + (valueC << 2)
		default : dc <= 21'bx;
	endcase
end

reg xa2_start;
wire xa2_finish;
wire [15:0] xa2_product;
MULT#(.multiplicand_size(8), .multiplier_size(8)) xa2_mult_8_8(clk, rst, xa2_start, A_x, A_x, xa2_finish, xa2_product);
reg ya2_start;
wire ya2_finish;
wire [15:0] ya2_product;
MULT#(.multiplicand_size(8), .multiplier_size(8)) ya2_mult_8_8(clk, rst, ya2_start, A_y, A_y, ya2_finish, ya2_product);
reg da2_start;
wire da2_finish;
wire [17:0] da2_product;
MULT#(.multiplicand_size(9), .multiplier_size(9)) da2_mult_9_9(clk, rst, da2_start, da[20:12], da[20:12], da2_finish, da2_product);
reg xb2_start;
wire xb2_finish;
wire [15:0] xb2_product;
MULT#(.multiplicand_size(8), .multiplier_size(8)) xb2_mult_8_8(clk, rst, xb2_start, B_x, B_x, xb2_finish, xb2_product);
reg yb2_start;
wire yb2_finish;
wire [15:0] yb2_product;
MULT#(.multiplicand_size(8), .multiplier_size(8)) yb2_mult_8_8(clk, rst, yb2_start, B_y, B_y, yb2_finish, yb2_product);
reg db2_start;
wire db2_finish;
wire [17:0] db2_product;
MULT#(.multiplicand_size(9), .multiplier_size(9)) db2_mult_9_9(clk, rst, db2_start, db[20:12], db[20:12], db2_finish, db2_product);
reg xc2_start;
wire xc2_finish;
wire [15:0] xc2_product;
MULT#(.multiplicand_size(8), .multiplier_size(8)) xc2_mult_8_8(clk, rst, xc2_start, C_x, C_x, xc2_finish, xc2_product);
reg yc2_start;
wire yc2_finish;
wire [15:0] yc2_product;
MULT#(.multiplicand_size(8), .multiplier_size(8)) yc2_mult_8_8(clk, rst, yc2_start, C_y, C_y, yc2_finish, yc2_product);
reg dc2_start;
wire dc2_finish;
wire [17:0] dc2_product;
MULT#(.multiplicand_size(9), .multiplier_size(9)) dc2_mult_9_9(clk, rst, dc2_start, dc[20:12], dc[20:12], dc2_finish, dc2_product);

always @(*) begin // next state logic
	nxt_state <= state;
	case (state)
		Idle : nxt_state <= S0;
		S0 : nxt_state <= S1;
		S1 :
			if (totexpA_finish/* && totexpB_finish && totexpC_finish*/) nxt_state <= S2;
		S2 : nxt_state <= S3;
		S3 :
			if (da2_finish/* && db2_finish && dc2_finish*/) begin
				if (first_flag) nxt_state <= Output;
				else nxt_state <= S4;
			end
		S4 :
			if (request) nxt_state <= Output;
		Output : nxt_state <= S0;
	endcase
end

always @(posedge clk/* or posedge rst*/) begin // FSM
	if (rst) state <= Idle;
	else state <= nxt_state;
end

always @(*) begin
	busy <= 1'b1;
	totexpA_start <= 1'b0;
	totexpB_start <= 1'b0;
	totexpC_start <= 1'b0;
	xa2_start <= 1'b0;
	ya2_start <= 1'b0;
	da2_start <= 1'b0;
	xb2_start <= 1'b0;
	yb2_start <= 1'b0;
	db2_start <= 1'b0;
	xc2_start <= 1'b0;
	yc2_start <= 1'b0;
	dc2_start <= 1'b0;
	den <= 1'b0;
	case (state)
		Idle : begin
			busy <= 1'b0;
		end
		S0 : begin
			totexpA_start <= 1'b1;
			totexpB_start <= 1'b1;
			totexpC_start <= 1'b1;
		end
		S2 : begin
			xa2_start <= 1'b1;
			ya2_start <= 1'b1;
			da2_start <= 1'b1;
			xb2_start <= 1'b1;
			yb2_start <= 1'b1;
			db2_start <= 1'b1;
			xc2_start <= 1'b1;
			yc2_start <= 1'b1;
			dc2_start <= 1'b1;
		end
		Output : begin
			busy <= 1'b0;
			den <= 1'b1;
		end
	endcase
end

always @(posedge clk) begin
	totexpA <= 14'bx;
	totexpB <= 14'bx;
	totexpC <= 14'bx;
	case (state)
		Idle : begin
			first_flag <= 1'b1;
		end
		S1 : begin
			if (totexpA_finish) totexpA <= totexpA_quotient;
			if (totexpB_finish) totexpB <= totexpB_quotient;
			if (totexpC_finish) totexpC <= totexpC_quotient;
		end
		S2 : begin
			xa <= A_x;
			ya <= A_y;
			xb <= B_x;
			yb <= B_y;
			xc <= C_x;
			yc <= C_y;
		end
		S3 : begin
			if (xa2_finish) xa2 <= xa2_product;
			if (ya2_finish) ya2 <= ya2_product;
			if (da2_finish) da2 <= da2_product;
			if (xb2_finish) xb2 <= xb2_product;
			if (yb2_finish) yb2 <= yb2_product;
			if (db2_finish) db2 <= db2_product;
			if (xc2_finish) xc2 <= xc2_product;
			if (yc2_finish) yc2 <= yc2_product;
			if (dc2_finish) dc2 <= dc2_product;
		end
		Output : begin
			first_flag <= 1'b0;
		end
	endcase
end
endmodule

module RFILE_XY(clk, rst, request, den, xa, xa2, ya, ya2, da2, xb, xb2, yb, yb2, db2, xc, xc2, yc, yc2, dc2, out_valid, xt, yt);
input clk;
input rst;
output reg request;
input den;
input [7:0]  xa;
input [15:0] xa2;
input [7:0]  ya;
input [15:0] ya2;
input [17:0] da2;
input [7:0]  xb;
input [15:0] xb2;
input [7:0]  yb;
input [15:0] yb2;
input [17:0] db2;
input [7:0]  xc;
input [15:0] xc2;
input [7:0]  yc;
input [15:0] yc2;
input [17:0] dc2;
output reg out_valid;
output reg [7:0] xt;
output reg [7:0] yt;
//
reg [1:0] state, nxt_state;
localparam Idle		= 2'd0;
localparam S0		= 2'd1;
localparam S1		= 2'd2;
localparam Output	= 2'd3;

wire signed [18:0] t1_1 = xa2 + ya2 - da2;
wire signed [18:0] t1_2 = xb2 + yb2 - db2;
wire signed [19:0] t1 = t1_1 - t1_2;
wire signed [8:0] t2 = xa - xb;
wire signed [8:0] t3 = ya - yb;
wire signed [18:0] t4_2 = xc2 + yc2 - dc2;
wire signed [19:0] t4 = t1_1 - t4_2;
wire signed [8:0] t5 = xa - xc;
wire signed [8:0] t6 = ya - yc;

reg signed [17:0] t7_1; // t2 * t6
reg t7_1_start;
wire t7_1_finish;
wire signed [17:0] t7_1_product;
SMULT#(.multiplicand_size(9), .multiplier_size(9)) t7_1_smult_9_9(clk, rst, t7_1_start, t2, t6, t7_1_finish, t7_1_product);
reg signed [17:0] t7_2; // t3 * t5
reg t7_2_start;
wire t7_2_finish;
wire signed [17:0] t7_2_product;
SMULT#(.multiplicand_size(9), .multiplier_size(9)) t7_2_smult_9_9(clk, rst, t7_2_start, t3, t5, t7_2_finish, t7_2_product);
wire signed [18:0] t7 = t7_1 - t7_2;
wire [17:0] abs_t7 = (t7[18] ? -t7 : t7);

reg signed [28:0] t8_1; // t1 * t6
reg t8_1_start;
wire t8_1_finish;
wire signed [28:0] t8_1_product;
SMULT#(.multiplicand_size(20), .multiplier_size(9)) t8_1_smult_20_9(clk, rst, t8_1_start, t1, t6, t8_1_finish, t8_1_product);
reg signed [28:0] t8_2; // t4 * t3
reg t8_2_start;
wire t8_2_finish;
wire signed [28:0] t8_2_product;
SMULT#(.multiplicand_size(20), .multiplier_size(9)) t8_2_smult_20_9(clk, rst, t8_2_start, t4, t3, t8_2_finish, t8_2_product);
wire signed [29:0] t8 = t8_1 - t8_2;
wire [28:0] abs_t8 = (t8[29] ? -t8 : t8);

reg signed [28:0] t9_1; // t4 * t2
reg t9_1_start;
wire t9_1_finish;
wire signed [28:0] t9_1_product;
SMULT#(.multiplicand_size(20), .multiplier_size(9)) t9_1_smult_20_9(clk, rst, t9_1_start, t4, t2, t9_1_finish, t9_1_product);
reg signed [28:0] t9_2; // t1 * t5
reg t9_2_start;
wire t9_2_finish;
wire signed [28:0] t9_2_product;
SMULT#(.multiplicand_size(20), .multiplier_size(9)) t9_2_smult_20_9(clk, rst, t9_2_start, t1, t5, t9_2_finish, t9_2_product);
wire signed [29:0] t9 = t9_1 - t9_2;
wire [28:0] abs_t9 = (t9[29] ? -t9 : t9);

// abs_t8[28:1] / abs_t7;
reg x_start;
wire x_finish;
wire [27:0] x_quotient;
DIV#(.dividend_size(28), .divisor_size(18)) x_div_28_18(clk, rst, x_start, abs_t8[28:1], abs_t7, x_finish, x_quotient);
// abs_t9[28:1] / abs_t7;
reg y_start;
wire y_finish;
wire [27:0] y_quotient;
DIV#(.dividend_size(28), .divisor_size(18)) y_div_28_18(clk, rst, y_start, abs_t9[28:1], abs_t7, y_finish, y_quotient);

reg [5:0] temp_cnt;

always @(*) begin // next state logic
	nxt_state <= state;
	case (state)
		Idle :
			if (den) nxt_state <= S0;
		S0 :
			if (t7_1_finish/* && t7_2_finish && t8_1_finish && t8_2_finish && t9_1_finish && t9_2_finish*/) nxt_state <= S1;
		S1 : nxt_state <= Output;
		Output :
			if (x_finish/* && y_finish*/) nxt_state <= Idle;
	endcase
end

always @(posedge clk/* or posedge rst*/) begin // FSM
	if (rst) state <= Idle;
	else state <= nxt_state;
end

always @(*) begin
	t7_1_start <= 1'b0;
	t7_2_start <= 1'b0;
	t8_1_start <= 1'b0;
	t8_2_start <= 1'b0;
	t9_1_start <= 1'b0;
	t9_2_start <= 1'b0;
	x_start <= 1'b0;
	y_start <= 1'b0;
	request <= 1'b0;
	case (state)
		Idle : begin
			if (den) begin
				t7_1_start <= 1'b1;
				t7_2_start <= 1'b1;
				t8_1_start <= 1'b1;
				t8_2_start <= 1'b1;
				t9_1_start <= 1'b1;
				t9_2_start <= 1'b1;
			end
		end
		S1 : begin
			x_start <= 1'b1;
			y_start <= 1'b1;
		end
		Output : begin
			if (x_finish/* && y_finish*/) request <= 1'b1;
		end
	endcase
end

always @(posedge clk) begin
	out_valid <= 1'b0;
	t7_1 <= 18'bx;
	t7_2 <= 18'bx;
	t8_1 <= 29'bx;
	t8_2 <= 29'bx;
	t9_1 <= 29'bx;
	t9_2 <= 29'bx;
	case (state)
		S0 : begin
			if (t7_1_finish) t7_1 <= t7_1_product;
			if (t7_2_finish) t7_2 <= t7_2_product;
			if (t8_1_finish) t8_1 <= t8_1_product;
			if (t8_2_finish) t8_2 <= t8_2_product;
			if (t9_1_finish) t9_1 <= t9_1_product;
			if (t9_2_finish) t9_2 <= t9_2_product;
		end
		Output : begin
			if (x_finish/* && y_finish*/) begin
				out_valid <= 1'b1;
				xt <= x_quotient;
				yt <= y_quotient;
			end
		end
	endcase
end

endmodule

module MULT#(parameter multiplicand_size = 64, parameter multiplier_size = 64) (clk, rst, start, multiplicand, multiplier, finish, product);
input clk;
input rst;
input start;
input [multiplicand_size - 1:0] multiplicand;
input [multiplier_size - 1:0] multiplier;
output reg finish;
output reg [multiplicand_size + multiplier_size - 1:0] product;

reg state, nxt_state;
localparam Idle	= 1'd0;
localparam Mult	= 1'd1;

reg [multiplicand_size - 1:0] _multiplicand;
reg [multiplicand_size + multiplier_size - 1:0] _product;
reg [multiplicand_size + multiplier_size - 1:0] _product_next;
localparam cnt_size = $clog2(multiplier_size);
reg [cnt_size - 1:0] cnt;
wire [cnt_size - 1:0] cnt_next = cnt + 1;
wire cnt_end = cnt == (multiplier_size - 1);
reg [multiplicand_size:0] temp;
always @(*) begin
	if (_product[0]) temp <= _product[multiplicand_size + multiplier_size - 1:multiplier_size] + _multiplicand;
	else temp <= _product[multiplicand_size + multiplier_size - 1:multiplier_size];
	_product_next <= {temp, _product[multiplier_size - 1:1]};
end

always @(*) begin // next state logic
	nxt_state <= state;
	case (state)
		Idle :
			if (start) nxt_state <= Mult;
		Mult :
			if (cnt_end) nxt_state <= Idle;
	endcase
end

always @(posedge clk/* or negedge rst*/) begin // FSM
	if (rst) state <= Idle;
	else state <= nxt_state;
end

always @(posedge clk) begin
	case (state)
		Idle : begin
			_multiplicand <= multiplicand;
			_product <= {{multiplicand_size{1'b0}}, multiplier};
			cnt <= 0;
		end
		Mult : begin
			_product <= _product_next;
			cnt <= cnt_next;
		end
	endcase
end

always @(*) begin
	finish <= 1'b0;
	product <= 'bx;
	case (state)
		Mult : begin
			if (cnt_end) begin
				finish <= 1'b1;
				product <= _product_next;
			end
		end
	endcase
end
endmodule

module SMULT#(parameter multiplicand_size = 64, parameter multiplier_size = 64) (clk, rst, start, multiplicand, multiplier, finish, product);
input clk;
input rst;
input start;
input signed [multiplicand_size - 1:0] multiplicand;
input signed [multiplier_size - 1:0] multiplier;
output reg finish;
output reg signed [multiplicand_size + multiplier_size - 1:0] product;

reg state, nxt_state;
localparam Idle	= 1'd0;
localparam Mult	= 1'd1;

reg signed [multiplicand_size - 1:0] _multiplicand;
reg signed [multiplicand_size + multiplier_size:0] _product;
reg signed [multiplicand_size + multiplier_size:0] _product_next;
localparam cnt_size = $clog2(multiplier_size);
reg [cnt_size - 1:0] cnt;
wire [cnt_size - 1:0] cnt_next = cnt + 1;
wire cnt_end = cnt == (multiplier_size - 1);
reg signed [multiplicand_size - 1:0] temp;
always @(*) begin
	case (_product[1:0])
		2'b00, 2'b11 : temp <= _product[multiplicand_size + multiplier_size:multiplier_size + 1];
		2'b01 : temp <= _product[multiplicand_size + multiplier_size:multiplier_size + 1] + _multiplicand;
		2'b10 : temp <= _product[multiplicand_size + multiplier_size:multiplier_size + 1] - _multiplicand;
	endcase
	_product_next <= {temp[multiplicand_size - 1], temp, _product[multiplier_size:1]};
end

always @(*) begin // next state logic
	nxt_state <= state;
	case (state)
		Idle :
			if (start) nxt_state <= Mult;
		Mult :
			if (cnt_end) nxt_state <= Idle;
	endcase
end

always @(posedge clk/* or negedge rst*/) begin // FSM
	if (rst) state <= Idle;
	else state <= nxt_state;
end

always @(posedge clk) begin
	case (state)
		Idle : begin
			_multiplicand <= multiplicand;
			_product <= {{multiplicand_size{1'b0}}, multiplier, 1'b0};
			cnt <= 0;
		end
		Mult : begin
			_product <= _product_next;
			cnt <= cnt_next;
		end
	endcase
end

always @(*) begin
	finish <= 1'b0;
	product <= 'bx;
	case (state)
		Mult : begin
			if (cnt_end) begin
				finish <= 1'b1;
				product <= _product_next[multiplicand_size + multiplier_size:1];
			end
		end
	endcase
end
endmodule

module DIV#(parameter dividend_size = 64, parameter divisor_size = 64) (clk, rst, start, dividend, divisor, finish, quotient/*, remainder*/);
input clk;
input rst;
input start;
input [dividend_size - 1:0] dividend;
input [divisor_size - 1:0] divisor;
output reg finish;
output reg [dividend_size - 1:0] quotient;
//output reg [divisor_size - 1:0] remainder;

reg state, nxt_state;
localparam Idle	= 1'd0;
localparam Div	= 1'd1;

reg [divisor_size - 1:0] _divisor;
reg [divisor_size + dividend_size - 1:0] _rq;
reg [divisor_size + dividend_size - 1:0] _rq_next;
localparam cnt_size = $clog2(dividend_size);
reg [cnt_size - 1:0] cnt;
wire [cnt_size - 1:0] cnt_next = cnt + 1;
wire cnt_end = cnt == (dividend_size - 1);
reg [divisor_size:0] temp;
always @(*) begin
	temp <= _rq[divisor_size + dividend_size - 1:dividend_size - 1] - _divisor;
	if (temp[divisor_size]) _rq_next <= {_rq[divisor_size + dividend_size - 2:0], 1'b0};
	else _rq_next <= {temp[divisor_size - 1:0], _rq[dividend_size - 2:0], 1'b1};
end

always @(*) begin // next state logic
	nxt_state <= state;
	case (state)
		Idle :
			if (start) nxt_state <= Div;
		Div :
			if (cnt_end) nxt_state <= Idle;
	endcase
end

always @(posedge clk/* or negedge rst*/) begin // FSM
	if (rst) state <= Idle;
	else state <= nxt_state;
end

always @(posedge clk) begin
	case (state)
		Idle : begin
			_divisor <= divisor;
			_rq <= {{divisor_size{1'b0}}, dividend};
			cnt <= 0;
		end
		Div : begin
			_rq <= _rq_next;
			cnt <= cnt_next;
		end
	endcase
end

always @(*) begin
	finish <= 1'b0;
	quotient <= 'bx;
	//remainder <= 'bx;
	case (state)
		Div : begin
			if (cnt_end) begin
				finish <= 1'b1;
				quotient <= _rq_next[dividend_size - 1:0];
				//remainder <= _rq_next[divisor_size + dividend_size - 1:dividend_size];
			end
		end
	endcase
end
endmodule

