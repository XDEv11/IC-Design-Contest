module DT (
	input clk, 
	input reset,
	output reg done,
	output reg sti_rd,
	output reg [9:0] sti_addr,
	input [15:0] sti_di,
	output reg res_wr,
	output reg res_rd,
	output reg [13:0] res_addr,
	output reg [7:0] res_do,
	input [7:0] res_di
);
/* my design */
reg [3:0] state, nxt_state;
localparam Idle	= 4'h0;
localparam F		= 4'h1;
localparam Fnw		= 4'h2;
localparam Fn		= 4'h3;
localparam Fne		= 4'h4;
localparam Fwrite	= 4'h5;
localparam B		= 4'h6;
localparam Bse		= 4'h7;
localparam Bs		= 4'h8;
localparam Bsw		= 4'h9;
localparam Bc		= 4'hA;
localparam Bwrite	= 4'hB;
localparam Finish	= 4'hC;

reg [13:0] pos;
wire [6:0] pos_row	= pos[13:7];
wire [6:0] pos_col	= pos[6:0];
wire [13:0] pos_nw	= pos - {7'h1, 7'h1};
wire [13:0] pos_n	= pos - {7'h1, 7'h0};
wire [13:0] pos_ne	= pos - {7'h0, 7'h7F};
wire [13:0] pos_w	= pos - {7'h0, 7'h1};
wire [13:0] pos_e	= pos + {7'h0, 7'h1};
wire [13:0] pos_sw	= pos + {7'h0, 7'h7F};
wire [13:0] pos_s	= pos + {7'h1, 7'h0};
wire [13:0] pos_se	= pos + {7'h1, 7'h1};

reg pixel;
reg [7:0] data [0:4];
reg prev_is_obj;
wire [7:0] _mn1		= (data[0] < data[1] ? data[0] : data[1]);
wire [7:0] _mn2		= (data[2] < data[3] ? data[2] : data[3]);
wire [7:0] F_res	= (_mn1 < _mn2 ? _mn1 : _mn2) + 8'h1;
wire [7:0] B_res	= (F_res < data[4] ? F_res : data[4]);

always @(*) begin // next state logic
	nxt_state <= state;
	case (state)
		Idle : nxt_state <= F;
		F :
			if (pos_row == 7'h7F) nxt_state <= B;
			else if (pixel == 1'b1) nxt_state <= (prev_is_obj == 1'b1 ? Fne : Fnw);
		Fnw : nxt_state <= Fn;
		Fn : nxt_state <= Fne;
		Fne : nxt_state <= Fwrite;
		Fwrite : nxt_state <= F;
		B :
			if (pos_row == 7'h0) nxt_state <= Finish;
			else if (pixel == 1'b1) nxt_state <= (prev_is_obj == 1'b1 ? Bsw : Bse);
		Bse : nxt_state <= Bs;
		Bs : nxt_state <= Bsw;
		Bsw : nxt_state <= Bc;
		Bc : nxt_state <= Bwrite;
		Bwrite : nxt_state <= B;
	endcase
end

always @(posedge clk/* or negedge reset*/) begin // FSM
	if (reset == 1'b0) state <= Idle;
	else state <= nxt_state;
end

always @(*) begin
	sti_rd <= 1'b1;
	sti_addr <= pos[13:4];
	pixel <= sti_di[~pos_col[3:0]];
	res_rd <= ~res_wr;
end

always @(posedge clk) begin
	res_wr <= 1'b0;
	res_addr <= 14'hx;
	res_do <= 8'hx;
	prev_is_obj <= 1'bx;
	done <= 1'b0;
	case (state)
		Idle : begin
			pos <= {7'h1, 7'h1};
		end
		F : begin
			if (pixel == 1'b1) begin
				res_addr <= (prev_is_obj == 1'b1 ? pos_ne : pos_nw);
			end
			else begin
				prev_is_obj <= 1'b0;
				pos <= pos_e;
			end
		end
		Fnw : begin
			data[0] <= res_di;
			data[3] <= 8'h0;
			res_addr <= pos_n;
		end
		Fn  : begin
			data[1] <= res_di;
			res_addr <= pos_ne;
		end
		Fne : begin
			data[2] <= res_di;
		end
		Fwrite : begin
			res_wr <= 1'b1;
			res_addr <= pos;
			res_do <= F_res;

			data[0] <= data[1]; 
			data[1] <= data[2]; 
			data[3] <= F_res;
			prev_is_obj <= 1'b1;
			pos <= pos_e;
		end
		B : begin
			if (pixel == 1'b1) begin
				res_addr <= (prev_is_obj == 1'b1 ? pos_sw : pos_se);
			end
			else begin
				prev_is_obj <= 1'b0;
				pos <= pos_w;
			end
		end
		Bse : begin
			data[0] <= res_di;
			data[3] <= 8'h0;
			res_addr <= pos_s;
		end
		Bs : begin
			data[1] <= res_di;
			res_addr <= pos_sw;
		end
		Bsw : begin
			data[2] <= res_di;
			res_addr <= pos;
		end
		Bc : begin
			data[4] <= res_di;
		end
		Bwrite : begin
			res_wr <= 1'b1;
			res_addr <= pos;
			res_do <= B_res;

			data[0] <= data[1]; 
			data[1] <= data[2]; 
			data[3] <= B_res;
			prev_is_obj <= 1'b1;
			pos <= pos_w;
		end
		Finish : done <= 1'b1;
	endcase
end

endmodule
