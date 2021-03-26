`timescale 1ns/10ps
module GPSDC(clk, reset_n, DEN, LON_IN, LAT_IN, COS_ADDR, COS_DATA, ASIN_ADDR, ASIN_DATA, Valid, a, D);
input              clk;
input              reset_n;
input              DEN;
input      [23:0]  LON_IN; // .16
input      [23:0]  LAT_IN; // .16
input      [95:0]  COS_DATA; // .32, .32
output     [6:0]   COS_ADDR;
input      [127:0] ASIN_DATA; // .64, .64
output     [5:0]   ASIN_ADDR;
output             Valid;
output     [39:0]  D; // .32
output     [63:0]  a; // .64
/* my design */
reg Valid;
reg [39:0]  D;
reg [63:0]  a;

localparam rad = 11'h477; // .16
localparam R = 24'hC2A532; // .0

reg [11:0] lat; // .16 ('h18C___)
reg [23:0] lon; // .16
reg [63:0] cos_lat; // .64

reg cos_start;
reg [11:0] cos_x; // .16
wire cos_finish;
wire [63:0] cos_cosx; // .64
COS cos(clk, reset_n, COS_ADDR, COS_DATA, cos_start, cos_x, cos_finish, cos_cosx);

// group 1
reg g1_start;
reg [5:0] g1_multiplicand; // .16
wire g1_fininsh;
wire [16:0] g1_product; // .32
MULT#(.multiplicand_size(6), .multiplier_size(11)) g1_mult_6_11(clk, reset_n, g1_start, g1_multiplicand, rad, g1_fininsh, g1_product);
// (group 1 / 2) ^ 2
reg [29:0] g12;
wire g12_fininsh;
wire [29:0] g12_product; // .64
MULT#(.multiplicand_size(15), .multiplier_size(15)) g12_mult_15_15(clk, reset_n, g1_fininsh, g1_product[15:1], g1_product[15:1], g12_fininsh, g12_product);

// group 2
reg g2_start;
reg [5:0] g2_multiplicand; // .16
wire g2_fininsh;
wire [16:0] g2_product; // .32
MULT#(.multiplicand_size(6), .multiplier_size(11)) g2_mult_6_11(clk, reset_n, g2_start, g2_multiplicand, rad, g2_fininsh, g2_product);
// (group 2 / 2) ^ 2
wire g22_fininsh;
wire [29:0] g22_product; // .64
MULT#(.multiplicand_size(15), .multiplier_size(15)) g22_mult_15_15(clk, reset_n, g2_fininsh, g2_product[15:1], g2_product[15:1], g22_fininsh, g22_product);
// g22 * cos_latA
reg [93:0] g22xcoslatA; // .128
wire g22xcoslatA_fininsh;
wire [93:0] g22xcoslatA_product; // .128
MULT#(.multiplicand_size(30), .multiplier_size(64)) g22xcoslatA_mult_30_64(clk, reset_n, g22_fininsh, g22_product, cos_lat, g22xcoslatA_fininsh, g22xcoslatA_product);

// g22 * cos(latA) * cos(latB)
reg [157:0] g22xcoslatAxcoslatB; // .192
reg g22xcoslatAxcoslatB_start;
reg [63:0] g22xcoslatAxcoslatB_multiplicand; // .64
reg [93:0] g22xcoslatAxcoslatB_multiplier; // .128
wire g22xcoslatAxcoslatB_fininsh;
wire [157:0] g22xcoslatAxcoslatB_product; // .192
MULT#(.multiplicand_size(64), .multiplier_size(94)) g22xcoslatAxcoslatB_mult_64_94(clk, reset_n, g22xcoslatAxcoslatB_start, g22xcoslatAxcoslatB_multiplicand, g22xcoslatAxcoslatB_multiplier, g22xcoslatAxcoslatB_fininsh, g22xcoslatAxcoslatB_product);

wire [29:0] _a = g12[29:0] + g22xcoslatAxcoslatB[157:128];

reg asin_start;
reg [29:0] asin_x; // .64
wire asin_finish;
wire [46:0] asin_asinx; // .64
ASIN asin(clk, reset_n, ASIN_ADDR, ASIN_DATA, asin_start, asin_x, asin_finish, asin_asinx);
wire Rxasinx_fininsh;
wire [70:0] Rxasinx_product; // .64
MULT#(.multiplicand_size(47), .multiplier_size(24)) Rxasinx_mult_47_24(clk, reset_n, asin_finish, asin_asinx, R, Rxasinx_fininsh, Rxasinx_product);

reg [2:0] state, nxt_state;
localparam Idle1	= 3'd0;
localparam Wait1	= 3'd1;
localparam Idle2	= 3'd2;
localparam Wait2_a	= 3'd3;
localparam Start2_D	= 3'd4;
localparam Wait2_D	= 3'd5;

wire [11:0] latG = lat >= LAT_IN[11:0] ? lat : LAT_IN[11:0];
wire [11:0] latL = lat < LAT_IN[11:0] ? lat : LAT_IN[11:0];
wire [11:0] _latD = latG - latL;
wire [5:0] latD = _latD;
wire [23:0] lonG = lon >= LON_IN ? lon : LON_IN;
wire [23:0] lonL = lon < LON_IN ? lon : LON_IN;
wire [23:0] _lonD = lonG - lonL;
wire [5:0] lonD = _lonD;

always @(*) begin // next state logic
	nxt_state <= state;
	case (state)
		Idle1 :
			if (DEN) nxt_state <= Wait1;
		Wait1 :
			if (cos_finish) nxt_state <= Idle2;
		Idle2 :
			if (DEN) nxt_state <= Wait2_a;
		Wait2_a :
			if (g22xcoslatAxcoslatB_fininsh) nxt_state <= Start2_D;
		Start2_D : nxt_state <= Wait2_D;
		Wait2_D :
			if (Rxasinx_fininsh) nxt_state <= Idle2;
	endcase
end

always @(posedge clk/* or negedge reset_n*/) begin // FSM
	if (!reset_n) state <= Idle1;
	else state <= nxt_state;
end

always @(*) begin
	cos_start <= 1'b0;
	cos_x <= 24'bx;
	g1_start <= 1'b0;
	g1_multiplicand <= 10'bx;
	g2_start <= 1'b0;
	g2_multiplicand <= 24'bx;
	g22xcoslatAxcoslatB_start <= 1'b0;
	g22xcoslatAxcoslatB_multiplicand <= 64'bx;
	g22xcoslatAxcoslatB_multiplier <= 132'bx;
	asin_start <= 1'b0;
	asin_x <= 30'bx;
	case (state)
		Idle1 : begin
			if (DEN) begin
				cos_start <= 1'b1;
				cos_x <= LAT_IN[11:0];
			end
		end
		Idle2 : begin
			if (DEN) begin
				cos_start <= 1'b1;
				cos_x <= LAT_IN[11:0];
				g1_start <= 1'b1;
				g1_multiplicand <= latD;
				g2_start <= 1'b1;
				g2_multiplicand <= lonD;
			end
		end
		Wait2_a : begin
			if (cos_finish) begin
				g22xcoslatAxcoslatB_start <= 1'b1;
				g22xcoslatAxcoslatB_multiplicand <= cos_cosx;
				g22xcoslatAxcoslatB_multiplier <= g22xcoslatA;
			end
		end
		Start2_D : begin
			asin_start <= 1'b1;
			asin_x <= _a;
		end
	endcase
end

always @(posedge clk) begin
	case (state)
		Idle1 : begin
			lat <= LAT_IN[11:0];
			lon <= LON_IN;
		end
		Wait1 : begin
			if (cos_finish) cos_lat <= cos_cosx;
		end
		Idle2 : begin
			if (DEN) begin
				lat <= LAT_IN[11:0];
				lon <= LON_IN;
			end
		end
		Wait2_a : begin
			if (g12_fininsh) g12 <= g12_product;
			if (g22xcoslatA_fininsh) g22xcoslatA <= g22xcoslatA_product;
			if (cos_finish) cos_lat <= cos_cosx;
			if (g22xcoslatAxcoslatB_fininsh) g22xcoslatAxcoslatB <= g22xcoslatAxcoslatB_product;
		end
	endcase
end

always @(posedge clk) begin
	Valid <= 1'b0;
	a[63:30] <= 34'b0;
	a[29:0] <= 30'bx;
	D[39] <= 1'b0;
	D[38:0] <= 39'bx;
	case (state)
		Wait2_D : begin
			if (Rxasinx_fininsh)
				Valid <= 1'b1;
				a[29:0] <= _a;
				D[38:0] <= Rxasinx_product[70:32];
			end
	endcase
end

endmodule

module COS(clk, reset_n, COS_ADDR, COS_DATA, start, x, finish, cosx);
input clk;
input reset_n;
output reg [6:0] COS_ADDR;
input [95:0] COS_DATA; // .32, .32
input start;
input [11:0] x; // .16
output reg finish;
output reg [63:0] cosx; // .64

wire [27:0] COS_DATA_X = COS_DATA[75:48];
wire [31:0] COS_DATA_Y = COS_DATA[31:0];

reg [2:0] state, nxt_state;
localparam Idle		= 3'd0;
localparam Find		= 3'd1;
localparam Calc1	= 3'd2;
localparam Wait1	= 3'd3;
localparam Calc2	= 3'd4;
localparam Wait2_a	= 3'd5;

reg [27:0] _x, xl, xr; // .32
reg [31:0] yl, yr; // .32

reg [6:0] L, R;
wire [7:0] L_add_R = L + R;
wire [6:0] M = L_add_R[7:1];
reg [27:0] xl_next, xr_next;
reg [31:0] yl_next, yr_next;
reg [6:0] L_next, R_next;
always @(*) begin
	xl_next <= xl;
	yl_next <= yl;
	L_next <= L;
	xr_next <= xr;
	yr_next <= yr;
	R_next <= R;
	if (_x >= COS_DATA_X) begin
		xl_next <= COS_DATA_X;
		yl_next <= COS_DATA_Y;
		L_next <= M;
	end
	else begin
		xr_next <= COS_DATA_X;
		yr_next <= COS_DATA_Y;
		R_next <= M;
	end
end

wire [27:0] _t1 = xr - xl;
wire [18:0] t1 = _t1;
wire [27:0] _t2 = _x - xl;
wire [18:0] t2 = _t2;
wire [31:0] _t3 = yr - yl;
wire [17:0] t3 = _t3;

reg [50:0] t4; // .64
reg t4_start;
reg [31:0] t4_multiplicand; // .32
reg [18:0] t4_multiplier; // .32
wire t4_fininsh;
wire [50:0] t4_product; // .64
MULT#(.multiplicand_size(32), .multiplier_size(19)) t4_mult_32_19(clk, reset_n, t4_start, t4_multiplicand, t4_multiplier, t4_fininsh, t4_product);

reg [36:0] t5; // .64
reg t5_start;
reg [17:0] t5_multiplicand; // .32
reg [18:0] t5_multiplier; // .32
wire t5_fininsh;
wire [36:0] t5_product; // .64
MULT#(.multiplicand_size(18), .multiplier_size(19)) t5_mult_18_19(clk, reset_n, t5_start, t5_multiplicand, t5_multiplier, t5_fininsh, t5_product);

wire [51:0] t4_add_t5 = t4 + t5;

reg t6_start;
reg [83:0] t6_dividend; // .96
reg [18:0] t6_divisor; // .32
wire t6_finish;
wire [83:0] t6_quotient; // .64
DIV#(.dividend_size(84), .divisor_size(19)) t6_div_84_19(clk, reset_n, t6_start, t6_dividend, t6_divisor, t6_finish, t6_quotient);

always @(*) begin // next state logic
	nxt_state <= state;
	case (state)
		Idle :
			if (start) nxt_state <= Find;
		Find :
			if (L_next + 7'd1 == R_next) nxt_state <= Calc1;
		Calc1 : nxt_state <= Wait1;
		Wait1 :
			if (t4_fininsh) nxt_state <= Calc2;
		Calc2 : nxt_state <= Wait2_a;
		Wait2_a :
			if (t6_finish) nxt_state <= Idle;
	endcase
end

always @(posedge clk/* or negedge reset_n*/) begin // FSM
	if (!reset_n) state <= Idle;
	else state <= nxt_state;
end

wire [7:0] L_next_add_R_next = L_next + R_next;
wire [6:0] M_next = L_next_add_R_next[7:1];
always @(posedge clk) begin
	COS_ADDR <= 7'dx;
	case (state)
		Idle : begin
			COS_ADDR <= 7'd63;
		end
		Find : begin
			COS_ADDR <= M_next;
		end
	endcase
end

always @(*) begin
	t4_start <= 1'b0;
	t4_multiplicand <= 32'bx;
	t4_multiplier <= 19'bx;
	t5_start <= 1'b0;
	t5_multiplicand <= 18'bx;
	t5_multiplier <= 19'bx;
	t6_start <= 1'b0;
	t6_dividend <= 84'bx;
	t6_divisor <= 19'bx;
	case (state)
		Calc1 : begin
			t4_start <= 1'b1;
			t4_multiplicand <= yl;
			t4_multiplier <= t1;
			t5_start <= 1'b1;
			t5_multiplicand <= t3;
			t5_multiplier <= t2;
		end
		Calc2 : begin
			t6_start <= 1'b1;
			t6_dividend <= {t4_add_t5, 32'b0};
			t6_divisor <= t1;
		end
	endcase
end

always @(posedge clk) begin
	_x[15:0] <= 16'b0;
	case (state)
		Idle : begin
			_x[27:16] <= x[11:0];
			xl <= 28'h7AE147A;
			yl <= 32'hF03CE5C7;
			L <= 7'd0;
			xr <= 28'hAD6FA82;
			yr <= 32'hF14FA845;
			R <= 7'd127;
		end
		Find : begin
			xl <= xl_next;
			yl <= yl_next;
			L <= L_next;
			xr <= xr_next;
			yr <= yr_next;
			R <= R_next;
		end
		Wait1 : begin
			if (t4_fininsh) t4 <= t4_product;
			if (t5_fininsh) t5 <= t5_product;
		end
	endcase
end

always @(*) begin
	finish <= 1'b0;
	cosx <= 64'bx;
	case (state)
		Wait2_a : begin
			if (t6_finish) begin
				finish <= 1'b1;
				cosx <= t6_quotient[63:0];
			end
		end
	endcase
end
endmodule

module ASIN(clk, reset_n, ASIN_ADDR, ASIN_DATA, start, x, finish, asinx);
input clk;
input reset_n;
output reg [5:0] ASIN_ADDR;
input [127:0] ASIN_DATA; // .64, .64
input start;
input [29:0] x; // .64
output reg finish;
output reg [46:0] asinx; // .64

wire [29:0] ASIN_DATA_X = ASIN_DATA[93:64];
wire [46:0] ASIN_DATA_Y = ASIN_DATA[46:0];

reg [2:0] state, nxt_state;
localparam Idle		= 3'd0;
localparam Find		= 3'd1;
localparam Calc1	= 3'd2;
localparam Wait1	= 3'd3;
localparam Calc2	= 3'd4;
localparam Wait2_a	= 3'd5;

reg [29:0] _x, xl, xr; // .32
reg [46:0] yl, yr; // .32

reg [5:0] L, R;
wire [6:0] L_add_R = L + R;
wire [5:0] M = L_add_R[6:1];
reg [29:0] xl_next, xr_next;
reg [46:0] yl_next, yr_next;
reg [5:0] L_next, R_next;
always @(*) begin
	xl_next <= xl;
	yl_next <= yl;
	L_next <= L;
	xr_next <= xr;
	yr_next <= yr;
	R_next <= R;
	if (_x >= ASIN_DATA_X) begin
		xl_next <= ASIN_DATA_X;
		yl_next <= ASIN_DATA_Y;
		L_next <= M;
	end
	else begin
		xr_next <= ASIN_DATA_X;
		yr_next <= ASIN_DATA_Y;
		R_next <= M;
	end
end

wire [29:0] _t1 = xr - xl;
wire [23:0] t1 = _t1;
wire [29:0] _t2 = _x - xl;
wire [23:0] t2 = _t2;
wire [46:0] _t3 = yr - yl;
wire [43:0] t3 = _t3;

reg [70:0] t4; // .128
reg t4_start;
reg [46:0] t4_multiplicand; // .64
reg [23:0] t4_multiplier; // .64
wire t4_fininsh;
wire [70:0] t4_product; // .128
MULT#(.multiplicand_size(47), .multiplier_size(24)) t4_mult_47_24(clk, reset_n, t4_start, t4_multiplicand, t4_multiplier, t4_fininsh, t4_product);

reg [67:0] t5; // .128
reg t5_start;
reg [43:0] t5_multiplicand; // .64
reg [23:0] t5_multiplier; // .64
wire t5_fininsh;
wire [67:0] t5_product; // .128
MULT#(.multiplicand_size(44), .multiplier_size(24)) t5_mult_44_24(clk, reset_n, t5_start, t5_multiplicand, t5_multiplier, t5_fininsh, t5_product);

wire [70:0] t4_add_t5 = t4 + t5;

reg t6_start;
reg [70:0] t6_dividend; // .128
reg [23:0] t6_divisor; // .64
wire t6_finish;
wire [70:0] t6_quotient; // .64
DIV#(.dividend_size(71), .divisor_size(24)) t6_div_71_24(clk, reset_n, t6_start, t6_dividend, t6_divisor, t6_finish, t6_quotient);

always @(*) begin // next state logic
	nxt_state <= state;
	case (state)
		Idle :
			if (start) nxt_state <= Find;
		Find :
			if (L_next + 6'd1 == R_next) nxt_state <= Calc1;
		Calc1 : nxt_state <= Wait1;
		Wait1 :
			if (t4_fininsh) nxt_state <= Calc2;
		Calc2 : nxt_state <= Wait2_a;
		Wait2_a :
			if (t6_finish) nxt_state <= Idle;
	endcase
end

always @(posedge clk/* or negedge reset_n*/) begin // FSM
	if (!reset_n) state <= Idle;
	else state <= nxt_state;
end

wire [6:0] L_next_add_R_next = L_next + R_next;
wire [5:0] M_next = L_next_add_R_next[6:1];
always @(posedge clk) begin
	ASIN_ADDR <= 6'dx;
	case (state)
		Idle : begin
			ASIN_ADDR <= 6'd31;
		end
		Find : begin
			ASIN_ADDR <= M_next;
		end
	endcase
end

always @(*) begin
	t4_start <= 1'b0;
	t4_multiplicand <= 47'bx;
	t4_multiplier <= 24'bx;
	t5_start <= 1'b0;
	t5_multiplicand <= 44'bx;
	t5_multiplier <= 24'bx;
	t6_start <= 1'b0;
	t6_dividend <= 71'bx;
	t6_divisor <= 24'bx;
	case (state)
		Calc1 : begin
			t4_start <= 1'b1;
			t4_multiplicand <= yl;
			t4_multiplier <= t1;
			t5_start <= 1'b1;
			t5_multiplicand <= t3;
			t5_multiplier <= t2;
		end
		Calc2 : begin
			t6_start <= 1'b1;
			t6_dividend <= t4_add_t5;
			t6_divisor <= t1;
		end
	endcase
end

always @(posedge clk) begin
	case (state)
		Idle : begin
			_x <= x;
			xl <= 30'h0;
			yl <= 47'h0;
			L <= 6'd0;
			xr <= 30'h20cf6e3b;
			yr <= 47'h5ba5fe07d1ed;
			R <= 6'd63;
		end
		Find : begin
			xl <= xl_next;
			yl <= yl_next;
			L <= L_next;
			xr <= xr_next;
			yr <= yr_next;
			R <= R_next;
		end
		Wait1 : begin
			if (t4_fininsh) t4 <= t4_product;
			if (t5_fininsh) t5 <= t5_product;
		end
	endcase
end

always @(*) begin
	finish <= 1'b0;
	asinx <= 47'bx;
	case (state)
		Wait2_a : begin
			if (t6_finish) begin
				finish <= 1'b1;
				asinx <= t6_quotient[46:0];
			end
		end
	endcase
end
endmodule

module MULT#(parameter multiplicand_size = 64, parameter multiplier_size = 64) (clk, reset_n, start, multiplicand, multiplier, finish, product);
input clk;
input reset_n;
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

always @(posedge clk/* or negedge reset_n*/) begin // FSM
	if (!reset_n) state <= Idle;
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

module DIV#(parameter dividend_size = 64, parameter divisor_size = 64) (clk, reset_n, start, dividend, divisor, finish, quotient/*, remainder*/);
input clk;
input reset_n;
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

always @(posedge clk/* or negedge reset_n*/) begin // FSM
	if (!reset_n) state <= Idle;
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

