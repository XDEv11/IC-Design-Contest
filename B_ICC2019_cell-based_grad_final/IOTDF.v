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

reg first_flag;
reg find_flag;
reg [6:0] cnt;
wire cnt_64_is_7 = (cnt[6:4] == 3'h7);
wire cnt_30_is_F = (cnt[3:0] == 4'hF);
wire cnt_is_0 = (cnt == 7'h0);
wire cnt_is_7F = (cnt_64_is_7 && cnt_30_is_F);

reg [127:0] data;
wire [127:0] data_next = {data[119:0], iot_in};
wire data_next_extracted = (128'h6FFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF < data_next &&
data_next < 128'hAFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF);
wire data_next_excluded = (data_next < 128'h7FFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF ||
128'hBFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF < data_next);
wire data_next_gt_res = (data_next > res[127:0]);
wire data_next_lt_res = (data_next < res[127:0]);
wire [130:0] res_add_data_next = res + data_next;

always @(posedge clk/* or posedge rst*/) begin
	if (rst) begin
		first_flag <= 1'b1;
	end
	else begin
		if (in_en) begin
			case (fn_sel)
				3'h6 : begin // PeakMax
					if (first_flag) first_flag <= 1'b0;
				end
				3'h7 : begin // PeakMin
					if (first_flag) first_flag <= 1'b0;
				end
			endcase
		end
	end
end

always @(posedge clk/* or posedge rst*/) begin
	if (rst) begin
		find_flag <= 1'b0;
	end
	else begin
		if (in_en) begin
			case (fn_sel)
				3'h6 : begin // PeakMax
					if (!first_flag && cnt_30_is_F) begin
						if (cnt_64_is_7) begin
							if (data_next_gt_res || find_flag) find_flag <= 1'b0;
						end
						else begin
							if (data_next_gt_res) find_flag <= 1'b1;
						end
					end
				end
				3'h7 : begin // PeakMin
					if (!first_flag && cnt_30_is_F) begin
						if (cnt_64_is_7) begin
							if (data_next_lt_res || find_flag) find_flag <= 1'b0;
						end
						else begin
							if (data_next_lt_res) find_flag <= 1'b1;
						end
					end
				end
			endcase
		end
	end
end

always @(posedge clk/* or posedge rst*/) begin
	if (rst) begin
		cnt <= 7'h0;
	end
	else begin
		if (in_en) begin
			cnt <= cnt + 7'h1;
		end
	end
end

always @(posedge clk) begin
	if (in_en) begin
		data <= data_next;
	end
end

always @(posedge clk) begin
	if (in_en) begin
		case (fn_sel)
			3'h1 : begin // MAX
				if (cnt_is_0) res[127:0] <= 128'h0;
				else if (cnt_30_is_F && data_next_gt_res) res[127:0] <= data_next;
			end
			3'h2 : begin // MIN
				if (cnt_is_0) res[127:0] <= ~128'h0;
				else if (cnt_30_is_F && data_next_lt_res) res[127:0] <= data_next;
			end
			3'h3 : begin // Avg
				if (cnt_is_0) res <= 131'h0;
				else if (cnt_30_is_F) begin
					res <= res_add_data_next;
					if (cnt_64_is_7) res[127:0] <= res_add_data_next[130:3];
				end
			end
			3'h4 : begin // Extract
				if (cnt_30_is_F && data_next_extracted) res[127:0] <= data_next;
			end
			3'h5 : begin // Exclude
				if (cnt_30_is_F && data_next_excluded) res[127:0] <= data_next;
			end
			3'h6 : begin // PeakMax
				if (first_flag) res[127:0] <= 128'h0;
				else if (cnt_30_is_F && data_next_gt_res) res[127:0] <= data_next;
			end
			3'h7 : begin // PeakMin
				if (first_flag) res[127:0] <= ~128'h0;
				else if (cnt_30_is_F && data_next_lt_res) res[127:0] <= data_next;
			end
		endcase
	end
end

always @(posedge clk) begin
	valid <= 1'b0;
	if (in_en) begin
		case (fn_sel)
			3'h1 : begin // MAX
				if (cnt_is_7F) valid <= 1'b1;
			end
			3'h2 : begin // MIN
				if (cnt_is_7F) valid <= 1'b1;
			end
			3'h3 : begin // Avg
				if (cnt_is_7F) valid <= 1'b1;
			end
			3'h4 : begin // Extract
				if (cnt_30_is_F && data_next_extracted) valid <= 1'b1;
			end
			3'h5 : begin // Exclude
				if (cnt_30_is_F) valid <= 1'b1;
			end
			3'h6 : begin // PeakMax
				if (!first_flag && cnt_is_7F && data_next_gt_res || find_flag) valid <= 1'b1;
			end
			3'h7 : begin // PeakMin
				if (!first_flag && cnt_is_7F && data_next_lt_res || find_flag) valid <= 1'b1;
			end
		endcase
	end
end

endmodule
