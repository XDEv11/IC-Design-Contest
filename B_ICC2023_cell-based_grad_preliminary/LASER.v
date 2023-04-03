module LASER (
input CLK,
input RST,
input [3:0] X,
input [3:0] Y,
output reg [3:0] C1X,
output reg [3:0] C1Y,
output reg [3:0] C2X,
output reg [3:0] C2Y,
output reg DONE);
/* my design */
integer i; genvar gv_i;

reg [2:0] state, nxt_state;
localparam Idle		= 3'd0;
localparam Read		= 3'd1;
localparam Step1_1	= 3'd2;
localparam Step1_2	= 3'd3;
localparam Step2	= 3'd4;
localparam Output	= 3'd5;

reg [3:0] pts [0:39][0:1];

reg [5:0] cnt;
wire [5:0] cnt_add_1  = cnt + 6'd1;
wire cnt_is_39 = (cnt == 6'd39);

reg [3:0] c1_x, c1_y, c2_x, c2_y;
reg in_c1 [0:39], in_c2 [0:39];
localparam c1_x_tbegin = 4'd0;
wire [3:0] c1_x_move_1 = c1_x - 4'd1;
wire c1_x_is_end = (c1_x == 4'd0);
localparam c1_y_tbegin = 4'd15;
wire [3:0] c1_y_move_1 = c1_y + 4'd1;
wire c1_y_is_end = (c1_y == 4'd15);
wire c1_is_end = (c1_x_is_end && c1_y_is_end);
wire [3:0] c1_x_next = c1_x_move_1;
wire [3:0] c1_y_next = (c1_x_is_end ? c1_y_move_1 : c1_y);

reg mx_up, mx_st;
reg [5:0] mx;
reg [3:0] mx_x, mx_y, mx_x2, mx_y2;
reg mx_in [0:39];

//
wire in_c1_next [0:39];
for (gv_i = 0; gv_i < 40; gv_i = gv_i + 1) begin
	Inr4 u_inr4(pts[gv_i][0], pts[gv_i][1], c1_x_next, c1_y_next, in_c1_next[gv_i]);
end
for (gv_i = 0; gv_i < 40; gv_i = gv_i + 1) begin
	always @(posedge CLK) begin
		in_c1[gv_i] <= in_c1_next[gv_i];
	end
end

wire in [0:39];
for (gv_i = 0; gv_i < 40; gv_i = gv_i + 1) begin
	assign in[gv_i] = (in_c1[gv_i] || in_c2[gv_i]);
end

wire [5:0] in_cnt;
wire [1:0] _in_cnt1 [0:19];
wire [2:0] _in_cnt2 [0:9];
wire [3:0] _in_cnt3 [0:4];
for (gv_i = 0; 2 * gv_i + 1 < 40; gv_i = gv_i + 1) begin
	assign _in_cnt1[gv_i] = in[2 * gv_i] + in[2 * gv_i + 1];
end
for (gv_i = 0; 2 * gv_i + 1 < 20; gv_i = gv_i + 1) begin
	assign _in_cnt2[gv_i] = _in_cnt1[2 * gv_i] + _in_cnt1[2 * gv_i + 1];
end
for (gv_i = 0; 2 * gv_i + 1 < 10; gv_i = gv_i + 1) begin
	assign _in_cnt3[gv_i] = _in_cnt2[2 * gv_i] + _in_cnt2[2 * gv_i + 1];
end
assign in_cnt = _in_cnt3[0]
			  + _in_cnt3[1]
			  + _in_cnt3[2]
			  + _in_cnt3[3]
			  + _in_cnt3[4];

reg mx_up_next;
always @(*) begin
	mx_up_next <= mx_up;
	if (in_cnt > mx) mx_up_next <= 1'b1;
end
reg [5:0] mx_next;
reg [3:0] mx_x_next, mx_y_next;
reg mx_in_next [0:39];
always @(*) begin
	mx_next <= mx;
	mx_x_next <= mx_x;
	mx_y_next <= mx_y;
	for (i = 0; i < 40; i = i + 1) begin
		mx_in_next[i] <= mx_in[i];
	end
	if (in_cnt >= mx) begin
		mx_next <= in_cnt;
		mx_x_next <= c1_x;
		mx_y_next <= c1_y;
		for (i = 0; i < 40; i = i + 1) begin
			mx_in_next[i] <= in_c1[i];
		end
	end
end
//

always @(*) begin // next state logic
	nxt_state <= state;
	case (state)
		Idle : nxt_state <= Read;
		Read :
			if (cnt_is_39) nxt_state <= Step1_1;
		Step1_1 : nxt_state <= Step1_2;
		Step1_2 :
			if (c1_is_end) nxt_state <= Step2;
		Step2 :
			if (c1_is_end && !mx_up && mx_st) nxt_state <= Output;
		Output : nxt_state <= Idle;
	endcase
end

always @(posedge CLK /*or posedge RST*/) begin // FSM
	if (RST) state <= Idle;
	else state <= nxt_state;
end

always @(posedge CLK) begin
	cnt <= 6'dx; //
	c1_x <= 4'dx; //
	c1_y <= 4'dx; //
	case (state)
		Idle : begin
			cnt <= 6'd1;
			pts[39][0] <= X; pts[39][1] <= Y;
		end
		Read : begin
			cnt <= cnt_add_1;
			for (i = 0; i + 1 < 40; i = i + 1) begin
				pts[i][0] <= pts[i + 1][0]; pts[i][1] <= pts[i + 1][1];
			end
			pts[39][0] <= X; pts[39][1] <= Y;

			mx_up <= 1'b0; mx_st <= 1'b0;
			mx <= 6'd0;
			c1_x <= c1_x_tbegin; c1_y <= c1_y_tbegin;
			for (i = 0; i < 40; i = i + 1) in_c2[i] <= 1'b0;
		end
		Step1_1 : begin
			c1_x <= c1_x_next; c1_y <= c1_y_next;
		end
		Step1_2 : begin
			mx <= mx_next; mx_x <= mx_x_next; mx_y <= mx_y_next;
			for (i = 0; i < 40; i = i + 1) mx_in[i] <= mx_in_next[i];

			c1_x <= c1_x_next; c1_y <= c1_y_next;
			if (c1_is_end) begin
				c2_x <= mx_x_next; c2_y <= mx_y_next;
				for (i = 0; i < 40; i = i + 1) in_c2[i] <= mx_in_next[i];
			end
		end
		Step2 : begin
			mx_up <= mx_up_next;
			mx <= mx_next; mx_x <= mx_x_next; mx_y <= mx_y_next;
			for (i = 0; i < 40; i = i + 1) mx_in[i] <= mx_in_next[i];

			c1_x <= c1_x_next; c1_y <= c1_y_next;
			if (c1_is_end) begin
				if (mx_up || !mx_st) begin
					c2_x <= mx_x_next; c2_y <= mx_y_next;
					for (i = 0; i < 40; i = i + 1) in_c2[i] <= mx_in_next[i];
				end
				mx_up <= 1'b0; mx_st <= !mx_up;
			end
		end
	endcase
end

always @(*) begin
	DONE <= 1'b0;
	C1X <= 4'dx; C1Y <= 4'dx;
	C2X <= 4'dx; C2Y <= 4'dx;
	case (state)
		Output : begin
			DONE <= 1'b1;
			C1X <= mx_x; C1Y <= mx_y;
			C2X <= c2_x; C2Y <= c2_y;
		end
	endcase
end
endmodule

module Inr4(x, y, c_x, c_y, in);
input [3:0] x, y, c_x, c_y;
output in;

wire signed [4:0] xd = x - c_x;
wire signed [4:0] yd = y - c_y;
wire [3:0] xd_abs = (xd[4] ? -xd : xd);
wire [3:0] yd_abs = (yd[4] ? -yd : yd);
reg [3:0] gd, ld;
always @(*) begin
	if (xd_abs >= yd_abs) begin
		gd <= xd_abs; ld <= yd_abs;
	end
	else begin
		gd <= yd_abs; ld <= xd_abs;
	end
end

assign in = ((gd <= 4'd4 && ld <= 4'd0) ||
			 (gd <= 4'd3 && ld <= 4'd2));
endmodule
