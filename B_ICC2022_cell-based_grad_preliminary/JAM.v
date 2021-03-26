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
reg [3:0] state, nxt_state;
localparam Idle		= 4'd8;
localparam S0		= 4'd0;
localparam S1		= 4'd1;
localparam S2		= 4'd2;
localparam S3		= 4'd3;
localparam S4		= 4'd4;
localparam S5		= 4'd5;
localparam S6		= 4'd6;
localparam S7		= 4'd7;
localparam Finish	= 4'd9;

reg [2:0] p [0:7], next_p [0:7];

reg [2:0] _i, i;
reg _i_ok, i_ok;
always @(*) begin
	_i <= 3'dx;
	_i_ok <= 1'b1;
	if (next_p[7] > next_p[6]) _i <= 3'd6;
	else if (next_p[6] > next_p[5]) _i <= 3'd5;
	else if (next_p[5] > next_p[4]) _i <= 3'd4;
	else if (next_p[4] > next_p[3]) _i <= 3'd3;
	else if (next_p[3] > next_p[2]) _i <= 3'd2;
	else if (next_p[2] > next_p[1]) _i <= 3'd1;
	else if (next_p[1] > next_p[0]) _i <= 3'd0;
	else _i_ok <= 1'b0;
end

reg [2:0] j, k, j_next, k_next;
always @(*) begin
	j_next <= j;
	k_next <= k;
	if (k) begin
		if (next_p[k] > next_p[i] && next_p[k] < next_p[j]) j_next <= k;
		k_next <= k + 3'd1;
	end
end

reg [2:0] next_p_reversed [0:7];
always @(*) begin
	next_p_reversed[0] <= next_p[0];
	next_p_reversed[1] <= next_p[1];
	next_p_reversed[2] <= next_p[2];
	next_p_reversed[3] <= next_p[3];
	next_p_reversed[4] <= next_p[4];
	next_p_reversed[5] <= next_p[5];
	next_p_reversed[6] <= next_p[6];
	next_p_reversed[7] <= next_p[7];
	case (i)
		3'd5 : begin
			next_p_reversed[6] <= next_p[7];
			next_p_reversed[7] <= next_p[6];
		end
		3'd4 : begin
			next_p_reversed[5] <= next_p[7];
			next_p_reversed[7] <= next_p[5];
		end
		3'd3 : begin
			next_p_reversed[4] <= next_p[7];
			next_p_reversed[7] <= next_p[4];
			next_p_reversed[5] <= next_p[6];
			next_p_reversed[6] <= next_p[5];
		end
		3'd2 : begin
			next_p_reversed[3] <= next_p[7];
			next_p_reversed[7] <= next_p[3];
			next_p_reversed[4] <= next_p[6];
			next_p_reversed[6] <= next_p[4];
		end
		3'd1 : begin
			next_p_reversed[2] <= next_p[7];
			next_p_reversed[7] <= next_p[2];
			next_p_reversed[3] <= next_p[6];
			next_p_reversed[6] <= next_p[3];
			next_p_reversed[4] <= next_p[5];
			next_p_reversed[5] <= next_p[4];
		end
		3'd0 : begin
			next_p_reversed[1] <= next_p[7];
			next_p_reversed[7] <= next_p[1];
			next_p_reversed[2] <= next_p[6];
			next_p_reversed[6] <= next_p[2];
			next_p_reversed[3] <= next_p[5];
			next_p_reversed[5] <= next_p[3];
		end
	endcase
end

reg [9:0] sum;
wire [9:0] sum_a_Cost = sum + Cost;

always @(*) begin // next state logic
	nxt_state <= state;
	case (state)
		Idle : nxt_state <= S0;
		S0 :
			if (i_ok) nxt_state <= S1;
			else nxt_state <= Finish;
		S1 : nxt_state <= S2;
		S2 : nxt_state <= S3;
		S3 : nxt_state <= S4;
		S4 : nxt_state <= S5;
		S5 : nxt_state <= S6;
		S6 : nxt_state <= S7;
		S7 : nxt_state <= S0;
	endcase
end

always @(posedge CLK/* or posedge RST*/) begin // FSM
	if (RST) state <= Idle;
	else state <= nxt_state;
end

always @(*) begin
	W <= 3'dx;
	case (state)
		Idle, S7 : W <= 3'd0;
		S0 : W <= 3'd1;
		S1 : W <= 3'd2;
		S2 : W <= 3'd3;
		S3 : W <= 3'd4;
		S4 : W <= 3'd5;
		S5 : W <= 3'd6;
		S6 : W <= 3'd7;
	endcase
	J <= 3'dx;
	case (state)
		Idle : J <= 3'd0;
		S7 : J <= p[0];
		S0 : J <= p[1];
		S1 : J <= p[2];
		S2 : J <= p[3];
		S3 : J <= p[4];
		S4 : J <= p[5];
		S5 : J <= p[6];
		S6 : J <= p[7];
	endcase
end

always @(posedge CLK) begin // stage 1 (next permutation)
	/* tricky */
	j <= 3'dx;
	k <= 3'dx;
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
			next_p[0] <= 3'd0;
			next_p[1] <= 3'd1;
			next_p[2] <= 3'd2;
			next_p[3] <= 3'd3;
			next_p[4] <= 3'd4;
			next_p[5] <= 3'd5;
			next_p[6] <= 3'd6;
			next_p[7] <= 3'd7;
			i_ok <= 1'b1;
		end
		S0 : begin
			i <= _i;
			i_ok <= _i_ok;
			j <= _i + 3'd1;
			k <= _i + 3'd2;
		end
		S1 : begin
			j <= j_next;
			k <= k_next;
		end
		S2 : begin
			j <= j_next;
			k <= k_next;
		end
		S3 : begin
			j <= j_next;
			k <= k_next;
		end
		S4 : begin
			j <= j_next;
			k <= k_next;
		end
		S5 : begin
			j <= j_next;
			k <= k_next;
		end
		S6 : begin
			next_p[i] <= next_p[j_next];
			next_p[j_next] <= next_p[i];
		end
		S7 : begin
			next_p[0] <= next_p_reversed[0];
			next_p[1] <= next_p_reversed[1];
			next_p[2] <= next_p_reversed[2];
			next_p[3] <= next_p_reversed[3];
			next_p[4] <= next_p_reversed[4];
			next_p[5] <= next_p_reversed[5];
			next_p[6] <= next_p_reversed[6];
			next_p[7] <= next_p_reversed[7];
			p[0] <= next_p_reversed[0];
			p[1] <= next_p_reversed[1];
			p[2] <= next_p_reversed[2];
			p[3] <= next_p_reversed[3];
			p[4] <= next_p_reversed[4];
			p[5] <= next_p_reversed[5];
			p[6] <= next_p_reversed[6];
			p[7] <= next_p_reversed[7];
		end
	endcase
end

always @(posedge CLK) begin // stage 2 (Calculation)
	Valid <= 1'b0;
	/* tricky */
	sum <= 10'hx;
	case (state)
		Idle : begin
			MinCost <= 10'h3FF;
			sum <= 10'h3FF;
		end
		S0 : begin
			if (sum < MinCost) begin
				MinCost <= sum;
				MatchCount <= 4'd1;
			end
			else if (sum == MinCost) MatchCount <= MatchCount + 4'd1;
			sum <= Cost;
		end
		S1 : begin
			sum <= sum_a_Cost;
		end
		S2 : begin
			sum <= sum_a_Cost;
		end
		S3 : begin
			sum <= sum_a_Cost;
		end
		S4 : begin
			sum <= sum_a_Cost;
		end
		S5 : begin
			sum <= sum_a_Cost;
		end
		S6 : begin
			sum <= sum_a_Cost;
		end
		S7 : begin
			sum <= sum_a_Cost;
		end
		Finish : begin
			Valid <= 1'b1;
		end
	endcase
end

endmodule
