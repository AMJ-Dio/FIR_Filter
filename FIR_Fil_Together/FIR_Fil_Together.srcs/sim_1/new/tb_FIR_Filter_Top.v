`timescale 1ns / 1ps

module tb_FIR_Filter_Top_Module();

    // Parameters
    parameter RAM_WIDTH = 64;
    parameter LEN_WIDTH = 16;
    parameter Tap_Num = RAM_WIDTH / LEN_WIDTH;

    // Signals
    reg                      clk;
    reg                      rst_n;

    // MMIO
    reg                      start;
    reg                      Reset;

    // Filter Coeffs AXI-Stream
    reg                      AXS_S_fil_vld;
    wire                     AXS_S_fil_rdy;
    reg  [RAM_WIDTH-1:0]     AXS_S_fil_data;
    reg                      AXS_S_fil_last;

    // Source Data AXI-Stream
    reg                      AXS_S_src_vld;
    wire                     AXS_S_src_rdy;
    reg  [RAM_WIDTH-1:0]     AXS_S_src_data;
    reg                      AXS_S_src_last;

    // Output Result AXI-Stream
    wire                     AXS_M_psum_vld;
    reg                      AXS_M_psum_rdy;
    wire [RAM_WIDTH-1:0]     AXS_M_psum_data;
    wire                     AXS_M_psum_last;

    // Status
    wire                     busy;
    wire                     done;

    // Instantiate DUT
    FIR_Filter_Top_Module #(
        .RAM_WIDTH(RAM_WIDTH),
        .LEN_WIDTH(LEN_WIDTH)
    ) u_FIR (
        .clk             (clk),
        .rst_n           (rst_n),
        .start           (start),
        .Reset           (Reset),
        
        .AXS_S_fil_vld   (AXS_S_fil_vld),
        .AXS_S_fil_rdy   (AXS_S_fil_rdy),
        .AXS_S_fil_data  (AXS_S_fil_data),
        .AXS_S_fil_last  (AXS_S_fil_last),
        
        .AXS_S_src_vld   (AXS_S_src_vld),
        .AXS_S_src_rdy   (AXS_S_src_rdy),
        .AXS_S_src_data  (AXS_S_src_data),
        .AXS_S_src_last  (AXS_S_src_last),
        
        .AXS_M_psum_vld  (AXS_M_psum_vld),
        .AXS_M_psum_rdy  (AXS_M_psum_rdy),
        .AXS_M_psum_data (AXS_M_psum_data),
        .AXS_M_psum_last (AXS_M_psum_last),
        
        .busy            (busy),
        .done            (done)
    );

    // Clock Generation: 100MHz (10ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Test Sequence
    initial begin
        // 1. Initialize all signals
        rst_n          = 0;
        start          = 0;
        Reset          = 0;
        
        AXS_S_fil_vld  = 0;
        AXS_S_fil_data = 0;
        AXS_S_fil_last = 0;
        
        AXS_S_src_vld  = 0;
        AXS_S_src_data = 0;
        AXS_S_src_last = 0;
        
        AXS_M_psum_rdy = 1; // 接收端始终准备好

        // 2. Apply Reset
        #25; 
        rst_n = 1;
        #20;

        $display("========== FIR Filter Test Started ==========");

        // 3. Load Coefficients: {c3, c2, c1, c0} = {4, 3, 2, 1}
        while (!AXS_S_fil_rdy) @(posedge clk); 
        #1; // 关键：模拟布线和逻辑延迟
        AXS_S_fil_data = {16'sd4, 16'sd3, 16'sd2, 16'sd1}; 
        AXS_S_fil_vld  = 1;
        
        @(posedge clk); 
        #1;
        AXS_S_fil_vld  = 0; 
        $display("[%0t] Coefficients Loaded: c0=1, c1=2, c2=3, c3=4", $time);
        
        #30;

        // 4. Assert MMIO Start
        @(posedge clk); 
        #1; // 关键修复：让 start 的拉高发生在时钟沿之后，触发硬件的边沿检测
        start = 1;
        $display("[%0t] MMIO Start Asserted", $time);

        // 5. Feed Source Data (Simulating DMA sending data)
        
        // --- 组1: 数据 {x3, x2, x1, x0} = {4, 3, 2, 1} ---
        while (!AXS_S_src_rdy) @(posedge clk); 
        #1;
        AXS_S_src_data = {16'sd4, 16'sd3, 16'sd2, 16'sd1}; 
        AXS_S_src_vld  = 1;
        AXS_S_src_last = 0;
        $display("[%0t] Sent Data Group 1: 1, 2, 3, 4", $time);

        @(posedge clk); 
        // --- 组2: 数据 {x7, x6, x5, x4} = {8, 7, 6, 5} ---
        while (!AXS_S_src_rdy) @(posedge clk); 
        #1;
        AXS_S_src_data = {16'sd8, 16'sd7, 16'sd6, 16'sd5}; 
        AXS_S_src_vld  = 1;
        AXS_S_src_last = 0;
        $display("[%0t] Sent Data Group 2: 5, 6, 7, 8", $time);

        @(posedge clk); 
        // --- 组3: Flush 数据 (全零) 并拉高 TLAST ---
        while (!AXS_S_src_rdy) @(posedge clk); 
        #1;
        AXS_S_src_data = {16'sd0, 16'sd0, 16'sd0, 16'sd0}; 
        AXS_S_src_vld  = 1;
        AXS_S_src_last = 1; 
        $display("[%0t] Sent Flush Data  : 0, 0, 0, 0 with TLAST", $time);

        @(posedge clk); 
        #1;
        AXS_S_src_vld  = 0;
        AXS_S_src_last = 0;

        // 6. Wait for DONE
        while (!done) @(posedge clk);
        $display("[%0t] Hardware asserted DONE!", $time);

        // 7. Clear MMIO Start 
        @(posedge clk); 
        #1;
        start = 0;
        $display("[%0t] MMIO Start Cleared. Hardware should return to IDLE.", $time);

        #50;
        $display("========== FIR Filter Test Finished ==========");
        $finish; // 触发仿真正常结束，不会死等到 1000ns
    end

    // Monitor Output Data Automatically
    always @(posedge clk) begin
        if (AXS_M_psum_vld && AXS_M_psum_rdy) begin
            $display("[%0t] Valid Output Received! TLAST = %b", $time, AXS_M_psum_last);
            $display("      Data[3] = %0d", $signed(AXS_M_psum_data[63:48]));
            $display("      Data[2] = %0d", $signed(AXS_M_psum_data[47:32]));
            $display("      Data[1] = %0d", $signed(AXS_M_psum_data[31:16]));
            $display("      Data[0] = %0d", $signed(AXS_M_psum_data[15:0]));
            $display("      -----------------------------------");
        end
    end

endmodule