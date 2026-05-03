`timescale 1ns / 1ps

module tb_mac_core();

    // 1. Khai báo các tham số và tín hiệu
    parameter DATA_WIDTH = 32;
    parameter NUM_TESTS  = 2000; // TỔNG SỐ MẪU: 2000 lần tính toán đan xen

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

    // Biến quản lý file nhãn (Label)
    integer fd;         
    reg current_label;  // 0: Fixed, 1: Random

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
        $dumpvars(0, tb_mac_core); 
    end

    // 5. Task chạy chuỗi MAC ĐAN XEN NGẪU NHIÊN (Interleaved)
    task run_mac_interleaved;
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

            // B3. Nạp dữ liệu 2000 lần
            for (i = 0; i < NUM_TESTS; i = i + 1) begin
                data_en_i = 1;
                
                //  Lấy bit cuối của $random (0 hoặc 1)
                current_label = $random & 1'b1; 
                
                // Ghi nhãn ra file text 
                $fdisplay(fd, "%0d", current_label);
                
                if (current_label == 1'b1) begin
                    // Nhãn 1 -> Dữ liệu Ngẫu nhiên
                    a_i = $random;
                    x_i = $random;
                end 
                else begin
                    // Nhãn 0 -> Dữ liệu Cố định (Corner Cases)
                    a_i = 32'h5555_5555; 
                    x_i = 32'hFFFF_FFFF; 
                end
                
                @(negedge clk); // Đợi 1 sườn xuống
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
        $display("[%0t] BAT DAU TEST TVLA - PHUONG PHAP INTERLEAVED", $time);
        
        // Mở file txt để chuẩn bị ghi nhãn
        fd = $fopen("tvla_labels.txt", "w");
        if (fd == 0) begin
            $display("LOI: Khong the tao file tvla_labels.txt");
            $finish;
        end

        // Gọi Task chạy 2000 mẫu đan xen
        $display("[%0t] Dang bom du lieu va ghi Label...", $time);
        run_mac_interleaved(); 
        
        $display("[%0t] Hoan thanh. Ket qua Y = %h", $time, y_o);
        $display("==================================================");
        
        // Đóng file text
        $fclose(fd);
        
        #100;
        $finish; // Kết thúc mô phỏng
    end

endmodule