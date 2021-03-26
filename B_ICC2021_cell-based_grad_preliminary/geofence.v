// synopsys translate_off
`include "DW_mult_seq.v"
`include "DW_sqrt_seq.v"
// synopsys translate_on

module geofence ( clk,reset,X,Y,R,valid,is_inside);
input clk;
input reset;
input [9:0] X;
input [9:0] Y;
input [10:0] R;
output valid;
output is_inside;
/* my design */
reg valid;
reg is_inside;

/* addsub1 */
localparam ADDSUB1_a_width = 24;
localparam ADDSUB1_b_width = 20;
localparam ADDSUB1_width = (ADDSUB1_a_width >= ADDSUB1_b_width ? ADDSUB1_a_width : ADDSUB1_b_width) + 1;
reg signed [ADDSUB1_a_width - 1 : 0] addsub1_a;
reg [ADDSUB1_b_width - 1 : 0] addsub1_b;
reg addsub1_d;
wire signed [ADDSUB1_width - 1 : 0] addsub1_sum = addsub1_a + (addsub1_d ? -addsub1_b : addsub1_b);

/* sub2 */
localparam SUB2_a_width = 13;
localparam SUB2_b_width = 12;
localparam SUB2_width = (SUB2_a_width >= SUB2_b_width ? SUB2_a_width : SUB2_b_width) + 1;
reg [SUB2_a_width - 1 : 0] sub2_a;
reg [SUB2_b_width - 1 : 0] sub2_b;
wire signed [SUB2_width - 1 : 0] sub2_difference = sub2_a - sub2_b;

/* mult1 */
localparam MULT1_a_width = 13;
localparam MULT1_b_width = 14;
wire mult1_hold = 1'b0;
reg mult1_start;
reg signed [MULT1_a_width - 1 : 0] mult1_a;
reg signed [MULT1_b_width - 1 : 0] mult1_b;
wire mult1_complete;
wire signed [MULT1_a_width + MULT1_b_width - 1 : 0] mult1_product;
DW_mult_seq
	#(.a_width(MULT1_a_width), .b_width(MULT1_b_width), .tc_mode(1), .num_cyc(MULT1_a_width), .rst_mode(1), .input_mode(0), .output_mode(0), .early_start(0))
	mult1(clk, ~reset, mult1_hold, mult1_start, mult1_a, mult1_b, mult1_complete, mult1_product);

/* sqrt1 */
localparam SQRT1_width = 25;
wire sqrt1_hold = 1'b0;
reg sqrt1_start;
reg [SQRT1_width - 1 : 0] sqrt1_a; // Radicand
wire sqrt1_complete;
wire [(SQRT1_width + 1) / 2 - 1 : 0] sqrt1_root;
DW_sqrt_seq
	#(.width(SQRT1_width), .tc_mode(0), .num_cyc((SQRT1_width + 1) / 2), .rst_mode(1), .input_mode(0), .output_mode(0), .early_start(0))
	sqrt1(clk, ~reset, sqrt1_hold, sqrt1_start, sqrt1_a, sqrt1_complete, sqrt1_root);

reg[4:0] state, nxt_state;
localparam Read_1			= 5'd0;
localparam Read_2			= 5'd1;
localparam Sort_1			= 5'd2;
localparam Sort_2			= 5'd3;
localparam Sort_3			= 5'd4;
localparam Area_1			= 5'd5;
localparam Area_2			= 5'd6;
localparam Area_3			= 5'd7;
localparam Triangle_a_1		= 5'd8;
localparam Triangle_a_2		= 5'd9;
localparam Triangle_a_3		= 5'd10;
localparam Triangle_area_1	= 5'd11;
localparam Triangle_area_2	= 5'd12;
localparam Triangle_area_3	= 5'd13;
localparam Triangle_area_4	= 5'd14;
localparam Triangle_area_5	= 5'd15;
localparam Triangle_area_6	= 5'd16;
localparam Output			= 5'd17;
localparam Idle				= 5'd18;

reg [9:0] x [1:6];
reg [9:0] y [1:6];
reg [10:0] r [1:6];
reg [2:0] i;
wire [9:0] x_i_ = x[i];
wire [9:0] y_i_ = y[i];
wire [10:0] r_i_ = r[i];
wire [2:0] i_add_1 = i + 3'd1;
wire i_end = (i == 3'd6);
wire [2:0] i_next = (i_end ? 3'd1 : i_add_1);
wire [9:0] x_i_next_ = x[i_next];
wire [9:0] y_i_next_ = y[i_next];
wire [10:0] r_i_next_ = r[i_next];
reg [2:0] j;
wire [9:0] x_j_ = x[j];
wire [9:0] y_j_ = y[j];
wire [10:0] r_j_ = r[j];
wire [2:0] j_sub_1 = j - 3'd1;
wire [9:0] x_j_sub_1_ = x[j_sub_1];
wire [9:0] y_j_sub_1_ = y[j_sub_1];
wire [10:0] r_j_sub_1_ = r[j_sub_1];

reg signed [21:0] sort_temp;
reg signed [23:0] rarea;
reg [19:0] triangle_temp;
reg [12:0] s;
reg [20:0] tarea;

always @(*) begin // next state logic
	nxt_state <= state;
	case (state)
		Read_1 : nxt_state <= Read_2;
		Read_2 :
			if (i_end) nxt_state <= Sort_1;
		Sort_1 :
			if (mult1_complete) nxt_state <= Sort_2;
		Sort_2 :
			if (mult1_complete) nxt_state <= Sort_3;
		Sort_3 :
			if (mult1_complete) begin
				if (i_end) nxt_state <= Area_1;
				else nxt_state <= Sort_1;
			end
		Area_1 :
			if (mult1_complete) nxt_state <= Area_2;
		Area_2 :
			if (mult1_complete) nxt_state <= Area_3;
		Area_3 :
			if (mult1_complete) begin
				if (i_end) nxt_state <= Triangle_a_1;
				else nxt_state <= Area_1;
			end
		Triangle_a_1 : nxt_state <= Triangle_a_2;
		Triangle_a_2 :
			if (mult1_complete) nxt_state <= Triangle_a_3;
		Triangle_a_3 :
			if (mult1_complete) nxt_state <= Triangle_area_1;
		Triangle_area_1 :
			if (sqrt1_complete) nxt_state <= Triangle_area_2;
		Triangle_area_2 :
			if (mult1_complete) nxt_state <= Triangle_area_3;
		Triangle_area_3 :
			if (sqrt1_complete) nxt_state <= Triangle_area_4;
		Triangle_area_4 :
			if (mult1_complete) nxt_state <= Triangle_area_5;
		Triangle_area_5 :
			if (sqrt1_complete) nxt_state <= Triangle_area_6;
		Triangle_area_6 :
			if (mult1_complete) begin
				if (i_end) nxt_state <= Output;
				else nxt_state <= Triangle_a_1;
			end
		Output : nxt_state <= Idle;
		Idle : nxt_state <= Read_1;
	endcase
end

always @(posedge clk/* or posedge reset*/) begin // FSM
	if (reset) state <= Read_1;
	else state <= nxt_state;
end

wire [10:0] a = sqrt1_root[11:1] + sqrt1_root[0];

always @(*) begin
	addsub1_a <= 'hx;
	addsub1_b <= 'hx;
	addsub1_d <= 'hx;
	sub2_a <= 'hx;
	sub2_b <= 'hx;
	case (state)
		Sort_1 : begin
			addsub1_a <= x_j_sub_1_;
			addsub1_b <= x[1];
			addsub1_d <= 1'b1;
			sub2_a <= y_j_;
			sub2_b <= y[1];
		end
		Sort_2 : begin
			addsub1_a <= x_j_;
			addsub1_b <= x[1];
			addsub1_d <= 1'b1;
			sub2_a <= y_j_sub_1_;
			sub2_b <= y[1];
		end
		Area_2 : begin
			addsub1_a <= rarea;
			addsub1_b <= mult1_product[19:0];
			addsub1_d <= 1'b0;
		end
		Area_3 : begin
			addsub1_a <= rarea;
			addsub1_b <= mult1_product[19:0];
			addsub1_d <= 1'b1;
		end
		Triangle_a_1 : begin
			addsub1_a <= r_i_;
			addsub1_b <= r_i_next_;
			addsub1_d <= 1'b0;
			sub2_a <= x_i_;
			sub2_b <= x_i_next_;
		end
		Triangle_a_2 : begin
			sub2_a <= y_i_;
			sub2_b <= y_i_next_;
		end
		Triangle_a_3 : begin
			addsub1_a <= triangle_temp;
			addsub1_b <= mult1_product;
			addsub1_d <= 1'b0;
		end
		Triangle_area_1 : begin
			addsub1_a <= s;
			addsub1_b <= a;
			addsub1_d <= 1'b0;
			sub2_a <= s;
			sub2_b <= a;
		end
		Triangle_area_3 : begin
			addsub1_a <= s;
			addsub1_b <= {r_i_, 1'b0};
			addsub1_d <= 1'b1;
			sub2_a <= s;
			sub2_b <= {r_i_next_, 1'b0};
		end
		Triangle_area_6 : begin
			addsub1_a <= tarea;
			addsub1_b <= mult1_product[21:2];
			addsub1_d <= 1'b0;
		end
	endcase
end

always @(posedge clk) begin
	valid <= 1'b0;
	mult1_start <= 1'b0;
	sqrt1_start <= 1'b0;
	case (state)
		Read_1 : begin
			rarea <= 24'h0;
			tarea <= 24'h0;
			is_inside <= 1'b1;
			x[1] <= X;
			y[1] <= Y;
			r[1] <= R;
			i <= 3'd2;
		end
		Read_2 : begin
			x[2] <= x[3];
			y[2] <= y[3];
			r[2] <= r[3];
			x[3] <= x[4];
			y[3] <= y[4];
			r[3] <= r[4];
			x[4] <= x[5];
			y[4] <= y[5];
			r[4] <= r[5];
			x[5] <= x[6];
			y[5] <= y[6];
			r[5] <= r[6];
			x[6] <= X;
			y[6] <= Y;
			r[6] <= R;
			if (i_end) i <= 3'd3;
			else i <= i_add_1;
			j <= 3'd6;
		end
		Sort_1 : begin
			if (mult1_complete) begin
				mult1_a <= addsub1_sum;
				mult1_b <= sub2_difference;
				mult1_start <= 1'b1;
			end
		end
		Sort_2 : begin
			if (mult1_complete) begin
				sort_temp <= mult1_product;
				mult1_a <= addsub1_sum;
				mult1_b <= sub2_difference;
				mult1_start <= 1'b1;
			end
		end
		Sort_3 : begin
			if (mult1_complete) begin
				if (sort_temp < mult1_product) begin
					x[j_sub_1] <= x_j_;
					y[j_sub_1] <= y_j_;
					r[j_sub_1] <= r_j_;
					x[j] <= x_j_sub_1_;
					y[j] <= y_j_sub_1_;
					r[j] <= r_j_sub_1_;
				end
				if (j == i) begin
					i <= i_next;	
					j <= 3'd6;
				end
				else j <= j_sub_1;
			end
		end
		Area_1 : begin
			mult1_a <= x_i_;
			mult1_b <= y_i_next_;
			mult1_start <= 1'b1;
		end
		Area_2 : begin
			if (mult1_complete) begin
				rarea <= addsub1_sum;
				mult1_a <= x_i_next_;
				mult1_b <= y_i_;
				mult1_start <= 1'b1;
			end
		end
		Area_3 : begin
			if (mult1_complete) begin
				rarea <= addsub1_sum;
				i <= i_next;
			end
		end
		Triangle_a_1 : begin
			s <= addsub1_sum;
			mult1_a <= sub2_difference;
			mult1_b <= sub2_difference;
			mult1_start <= 1'b1;
		end
		Triangle_a_2 : begin
			if (mult1_complete) begin
				triangle_temp <= mult1_product[19:0];
				mult1_a <= sub2_difference;
				mult1_b <= sub2_difference;
				mult1_start <= 1'b1;
			end
		end
		Triangle_a_3 : begin
			if (mult1_complete) begin
				triangle_temp <= mult1_product[19:0];
				sqrt1_a <= {addsub1_sum, 2'b00};
				sqrt1_start <= 1'b1;
			end
		end
		Triangle_area_1 : begin
			if (sqrt1_complete) begin
				mult1_a <= (sub2_difference[SUB2_width - 1] ? 0 : sub2_difference);
				mult1_b <= addsub1_sum;
				s <= addsub1_sum;
				mult1_start <= 1'b1;
			end
		end
		Triangle_area_2 : begin
			if (mult1_complete) begin
				sqrt1_a <= mult1_product;
				sqrt1_start <= 1'b1;
			end
		end
		Triangle_area_3 : begin
			if (sqrt1_complete) begin
				triangle_temp[12:0] <= sqrt1_root;
				mult1_a <= (addsub1_sum[ADDSUB1_width - 1] ? 0 : addsub1_sum);
				mult1_b <= (sub2_difference[SUB2_width - 1] ? 0 : sub2_difference);
				mult1_start <= 1'b1;
			end
		end
		Triangle_area_4 : begin
			if (mult1_complete) begin
				sqrt1_a <= mult1_product;
				sqrt1_start <= 1'b1;
			end
		end
		Triangle_area_5 : begin
			if (sqrt1_complete) begin
				mult1_a <= sqrt1_root;
				mult1_b <= triangle_temp[12:0];
				mult1_start <= 1'b1;
			end
		end
		Triangle_area_6 : begin
			if (mult1_complete) begin
				tarea <= addsub1_sum;
				i <= i_next;
			end
		end
		Output : begin
			if (mult1_complete) begin
				valid <= 1'b1;
				is_inside <= (tarea <= rarea[20:1]);
			end
		end
	endcase
end

endmodule

