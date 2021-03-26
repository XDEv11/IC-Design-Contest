`timescale 1ns/10ps
module IOTDF( clk, rst, in_en, iot_in, fn_sel, busy, valid, iot_out);
input          clk;
input          rst;
input          in_en;
input  [7:0]   iot_in;
input  [2:0]   fn_sel;
output         busy;
output         valid;
output [127:0] iot_out;
/* my design */
//reg busy;
assign busy = 1'b0;
reg valid;
//reg [127:0] iot_out;
reg [130:0] res;
assign iot_out = res[127:0];

reg [6:0] cnt;
reg [127:0] data;
wire [127:0] data_next = {data[119:0], iot_in};
wire data_next_gt_res = (data_next > res[127:0]);
wire data_next_lt_res = (data_next < res[127:0]);
wire [130:0] res_add_data_next = res + data_next;

reg first_flag;
reg find_flag;

always @(posedge clk/* or posedge rst*/) begin
	if (rst) begin
		cnt <= 7'h0;
		first_flag <= 1'b1;
		find_flag <= 1'b0;
	end
	else begin
		valid <= 1'b0;
		if (in_en) begin
			data <= data_next;
			cnt <= cnt + 7'h1;
			case (fn_sel)
				3'h1 : begin // MAX
					if (cnt == 7'h0) res[127:0] <= 128'h0;
					if (cnt[3:0] == 4'hF && data_next_gt_res) res[127:0] <= data_next;
					if (cnt == 7'h7F) valid <= 1'b1;
				end
				3'h2 : begin // MIN
					if (cnt == 7'h0) res[127:0] <= ~128'h0;
					if (cnt[3:0] == 4'hF && data_next_lt_res) res[127:0] <= data_next;
					if (cnt == 7'h7F) valid <= 1'b1;
				end
				3'h3 : begin // Avg
					if (cnt == 7'h0) res <= 131'h0;
					if (cnt[3:0] == 4'hF) begin
						res <= res_add_data_next;
						if (cnt[6:4] == 3'h7) begin
							res[127:0] <= res_add_data_next[130:3];
							valid <= 1'b1;
						end
					end
				end
				3'h4 : begin // Extract
					if (cnt[3:0] == 4'hF) begin
						if (128'h6FFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF < data_next &&
						data_next < 128'hAFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF) begin
							res[127:0] <= data_next;
							valid <= 1'b1;
						end
					end
				end
				3'h5 : begin // Exclude
					if (cnt[3:0] == 4'hF) begin
						if (data_next < 128'h7FFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF ||
						128'hBFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF < data_next) begin
							res[127:0] <= data_next;
							valid <= 1'b1;
						end
					end
				end
				3'h6 : begin // PeakMax
					if (first_flag) begin
						first_flag <= 1'b0;
						res[127:0] <= 128'h0;
					end
					else begin
						if (cnt[3:0] == 4'hF)
							if (cnt[6:4] == 3'h7) begin
								if (data_next_gt_res) res[127:0] <= data_next;
								if (data_next_gt_res || find_flag) begin
									find_flag <= 1'b0;
									valid <= 1'b1;
								end
							end
							else begin
								if (data_next_gt_res) begin
									res[127:0] <= data_next;
									find_flag <= 1'b1;
								end
							end
					end
				end
				3'h7 : begin // PeakMin
					if (first_flag) begin
						first_flag <= 1'b0;
						res[127:0] <= ~128'h0;
					end
					else begin
						if (cnt[3:0] == 4'hF)
							if (cnt[6:4] == 3'h7) begin
								if (data_next_lt_res) res[127:0] <= data_next;
								if (data_next_lt_res || find_flag) begin
									find_flag <= 1'b0;
									valid <= 1'b1;
								end
							end
							else begin
								if (data_next_lt_res) begin
									res[127:0] <= data_next;
									find_flag <= 1'b1;
								end
							end
					end
				end
			endcase
		end
	end
end

endmodule
