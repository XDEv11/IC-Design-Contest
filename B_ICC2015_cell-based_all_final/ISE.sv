`timescale 1ns/10ps
module ISE( clk, reset, image_in_index, pixel_in, busy, out_valid, color_index, image_out_index);
input           clk;
input           reset;
input   [4:0]   image_in_index;
input   [23:0]  pixel_in;
output          busy;
output          out_valid;
output  [1:0]   color_index;
output  [4:0]   image_out_index;
//***my design***//
//reg          busy;
assign busy = 1'b0;
reg          out_valid;
reg  [1:0]   color_index;
reg  [4:0]   image_out_index;

wire [7:0] pixel_in_R = pixel_in[23:16];
wire [7:0] pixel_in_G = pixel_in[15:8];
wire [7:0] pixel_in_B = pixel_in[7:0];

reg put_flag;

reg [13:0] pixel_cnt;
wire first_pixel = (pixel_cnt == 14'h0);
wire last_pixel = (pixel_cnt == 14'h3FFF);
reg [4:0] image_index;
reg [14:0] R_cnt, G_cnt, B_cnt;
reg [21:0] R_mag, G_mag, B_mag;

reg [14:0] R_cnt_next, G_cnt_next, B_cnt_next;
reg [21:0] R_mag_next, G_mag_next, B_mag_next;
always @(*) begin
	R_cnt_next <= first_pixel ? 15'h0 : R_cnt;
	G_cnt_next <= first_pixel ? 15'h0 : G_cnt;
	B_cnt_next <= first_pixel ? 15'h0 : B_cnt;
	R_mag_next <= first_pixel ? 22'h0 : R_mag;
	G_mag_next <= first_pixel ? 22'h0 : G_mag;
	B_mag_next <= first_pixel ? 22'h0 : B_mag;
	if (pixel_in_R >= pixel_in_G && pixel_in_R >= pixel_in_B) begin
		R_cnt_next <= first_pixel ? 15'h1 : R_cnt + 15'h1;
		R_mag_next <= first_pixel ? pixel_in_R : R_mag + pixel_in_R;
	end
	else if (pixel_in_G >= pixel_in_B) begin
		G_cnt_next <= first_pixel ? 15'h1 : G_cnt + 15'h1;
		G_mag_next <= first_pixel ? pixel_in_G : G_mag + pixel_in_G;
	end
	else begin
		B_cnt_next <= first_pixel ? 15'h1 : B_cnt + 15'h1;
		B_mag_next <= first_pixel ? pixel_in_B : B_mag + pixel_in_B;
	end
end

always @(posedge clk/* or posedge reset*/) begin
	if (reset) pixel_cnt <= 14'h0;
	else pixel_cnt <= pixel_cnt + 14'h1;
end

always @(posedge clk) begin
	image_index <= image_in_index;
	R_cnt <= R_cnt_next;
	G_cnt <= G_cnt_next;
	B_cnt <= B_cnt_next;
	R_mag <= R_mag_next;
	G_mag <= G_mag_next;
	B_mag <= B_mag_next;
	put_flag <= 1'b0;
	if (last_pixel) put_flag <= 1'b1;
end

/*	*	*	*	*	*	*	*	*	*/
reg [2:0] state, nxt_state;
localparam Init		= 3'd0;
localparam Idle		= 3'd1;
localparam Compare1	= 3'd2;
localparam Mul		= 3'd3;
localparam Compare2	= 3'd4;
localparam Loop		= 3'd5;
localparam Output	= 3'd6;
localparam Finish	= 3'd7;

reg finish_flag;

reg [4:0] indexs [0:31];
reg [1:0] colors [0:31];
reg [14:0] cnts [0:31];
reg [21:0] mags [0:31];

reg [4:0] i;
wire [4:0] indexs_i_ =  indexs[i];
wire [1:0] colors_i_ = colors[i];
wire [14:0] cnts_i_ = cnts[i];
wire [21:0] mags_i_ = mags[i];
wire [4:0] i_add_1 = i + 5'd1;
wire [4:0] i_sub_1 = i - 5'd1;
wire [4:0] indexs_i_sub_1_ = indexs[i_sub_1];
wire [1:0] colors_i_sub_1_ = colors[i_sub_1];
wire [14:0] cnts_i_sub_1_ = cnts[i_sub_1];
wire [21:0] mags_i_sub_1_ = mags[i_sub_1];

wire cmp1_gt = (colors_i_sub_1_ > colors_i_);
wire cmp1_eq = (colors_i_sub_1_ == colors_i_);

reg [14:0] multiplicand1;
reg [36:0] product_cur1;
reg [36:0] product_nxt1;
reg [15:0] product_tmp1;
always @(*) begin
	case (product_cur1[0])
		1'b0 : product_tmp1 <= product_cur1[36:22];
		1'b1 : product_tmp1 <= product_cur1[36:22] + multiplicand1;
	endcase
	product_nxt1 <= {product_tmp1, product_cur1[21:1]};
end
reg [14:0] multiplicand2;
reg [36:0] product_cur2;
reg [36:0] product_nxt2;
reg [15:0] product_tmp2;
always @(*) begin
	case (product_cur2[0])
		1'b0 : product_tmp2 <= product_cur2[36:22];
		1'b1 : product_tmp2 <= product_cur2[36:22] + multiplicand2;
	endcase
	product_nxt2 <= {product_tmp2, product_cur2[21:1]};
end
reg [4:0] mul_iteration;
wire [4:0] mul_iteration_nxt = mul_iteration + 5'd1;
wire mul_end = (mul_iteration == 5'd21);
wire cmp2_gt = (product_cur1 > product_cur2);

always @(*) begin // next state logic
	nxt_state <= state;
	case (state)
		Init : nxt_state <= Idle;
		Idle : begin
			if (put_flag) nxt_state <= Compare1;
			if (finish_flag) nxt_state <= Output;
		end
		Compare1 :
			if (cmp1_gt) nxt_state <= Loop;
			else if (cmp1_eq) nxt_state <= Mul;
			else nxt_state <= Idle;
		Mul :
			if (mul_end) nxt_state <= Compare2;
		Compare2 :
			if (cmp2_gt) nxt_state <= Loop;
			else nxt_state <= Idle;
		Loop :
			if (i == 5'd1) nxt_state <= Idle;
			else nxt_state <= Compare1;
		Output :
			if (i == 5'd31) nxt_state <= Finish;
	endcase
end

always @(posedge clk/* or posedge reset*/) begin // FSM
	if (reset) state <= Init;
	else state <= nxt_state;
end

always @(posedge clk) begin
	mul_iteration <= 4'd0;
	product_cur1 <= 36'hx;
	product_cur2 <= 36'hx;
	out_valid <= 1'b0;
	case (state)
		Init : begin
			colors[31] <= 2'd0;
			finish_flag <= 1'b0;
		end
		Idle : begin
			if (put_flag) begin
				indexs[0:30] <= indexs[1:31];
				colors[0:30] <= colors[1:31];
				cnts[0:30] <= cnts[1:31];
				mags[0:30] <= mags[1:31];
				indexs[31] <= image_index;
				if (R_cnt >= G_cnt && R_cnt >= B_cnt) begin
					colors[31] <= 2'd1;
					cnts[31] <= R_cnt;
					mags[31] <= R_mag;
				end
				else if (G_cnt>= B_cnt) begin
					colors[31] <= 2'd2;
					cnts[31] <= G_cnt;
					mags[31] <= G_mag;
				end
				else begin
					colors[31] <= 2'd3;
					cnts[31] <= B_cnt;
					mags[31] <= B_mag;
				end
				if (image_index == 5'd31) finish_flag <= 1'b1;
				i <= 5'd31;
			end
			else /*if (finish_flag)*/ i <= 5'd0;
		end
		Compare1 : begin
			multiplicand1 <= cnts_i_;
			product_cur1 <= {15'b0, mags_i_sub_1_};
			multiplicand2 <= cnts_i_sub_1_;
			product_cur2 <= {15'b0, mags_i_};
		end
		Mul : begin
			mul_iteration <= mul_iteration_nxt;
			product_cur1 <= product_nxt1;
			product_cur2 <= product_nxt2;
		end
		Loop : begin
			indexs[i_sub_1] <= indexs_i_;
			indexs[i] <= indexs_i_sub_1_;
			colors[i_sub_1] <= colors_i_;
			colors[i] <= colors_i_sub_1_;
			cnts[i_sub_1] <= cnts_i_;
			cnts[i] <= cnts_i_sub_1_;
			mags[i_sub_1] <= mags_i_;
			mags[i] <= mags_i_sub_1_;
			i <= i_sub_1;
		end
		Output : begin
			out_valid <= 1'b1;
			color_index <= colors_i_ - 2'd1;
			image_out_index <= indexs_i_;
			i <= i_add_1;
		end
	endcase
end

endmodule
