module JAM (
input CLK,
input RST,
output reg [2:0] W,
output reg [2:0] J,
input [6:0] Cost,
output reg [3:0] MatchCount,
output reg [9:0] MinCost,
output reg Valid );
/* my design */
reg [2:0] state, nxt_state;
localparam Idle = 3'd0;
localparam Begin = 3'd1;
localparam Calculation = 3'd2;
localparam Find_i = 3'd3;
localparam Find_j = 3'd4;
localparam Swap = 3'd5;
localparam Reverse = 3'd6;
localparam Finish = 3'd7;

reg [2:0] p [0:7];

reg [2:0] i;
wire [2:0] i_add_1 = i + 3'd1;
wire i_end = (i == 3'd7);

reg [9:0] sum;
wire [9:0] sum_a_Cost = sum + Cost;
wire sum_a_Cost_gt_MinCost = (sum_a_Cost > MinCost);
wire sum_a_Cost_eq_MinCost = (sum_a_Cost == MinCost); 
wire sum_a_Cost_lt_MinCost = (!sum_a_Cost_gt_MinCost && !sum_a_Cost_eq_MinCost); 

wire calc_end = (sum_a_Cost_gt_MinCost || i_end);

reg [2:0] j, k;
wire [2:0] p_i_ = p[i];
wire [2:0] p_j_ = p[j];
wire [2:0] p_k_ = p[k];
wire [2:0] i_sub_1 = i - 3'd1;
wire i_ok = (p[i_add_1] > p_i_);

always @(*) begin // next state logic
	nxt_state <= state;
	case (state)
		Idle : nxt_state <= Begin;
		Begin : nxt_state <= Calculation;
		Calculation:
			if (calc_end) nxt_state <= Find_i;
		Find_i :
			if (i_ok) nxt_state <= Find_j;
			else if (i == 3'd0) nxt_state <= Finish;
		Find_j :
			if (j == 3'd7) nxt_state <= Swap;
		Swap : nxt_state <= Reverse;
		Reverse : nxt_state <= Begin;
	endcase
end

always @(posedge CLK/* or posedge RST*/) begin // FSM
	if (RST) state <= Idle;
	else state <= nxt_state;
end

always @(*) begin
	W <= i;
	J <= p_i_;
end

always @(posedge CLK) begin
	Valid <= 1'b0;
	case (state)
		Idle : begin
			p[0] <= 3'd0;
			p[1] <= 3'd1;
			p[2] <= 3'd2;
			p[3] <= 3'd3;
			p[4] <= 3'd4;
			p[5] <= 3'd5;
			p[6] <= 3'd6;
			p[7] <= 3'd7;
			MinCost <= 10'h3FF;
			MatchCount <= 4'd0;
		end
		Begin : begin
			i <= 3'd0;
			sum <= 17'h0;
		end
		Calculation: begin
			i <= i_add_1;
			sum <= sum_a_Cost;
			if (calc_end) i <= 3'd6;
			if (i_end) begin
				if (sum_a_Cost_lt_MinCost) begin
					MinCost <= sum_a_Cost;
					MatchCount <= 4'd1;
				end
				else if (sum_a_Cost_eq_MinCost) MatchCount <= MatchCount + 4'd1;
			end
		end
		Find_i : begin
			if (!i_ok) i <= i_sub_1;
			j <= i_add_1;
			k <= i_add_1;
		end
		Find_j : begin
			if (p_j_ > p_i_ && p_j_ < p_k_) k <= j;
			j <= j + 3'd1;
		end
		Swap : begin
			p[i] <= p_k_;
			p[k] <= p_i_;
		end
		Reverse : begin
			case (i)
				3'd5 : begin
					p[6] <= p[7];
					p[7] <= p[6];
				end
				3'd4 : begin
					p[5] <= p[7];
					p[7] <= p[5];
				end
				3'd3 : begin
					p[4] <= p[7];
					p[7] <= p[4];
					p[5] <= p[6];
					p[6] <= p[5];
				end
				3'd2 : begin
					p[3] <= p[7];
					p[7] <= p[3];
					p[4] <= p[6];
					p[6] <= p[4];
				end
				3'd1 : begin
					p[2] <= p[7];
					p[7] <= p[2];
					p[3] <= p[6];
					p[6] <= p[3];
					p[4] <= p[5];
					p[5] <= p[4];
				end
				3'd0 : begin
					p[1] <= p[7];
					p[7] <= p[1];
					p[2] <= p[6];
					p[6] <= p[2];
					p[3] <= p[5];
					p[5] <= p[3];
				end
			endcase
		end
		Finish : begin
			Valid <= 1'b1;
		end
	endcase
end

endmodule

