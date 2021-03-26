module huffman(clk, reset, gray_valid, gray_data, CNT_valid, CNT1, CNT2, CNT3, CNT4, CNT5, CNT6,
    code_valid, HC1, HC2, HC3, HC4, HC5, HC6, M1, M2, M3, M4, M5, M6);

input clk;
input reset;
input gray_valid;
input [7:0] gray_data;
output reg CNT_valid;
output [7:0] CNT1, CNT2, CNT3, CNT4, CNT5, CNT6;
output reg code_valid;
output [7:0] HC1, HC2, HC3, HC4, HC5, HC6;
output [7:0] M1, M2, M3, M4, M5, M6;
// my design
integer i;

reg [3:0] state, nxt_state;
localparam Idle =        3'd0;
localparam Read =        3'd1;
localparam OutputCNT =   3'd2;
localparam SortingOdd =  3'd3;
localparam SortingEven = 3'd4;
localparam Combine =     3'd5;
localparam OutputHC =    3'd6;

reg [6:0] counter;

reg [7:0] HC [1:6], M [1:6], M_nxt [1:6];
always @(*) begin
	for (i = 1;i <= 6;i = i + 1) M_nxt[i] = {M[i][6:0], 1'b1};
end
reg [2:0] group_Num;
wire [2:0] last = group_Num;
wire [2:0] second_last = group_Num - 3'd1;
reg [7:0] group_CNT [1:6];
reg [6:1] group_member [1:6];

always @(*) begin // next state logic
	nxt_state <= state;
	case (state)
		Idle : nxt_state <= Read;
		Read : if (counter == 7'd100) nxt_state <= OutputCNT;
		OutputCNT : nxt_state <= SortingOdd;
		SortingOdd : nxt_state <= SortingEven;
		SortingEven :
			if ((group_CNT[2] >= group_CNT[3]) && (group_CNT[4] >= group_CNT[5])) nxt_state <= Combine;
			else nxt_state <= SortingOdd;
		Combine : 
			if (group_Num == 3'd2) nxt_state <= OutputHC;
			else nxt_state <= SortingOdd;
		OutputHC : nxt_state <= Idle;
	endcase
end

always @(posedge clk/* or posedge reset*/) begin // FSM
	if (reset) state <= Idle;
	else state <= nxt_state;
end

always @(posedge clk) begin
	CNT_valid <= 0;
	code_valid <= 0;
	case (state)
		Idle : begin
			group_Num <= 3'd6;
			for (i = 1;i <= 6;i = i + 1) begin
				group_CNT[i] <= 8'd0;
				HC[i] <= 8'd0;
				M[i] <= 8'd0;
			end
			group_member[1] <= 6'b000001;
			group_member[2] <= 6'b000010;
			group_member[3] <= 6'b000100;
			group_member[4] <= 6'b001000;
			group_member[5] <= 6'b010000;
			group_member[6] <= 6'b100000;
				
			counter <= 7'd1;
		end
		Read : begin
			if (gray_valid) begin
				case (gray_data)
					8'h01 : group_CNT[1] <= group_CNT[1] + 8'd1;
					8'h02 : group_CNT[2] <= group_CNT[2] + 8'd1;
					8'h03 : group_CNT[3] <= group_CNT[3] + 8'd1;
					8'h04 : group_CNT[4] <= group_CNT[4] + 8'd1;
					8'h05 : group_CNT[5] <= group_CNT[5] + 8'd1;
					8'h06 : group_CNT[6] <= group_CNT[6] + 8'd1;
				endcase
				counter <= counter + 7'd1;
			end
		end
		OutputCNT : begin
			CNT_valid <= 1;
		end
		SortingOdd : begin
			if (group_CNT[1] < group_CNT[2]) begin
				group_CNT[1] <= group_CNT[2];
				group_CNT[2] <= group_CNT[1];
				group_member[1] <= group_member[2];
				group_member[2] <= group_member[1];
			end
			if (group_CNT[3] < group_CNT[4]) begin
				group_CNT[3] <= group_CNT[4];
				group_CNT[4] <= group_CNT[3];
				group_member[3] <= group_member[4];
				group_member[4] <= group_member[3];
			end
			if (group_CNT[5] < group_CNT[6]) begin
				group_CNT[5] <= group_CNT[6];
				group_CNT[6] <= group_CNT[5];
				group_member[5] <= group_member[6];
				group_member[6] <= group_member[5];
			end
		end
		SortingEven : begin
			if (group_CNT[2] < group_CNT[3]) begin
				group_CNT[2] <= group_CNT[3];
				group_CNT[3] <= group_CNT[2];
				group_member[2] <= group_member[3];
				group_member[3] <= group_member[2];
			end
			if (group_CNT[4] < group_CNT[5]) begin
				group_CNT[4] <= group_CNT[5];
				group_CNT[5] <= group_CNT[4];
				group_member[4] <= group_member[5];
				group_member[5] <= group_member[4];
			end
		end
		Combine : begin
			for (i=1;i<=6;i=i+1) begin
				if (group_member[last][i]) begin //code 1
					HC[i] <= HC[i] | (M[i] ^ M_nxt[i]);
					M[i] <= M_nxt[i];
				end
				if (group_member[second_last][i]) begin //code 0
					M[i] <= M_nxt[i];
				end
			end
			group_Num <= group_Num - 3'd1;
			group_CNT[second_last] <= group_CNT[second_last] + group_CNT[last];
			group_member[second_last] <= group_member[second_last] | group_member[last];
			//group_CNT[last] <= 0;
			//group_member[last] <= 6'b000000;
		end
		OutputHC : begin
			code_valid <= 1;
		end
	endcase
end

assign CNT1 = group_CNT[1];
assign CNT2 = group_CNT[2];
assign CNT3 = group_CNT[3];
assign CNT4 = group_CNT[4];
assign CNT5 = group_CNT[5];
assign CNT6 = group_CNT[6];
assign HC1 = HC[1];
assign HC2 = HC[2];
assign HC3 = HC[3];
assign HC4 = HC[4];
assign HC5 = HC[5];
assign HC6 = HC[6];
assign M1 = M[1];
assign M2 = M[2];
assign M3 = M[3];
assign M4 = M[4];
assign M5 = M[5];
assign M6 = M[6];

endmodule

