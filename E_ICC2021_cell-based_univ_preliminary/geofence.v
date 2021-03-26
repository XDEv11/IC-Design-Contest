module geofence ( clk,reset,X,Y,valid,is_inside );
input clk;
input reset;
input [9:0] X;
input [9:0] Y;
output valid;
output is_inside;
/* my design */
reg valid;
reg is_inside;

/* 11-bits * 11-bits signed multiplication (Booth's algorithm) */
reg [10:0] mulitplicand;
reg [22:0] product_cur;
reg [22:0] product_nxt;
reg [10:0] product_tmp;
always @(*) begin
	case (product_cur[1:0])
		2'b00, 2'b11 : product_tmp <= product_cur[22:12];
		2'b01 : product_tmp <= product_cur[22:12] + mulitplicand;
		2'b10 : product_tmp <= product_cur[22:12] - mulitplicand;
	endcase
	product_nxt <= {product_tmp[10], product_tmp, product_cur[11:1]};
end
reg [3:0] mul_iteration;
wire [3:0] mul_iteration_next = mul_iteration + 4'd1;
wire mul_end = (mul_iteration == 4'd10);
wire signed [21:0] product = product_cur[22:1];

reg[3:0] state, nxt_state, save_state, save_state_next;
localparam ReadP		= 4'h0;
localparam ReadF		= 4'h1;
localparam BubbleSort	= 4'h2;
localparam BStmp		= 4'h3;
localparam BScompare	= 4'h4;
localparam Judge		= 4'h5;
localparam Jtmp			= 4'h6;
localparam Jcompare		= 4'h7;
localparam Idle			= 4'h8;
localparam Mul			= 4'h9;

reg [9:0] x [0:6]; // 0 : point, [1:6] : fences
reg [9:0] y [0:6];
reg [2:0] i;
wire [9:0] x_i_ = x[i];
wire [9:0] y_i_ = y[i];
wire [2:0] i_add_1 = i + 3'd1;
wire i_end = (i == 3'd6);
wire [2:0] i_next = (i_end ? 3'd1 : i_add_1);
wire [9:0] x_i_next_ = x[i_next];
wire [9:0] y_i_next_ = y[i_next];
reg [2:0] j;
wire [9:0] x_j_ = x[j];
wire [9:0] y_j_ = y[j];
wire [2:0] j_sub_1 = j - 3'd1;
wire [9:0] x_j_sub_1_ = x[j_sub_1];
wire [9:0] y_j_sub_1_ = y[j_sub_1];
reg signed [21:0] tmp;

always @(*) begin // next state logic
	nxt_state <= state;
	save_state_next <= save_state;
	case (state)
		ReadP : nxt_state <= ReadF;
		ReadF :
			if (i_end) nxt_state <= BubbleSort;
		BubbleSort : begin
			save_state_next <= BStmp;
			nxt_state <= Mul;
		end
		BStmp : begin
			save_state_next <= BScompare;
			nxt_state <= Mul;
		end
		BScompare :
			if (i_end) nxt_state <= Judge;
			else nxt_state <= BubbleSort;

		Judge : begin
			save_state_next <= Jtmp;
			nxt_state <= Mul;
		end
		Jtmp : begin
			save_state_next <= Jcompare;
			nxt_state <= Mul;
		end
		Jcompare :
			if (i_end) nxt_state <= Idle;
			else nxt_state <= Judge;
		Idle : nxt_state <= ReadP;
		Mul : if (mul_end) nxt_state <= save_state; 
	endcase
end

always @(posedge clk/* or posedge reset*/) begin // FSM
	if (reset) state <= ReadP;
	else state <= nxt_state;
end

reg [9:0] sub1_op1, sub1_op2, sub2_op1, sub2_op2;
always @(*) begin
	sub1_op1 <= 10'dx;
	sub1_op2 <= 10'dx;
	sub2_op1 <= 10'dx;
	sub2_op2 <= 10'dx;
	case (state)
		BubbleSort : begin
			sub1_op1 <= x_j_sub_1_;
			sub1_op2 <= x[1];
			sub2_op1 <= y_j_;
			sub2_op2 <= y[1];
		end
		BStmp : begin
			sub1_op1 <= x_j_;
			sub1_op2 <= x[1];
			sub2_op1 <= y_j_sub_1_;
			sub2_op2 <= y[1];
		end
		Judge : begin
			sub1_op1 <= x_i_;
			sub1_op2 <= x[0];
			sub2_op1 <= y_i_next_;
			sub2_op2 <= y[0];
		end
		Jtmp : begin
			sub1_op1 <= x_i_next_;
			sub1_op2 <= x[0];
			sub2_op1 <= y_i_;
			sub2_op2 <= y[0];
		end
	endcase
end
wire [10:0] sub1_diff = sub1_op1 - sub1_op2;
wire [10:0] sub2_diff = sub2_op1 - sub2_op2;

always @(posedge clk) begin
	save_state <= save_state_next;
	valid <= 1'b0;
	mul_iteration <= 4'd0;
	product_cur <= 23'hx;
	case (state)
		ReadP : begin
			x[0] <= X;
			y[0] <= Y;
			i <= 3'd1;
			is_inside <= 1'b1;
		end
		ReadF : begin
			x[1] <= x[2];
			y[1] <= y[2];
			x[2] <= x[3];
			y[2] <= y[3];
			x[3] <= x[4];
			y[3] <= y[4];
			x[4] <= x[5];
			y[4] <= y[5];
			x[5] <= x[6];
			y[5] <= y[6];
			x[6] <= X;
			y[6] <= Y;
			if (i_end) i <= 3'd3;
			else i <= i_add_1;
			j <= 3'd6;
		end
		BubbleSort : begin
			mulitplicand <= sub1_diff;
			product_cur[22:12] <= 11'h0;
			product_cur[11:1] <= sub2_diff;
			product_cur[0] <= 1'h0;
		end
		BStmp : begin
			tmp <= product;
			mulitplicand <= sub1_diff;
			product_cur[22:12] <= 11'h0;
			product_cur[11:1] <= sub2_diff;
			product_cur[0] <= 1'h0;
		end
		BScompare : begin
			if (tmp >= product) begin
				x[j_sub_1] <= x_j_;
				y[j_sub_1] <= y_j_;
				x[j] <= x_j_sub_1_;
				y[j] <= y_j_sub_1_;
			end
			if (j == i) begin
				i <= i_next;	
				j <= 3'd6;
			end
			else j <= j_sub_1;
		end
		Judge : begin
			mulitplicand <= sub1_diff;
			product_cur[22:12] <= 11'h0;
			product_cur[11:1] <= sub2_diff;
			product_cur[0] <= 1'h0;
		end
		Jtmp : begin
			tmp <= product;
			mulitplicand <= sub1_diff;
			product_cur[22:12] <= 11'h0;
			product_cur[11:1] <= sub2_diff;
			product_cur[0] <= 1'h0;
		end
		Jcompare : begin
			if (tmp >= product) is_inside <= 1'b0;
			i <= i_add_1;
			if (i_end) valid <= 1'b1;
		end
		Mul : begin
			mul_iteration <= mul_iteration_next;
			product_cur <= product_nxt;
		end
	endcase
end

endmodule
