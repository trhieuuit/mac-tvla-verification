`timescale 1ns / 1ps

module tb_mac_core();

    // 1. Khai báo các tham số và tín hiệu
    parameter DATA_WIDTH = 32;
    parameter NUM_TESTS  = 1000; // Số lần cộng dồn trong 1 chuỗi TVLA

    reg                   clk;
    reg                   rst_n;
    reg                   start_i;
    reg                   done_i;
    reg                   clear_i;
    reg                   data_en_i;
    reg  [DATA_WIDTH-1:0] a_i;
    reg  [DATA_WIDTH-1:0] x_i;
    
    wire [DATA_WIDTH-1:0] y_o;
    wire                  valid_o;

    // 2. Khởi tạo Module (Device Under Test - DUT)
    mac_core #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .start_i    (start_i),
        .done_i     (done_i),
        .clear_i    (clear_i),
        .data_en_i  (data_en_i),
        .a_i        (a_i),
        .x_i        (x_i),
        .y_o        (y_o),
        .valid_o    (valid_o)
    );

    // 3. Tạo Clock (Tần số 100MHz -> Chu kỳ 10ns)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // 4. Khởi tạo lệnh xuất file VCD cho TVLA
    initial begin
        $dumpfile("tvla_mac_core.vcd");
        // Dump toàn bộ tín hiệu của module tb_mac_core và các module con bên trong
        $dumpvars(0, tb_mac_core); 
    end

    // 5. Task chạy 1 chuỗi MAC (Dùng chung cho cả Fixed và Random)
    task run_mac_sequence;
        input is_random; // 0: Dữ liệu Cố định | 1: Dữ liệu Ngẫu nhiên
        integer i;
        begin
            // B1. Xóa thanh ghi tích lũy
            @(negedge clk);
            clear_i = 1;
            @(negedge clk);
            clear_i = 0;

            // B2. Kích hoạt FSM chuyển sang trạng thái ACCUMULATE
            start_i = 1;
            @(negedge clk);
            start_i = 0;

            // B3. Bơm dữ liệu liên tục vào mạch
            for (i = 0; i < NUM_TESTS; i = i + 1) begin
                data_en_i = 1;
                
                if (is_random == 1) begin
                    a_i = $random;
                    x_i = $random;
                end 
                else begin
                    // Dữ liệu cố định: A = 1.0, X = 2.0 (Định dạng Q15.16)
                    a_i = 32'h0001_0000; 
                    x_i = 32'h0002_0000; 
                end
                
                @(negedge clk); // Đợi 1 sườn xuống của clock (để đảm bảo setup time cho sườn lên)
            end

            // B4. Kết thúc chuỗi, báo cho mạch dừng lại
            data_en_i = 0;
            done_i = 1;
            @(negedge clk);
            done_i = 0;

            // B5. Đợi mạch xuất cờ hợp lệ
            wait(valid_o == 1'b1);
            @(negedge clk);
        end
    endtask

    // 6. Kịch bản test chính (Main Flow)
    initial begin
        // Khởi tạo giá trị ban đầu
        rst_n     = 0;
        start_i   = 0;
        done_i    = 0;
        clear_i   = 0;
        data_en_i = 0;
        a_i       = 0;
        x_i       = 0;

        // Reset hệ thống
        #200 rst_n = 1;
        #50;

        $display("==================================================");
        $display("[%0t] BAT DAU TEST TVLA - KHOI MAC CORE", $time);
        
        // --- CHUỖI 1: FIXED DATA (Tập dữ liệu cố định) ---
        $display("[%0t] Dang chay tap du lieu FIXED...", $time);
        run_mac_sequence(0); 
        $display("[%0t] Hoan thanh FIXED. Ket qua Y = %h", $time, y_o);
        
        #50; // Trễ một chút giữa 2 chuỗi để dễ nhìn trên wave

        // --- CHUỖI 2: RANDOM DATA (Tập dữ liệu ngẫu nhiên) ---
        $display("[%0t] Dang chay tap du lieu RANDOM...", $time);
        run_mac_sequence(1);
        $display("[%0t] Hoan thanh RANDOM. Ket qua Y = %h", $time, y_o);
        
        $display("==================================================");
        
        #100;
        $finish; // Kết thúc mô phỏng, đóng file VCD
    end

endmodule