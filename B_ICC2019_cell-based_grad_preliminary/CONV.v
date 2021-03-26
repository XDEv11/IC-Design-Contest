module  CONV(
	input clk,
	input reset,
	output reg busy,
	input ready,

	output reg [11:0] iaddr,
	input [19:0] idata,	

	output reg cwr,
	output reg [11:0] caddr_wr,
	output reg [19:0] cdata_wr,
	
	output reg crd,
	output reg [11:0] caddr_rd,
	input [19:0] cdata_rd,

	output reg [2:0] csel
	);
/* my design */
reg signed [16:0] k_1[0:1], k_2[0:1], k_3[0:1], k_4[0:1], k_5[0:1], k_6[0:1], k_7[0:1], k_8[0:1], k_9[0:1];
reg signed [40:0] k_bias[0:1];
wire presim_aux_wire = 1'b0;
reg presim_aux_reg;
always @(*) begin
	presim_aux_reg <= presim_aux_wire;
	k_1[0] <= 17'h0A89E;
	k_2[0] <= 17'h092D5;
	k_3[0] <= 17'h06D43;
	k_4[0] <= 17'h01004;
	k_5[0] <= 17'h18F71;
	k_6[0] <= 17'h16E54;
	k_7[0] <= 17'h1A6D7;
	k_8[0] <= 17'h1C834;
	k_9[0] <= 17'h1AC19;
	k_bias[0] <= {{8{1'b0}}, 17'h01310, {16{1'b0}}};
	k_1[1] <= 17'h1DB55;
	k_2[1] <= 17'h02992;
	k_3[1] <= 17'h1C994;
	k_4[1] <= 17'h050FD;
	k_5[1] <= 17'h02F20;
	k_6[1] <= 17'h0202D;
	k_7[1] <= 17'h03BD7;
	k_8[1] <= 17'h1D369;
	k_9[1] <= 17'h05E68;
	k_bias[1] <= {{8{1'b1}}, 17'h17295, {16{1'b0}}};
end

reg [4:0] state, nxt_state, save_state, save_state_next;
localparam Idle1		= 5'd0;
localparam Idle2		= 5'd1;
localparam Layer0		= 5'd2;
localparam Layer0_1		= 5'd3;
localparam Layer0_2		= 5'd4;
localparam Layer0_3		= 5'd5;
localparam Layer0_4		= 5'd6;
localparam Layer0_5		= 5'd7;
localparam Layer0_6		= 5'd8;
localparam Layer0_7		= 5'd9;
localparam Layer0_8		= 5'd10;
localparam Layer0_9		= 5'd11;
localparam Layer0_10	= 5'd12;
localparam Layer0_write	= 5'd13;
localparam Mul			= 5'd14;
localparam Layer1_write	= 5'd15;
localparam Layer2_write	= 5'd16;
localparam Finish		= 5'd31;

/* 20-bits * 17-bits signed multiplication (Booth's algorithm) */
reg [16:0] multiplicand;
reg [37:0] product_cur;
reg [37:0] product_nxt;
reg [16:0] product_tmp;
always @(*) begin
	case (product_cur[1:0])
		2'b00, 2'b11 : product_tmp <= product_cur[37:21];
		2'b01 : product_tmp <= product_cur[37:21] + multiplicand;
		2'b10 : product_tmp <= product_cur[37:21] - multiplicand;
	endcase
	product_nxt <= {product_tmp[16], product_tmp, product_cur[20:1]};
end
reg [4:0] mul_iteration;
wire [4:0] mul_iteration_nxt = mul_iteration + 5'd1;
wire mul_end = (mul_iteration == 5'd19);
wire signed [36:0] product = product_cur[37:1];

reg k;
reg [9:0] cnt1;
wire [9:0] cnt1_next = cnt1 + 10'h1;
wire cnt1_end = (cnt1 == 10'h3FF);
reg [1:0] cnt2;
wire [1:0] cnt2_next = cnt2 + 2'h1;
wire cnt2_end = (cnt2 == 2'h3);

wire [11:0] pos = {cnt1[9:5], cnt2[1], cnt1[4:0], cnt2[0]};
wire [5:0] pos_row = pos[11:6];
wire [5:0] pos_col = pos[5:0];
wire pos_is_top = (pos_row == 6'h0);
wire pos_is_down = (pos_row == 6'h3F);
wire pos_is_left = (pos_col == 6'h0);
wire pos_is_right = (pos_col == 6'h3F);
wire pos_is_top_or_left = (pos_is_top || pos_is_left);
wire pos_is_top_or_right = (pos_is_top || pos_is_right);
wire pos_is_down_or_left = (pos_is_down || pos_is_left);
wire pos_is_down_or_right = (pos_is_down || pos_is_right);
wire [11:0] pos_1 = pos - {6'h1, 6'h1};
wire [11:0] pos_2 = pos - {6'h1, 6'h0};
wire [11:0] pos_3 = pos - {6'h0, 6'h3F};
wire [11:0] pos_4 = pos - {6'h0, 6'h1};
wire [11:0] pos_5 = pos;
wire [11:0] pos_6 = pos + {6'h0, 6'h1};
wire [11:0] pos_7 = pos + {6'h0, 6'h3F};
wire [11:0] pos_8 = pos + {6'h1, 6'h0};
wire [11:0] pos_9 = pos + {6'h1, 6'h1};
wire [11:0] pos_next = pos_6;

reg signed [40:0] layer0_result;
wire signed [40:0] layer0_result_a_product = layer0_result + product;
wire [19:0] layer0_result_final = (layer0_result[40] ? 20'h0 : (layer0_result[35:16] + layer0_result[15]));
reg [19:0] layer1_result;

always @(*) begin // next state logic
	nxt_state <= state;
	save_state_next <= 5'dx;
	case (state)
		Idle1 : nxt_state <= Idle2; 
		Idle2 :
			if (ready) nxt_state <= Layer0;
		Layer0 : nxt_state <= Layer0_1;
		Layer0_1 :
			if (pos_is_top_or_left) nxt_state <= Layer0_2;
			else begin
				save_state_next <= Layer0_2;
				nxt_state <= Mul;
			end
		Layer0_2 : 
			if (pos_is_top) nxt_state <= Layer0_3;
			else begin
				save_state_next <= Layer0_3;
				nxt_state <= Mul;
			end
		Layer0_3 : 
			if (pos_is_top_or_right) nxt_state <= Layer0_4;
			else begin
				save_state_next <= Layer0_4;
				nxt_state <= Mul;
			end
		Layer0_4 :
			if (pos_is_left) nxt_state <= Layer0_5;
			else begin
				save_state_next <= Layer0_5;
				nxt_state <= Mul;
			end
		Layer0_5 : begin
			save_state_next <= Layer0_6;
			nxt_state <= Mul;
		end
		Layer0_6 : 
			if (pos_is_right) nxt_state <= Layer0_7;
			else begin
				save_state_next <= Layer0_7;
				nxt_state <= Mul;
			end
		Layer0_7 : 
			if (pos_is_down_or_left) nxt_state <= Layer0_8;
			else begin
				save_state_next <= Layer0_8;
				nxt_state <= Mul;
			end
		Layer0_8 : 
			if (pos_is_down) nxt_state <= Layer0_9;
			else begin
				save_state_next <= Layer0_9;
				nxt_state <= Mul;
			end
		Layer0_9 :
			if (pos_is_down_or_right) nxt_state <= Layer0_10;
			else begin
				save_state_next <= Layer0_10;
				nxt_state <= Mul;
			end
		Layer0_10 : nxt_state <= Layer0_write;
		Layer0_write :
			if (cnt2_end) nxt_state <= Layer1_write;
			else nxt_state <= Layer0;
		Layer1_write : nxt_state <= Layer2_write;
		Layer2_write :
			if (cnt1_end && k == 1'b1) nxt_state <= Finish;
			else nxt_state <= Layer0;
		Mul : begin
			save_state_next <= save_state;
			if (mul_end) nxt_state <= save_state;
		end
	endcase
end

always @(posedge clk/* or posedge reset*/) begin // FSM
	if (reset) state <= Idle1;
	else state <= nxt_state;
end

always @(posedge clk) begin
	/* useless */
	crd <= 1'b0;
	caddr_rd <= 12'hx;
	/*         */
	save_state <= save_state_next;
	csel <= 3'bx;
	cwr <= 1'b0;
	caddr_wr <= 12'hx;
	cdata_wr <= 20'hx;
	/* tricky */
	mul_iteration <= 5'd0;
	product_cur <= 38'dx;
	/*        */
	case (state)
		Idle1 : begin
			busy <= 1'b0;
		end
		Idle2 : begin
			if (ready) busy <= 1'b1;
			k <= 1'b0;
			cnt1 <= 10'h0;
			cnt2 <= 2'h0;
			layer1_result <= 20'h0;
		end
		Layer0 : begin
			iaddr <= pos_1;
		end
		Layer0_1 : begin
			layer0_result <= k_bias[k];
			multiplicand <= k_1[k];
			product_cur[37:21] <= 17'b0;
			product_cur[20:1] <= (pos_is_top_or_left ? 20'b0 : idata);
			product_cur[0] <= 1'b0;
			iaddr <= pos_2;
		end
		Layer0_2 : begin
			layer0_result <= layer0_result_a_product;
			multiplicand <= k_2[k];
			product_cur[37:21] <= 17'b0;
			product_cur[20:1] <= (pos_is_top ? 20'b0 : idata);
			product_cur[0] <= 1'b0;
			iaddr <= pos_3;
		end
		Layer0_3 : begin
			layer0_result <= layer0_result_a_product;
			multiplicand <= k_3[k];
			product_cur[37:21] <= 17'b0;
			product_cur[20:1] <= (pos_is_top_or_right ? 20'b0 : idata);
			product_cur[0] <= 1'b0;
			iaddr <= pos_4;
		end
		Layer0_4 : begin
			layer0_result <= layer0_result_a_product;
			multiplicand <= k_4[k];
			product_cur[37:21] <= 17'b0;
			product_cur[20:1] <= (pos_is_left ? 20'b0 : idata);
			product_cur[0] <= 1'b0;
			iaddr <= pos_5;
		end
		Layer0_5 : begin
			layer0_result <= layer0_result_a_product;
			multiplicand <= k_5[k];
			product_cur[37:21] <= 17'b0;
			product_cur[20:1] <= idata;
			product_cur[0] <= 1'b0;
			iaddr <= pos_6;
		end
		Layer0_6 : begin
			layer0_result <= layer0_result_a_product;
			multiplicand <= k_6[k];
			product_cur[37:21] <= 17'b0;
			product_cur[20:1] <= (pos_is_right ? 20'b0 : idata);
			product_cur[0] <= 1'b0;
			iaddr <= pos_7;
		end
		Layer0_7 : begin
			layer0_result <= layer0_result_a_product;
			multiplicand <= k_7[k];
			product_cur[37:21] <= 17'b0;
			product_cur[20:1] <= (pos_is_down_or_left ? 20'b0 : idata);
			product_cur[0] <= 1'b0;
			iaddr <= pos_8;
		end
		Layer0_8 : begin
			layer0_result <= layer0_result_a_product;
			multiplicand <= k_8[k];
			product_cur[37:21] <= 17'b0;
			product_cur[20:1] <= (pos_is_down ? 20'b0 : idata);
			product_cur[0] <= 1'b0;
			iaddr <= pos_9;
		end
		Layer0_9 : begin
			layer0_result <= layer0_result_a_product;
			multiplicand <= k_9[k];
			product_cur[37:21] <= 17'b0;
			product_cur[20:1] <= (pos_is_down_or_right ? 20'b0 : idata);
			product_cur[0] <= 1'b0;
		end
		Layer0_10 : begin
			layer0_result <= layer0_result_a_product;
		end
		Layer0_write : begin
			csel <= (k ? 3'b010 : 3'b001);
			cwr <= 1'b1;
			caddr_wr <= pos;
			cdata_wr <= layer0_result_final;
			layer1_result <= (layer0_result_final > layer1_result ? layer0_result_final : layer1_result);
			cnt2 <= cnt2_next;
		end
		Mul : begin
			mul_iteration <= mul_iteration_nxt;
			product_cur <= product_nxt;
		end
		Layer1_write : begin
			csel <= (k ? 3'b100 : 3'b011);
			cwr <= 1'b1;
			caddr_wr <= cnt1;
			cdata_wr <= layer1_result;
		end
		Layer2_write : begin
			csel <= 3'b101;
			cwr <= 1'b1;
			caddr_wr <= {cnt1, k};
			cdata_wr <= layer1_result;
			layer1_result <= 20'h0;
			cnt1 <= cnt1_next;
			if (cnt1_end) k <= 1'b1;
		end
		Finish : begin
			busy <= 1'b0;
		end
	endcase
end

endmodule
