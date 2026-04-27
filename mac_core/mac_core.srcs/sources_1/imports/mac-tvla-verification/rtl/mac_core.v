module mac_core # (
    parameter DATA_WIDTH = 32
)(
    input  wire                   clk,
    input  wire                   rst_n,      
    input  wire                   start_i,    // Chuyển FSM từ IDLE sang ACCUMULATE
    input  wire                   done_i,     // Báo hiệu kết thúc chuỗi MAC, chuyển sang WAIT_DONE
    input  wire                   clear_i,    // Xóa thanh ghi tích lũy về 0
    input  wire                   data_en_i,  // Cờ báo hiệu (A, X) hợp lệ để thực hiện cộng dồn
    input  wire [DATA_WIDTH-1:0]  a_i,        // Q15.16
    input  wire [DATA_WIDTH-1:0]  x_i,        // Q15.16
    // Đã loại bỏ b_i
    output wire [DATA_WIDTH-1:0]  y_o,       
    output wire                   valid_o     // Bật mức 1 khi toàn bộ chuỗi đã tính xong
);

    // FSM States
    localparam S_IDLE        = 2'd0;
    localparam S_ACCUMULATE  = 2'd1; // Đổi tên để phản ánh đúng chức năng
    localparam S_WAIT_DONE   = 2'd2;
    
    wire [63:0] mul_full_w;       
    wire [31:0] mul_truncated_w;  
    wire [31:0] mac_sum_w;       
  
    reg [1:0]  state_curr_r;
    reg [1:0]  state_next_r;
    reg [31:0] y_res_r;
    reg        valid_r;

    // 1. CurrentStateGen
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state_curr_r <= S_IDLE;
        else
            state_curr_r <= state_next_r;
    end

    // 2. NextStateGen
    always @(*) begin
        case (state_curr_r)
            S_IDLE: begin
                if (start_i)
                    state_next_r = S_ACCUMULATE;
                else
                    state_next_r = S_IDLE;
            end
            S_ACCUMULATE: begin
                // Ở trạng thái này, FSM đứng chờ và lặp lại liên tục.
                // Chỉ thoát ra WAIT_DONE khi có tín hiệu done_i.
                if (done_i)
                    state_next_r = S_WAIT_DONE;
                else
                    state_next_r = S_ACCUMULATE;
            end
            S_WAIT_DONE: begin
                // Thoát về IDLE khi hạ cờ done_i xuống 0
                if (!done_i)
                    state_next_r = S_IDLE;
                else
                    state_next_r = S_WAIT_DONE;
            end
            default: state_next_r = S_IDLE;
        endcase
    end

    // 3. Multiply Logic & Hồi tiếp (Feedback)
    assign mul_full_w      = $signed(a_i) * $signed(x_i);           // Q15.16 * Q15.16 = Q30.32
    assign mul_truncated_w = mul_full_w[47:16];                     
    
    // ĐIỂM CỐT LÕI: Lấy y_res_r cộng ngược trở lại
    assign mac_sum_w       = mul_truncated_w + y_res_r;             

    assign y_o             = y_res_r;
    assign valid_o         = valid_r;

    // 4. OutputGen
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            y_res_r <= 32'sd0;
            valid_r <= 1'b0;
        end 
        else if (clear_i) begin
            // Xóa thanh ghi trước khi chạy 1 lượt tính MAC mới
            y_res_r <= 32'sd0;
            valid_r <= 1'b0;
        end
        else begin
            case (state_curr_r)
                S_IDLE: begin
                    valid_r <= 1'b0;
                    y_res_r <= y_res_r; // Giữ nguyên kết quả cũ
                end
                S_ACCUMULATE: begin
                    // CHỈ lật bit thanh ghi (cộng dồn) nếu có tín hiệu data_en_i
                    if (data_en_i) begin
                        y_res_r <= mac_sum_w;
                    end
                    valid_r <= 1'b0; // Đang tính toán chuỗi, chưa xuất kết quả cuối cùng
                end
                S_WAIT_DONE: begin
                    valid_r <= 1'b1;    // Báo hiệu kết quả y_o đã sẵn sàng để đọc
                    y_res_r <= y_res_r;
                end
                default: begin
                    valid_r <= 1'b0;
                    y_res_r <= 32'sd0;
                end
            endcase
        end
    end

endmodule