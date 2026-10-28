
`timescale 1ns/1ps

module tb_axi4_lite_slave;

    localparam int ADDR_WIDTH = 32;
    localparam int DATA_WIDTH = 32;

    localparam logic [1:0] RESP_OKAY  = 2'b00;
    localparam logic [1:0] RESP_SLVERR = 2'b10;

    logic clk;
    logic rst_n = 1'b0;

    logic [ADDR_WIDTH-1:0] s_axi_awaddr = '0;
    logic s_axi_awvalid = 1'b0;
    logic s_axi_awready;

    logic [DATA_WIDTH-1:0] s_axi_wdata = '0;
    logic [DATA_WIDTH/8-1:0] s_axi_wstrb = '0;
    logic s_axi_wvalid = 1'b0;
    logic s_axi_wready;

    logic [1:0] s_axi_bresp;
    logic s_axi_bvalid;
    logic s_axi_bready = 1'b0;

    logic [ADDR_WIDTH-1:0] s_axi_araddr = '0;
    logic s_axi_arvalid = 1'b0;
    logic s_axi_arready;

    logic [DATA_WIDTH-1:0] s_axi_rdata;
    logic [1:0] s_axi_rresp;
    logic s_axi_rvalid;
    logic s_axi_rready = 1'b0;

    int tests_passed = 0;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    axi4_lite_slave #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_REGS(16)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),

        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),

        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),

        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),

        .s_axi_araddr(s_axi_araddr),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),

        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready)
    );
    // Assertions for AXI write-response stability
    axi_write_assertions write_assertions (
        .clk     (clk),
        .check_enable (rst_n),
        .bvalid  (s_axi_bvalid),
        .bready  (s_axi_bready),
        .bresp   (s_axi_bresp),
        .rvalid (s_axi_rvalid),
        .rready (s_axi_rready),
        .rdata  (s_axi_rdata),
        .rresp  (s_axi_rresp)
    );
    task automatic write_txn(
        input  logic [31:0] addr,
        input  logic [31:0] data,
        input  logic [3:0]  strb,
        output logic [1:0]  resp
    );
        bit aw_done;
        bit w_done;
        int timeout_count;

        begin
            aw_done = 0;
            w_done = 0;
            timeout_count = 0;
            resp = 2'bxx;

            @(negedge clk);
            s_axi_awaddr  = addr;
            s_axi_awvalid = 1'b1;
            s_axi_wdata   = data;
            s_axi_wstrb   = strb;
            s_axi_wvalid  = 1'b1;
            s_axi_bready  = 1'b0;

            // Wait for both independent write-channel handshakes.
            while ((!aw_done || !w_done) && timeout_count < 30) begin
                @(posedge clk);

                if (s_axi_awvalid && s_axi_awready)
                    aw_done = 1;

                if (s_axi_wvalid && s_axi_wready)
                    w_done = 1;

                @(negedge clk);

                if (aw_done)
                    s_axi_awvalid = 1'b0;

                if (w_done)
                    s_axi_wvalid = 1'b0;

                timeout_count++;
            end

            if (!aw_done || !w_done)
                $fatal(1, "FAIL: Write address/data handshake timed out");

            // Wait for the write response.
            timeout_count = 0;
            while (!s_axi_bvalid && timeout_count < 30) begin
                @(negedge clk);
                timeout_count++;
            end

            if (!s_axi_bvalid)
                $fatal(1, "FAIL: Write response timed out");

            // Capture BRESP before accepting the response.
            resp = s_axi_bresp;

            // Complete the response handshake.
            s_axi_bready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            s_axi_bready = 1'b0;
        end
    endtask

    task automatic read_txn(
        input  logic [31:0] addr,
        output logic [31:0] data,
        output logic [1:0]  resp
    );
        int timeout_count;

        begin
            timeout_count = 0;

            @(negedge clk);
            s_axi_araddr  = addr;
            s_axi_arvalid = 1'b1;
            s_axi_rready  = 1'b0;

            do begin
                @(posedge clk);
                if (s_axi_arvalid && s_axi_arready)
                    break;
                timeout_count++;
                if (timeout_count >= 30)
                    $fatal(1, "FAIL: Read address handshake timed out");
            end while (1);

            @(negedge clk);
            s_axi_arvalid = 1'b0;

            timeout_count = 0;
            while (!s_axi_rvalid && timeout_count < 30) begin
                @(negedge clk);
                timeout_count++;
            end

            if (!s_axi_rvalid)
                $fatal(1, "FAIL: Read response timed out");

            data = s_axi_rdata;
            resp = s_axi_rresp;

            s_axi_rready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            s_axi_rready = 1'b0;
        end
    endtask
        task automatic write_channels_independent(
        input logic [31:0] addr,
        input logic [31:0] data,
        input logic [3:0]  strb,
        input bit          address_first,
        output logic [1:0] resp
    );
        int timeout_count;

        begin
            timeout_count = 0;
            resp = 2'bxx;

            // Keep the response channel idle before starting.
            @(negedge clk);
            s_axi_bready = 1'b0;

            if (address_first) begin
                // Phase 1: Send address without write data.
                s_axi_awaddr  = addr;
                s_axi_awvalid = 1'b1;
                s_axi_wvalid  = 1'b0;

                do begin
                    @(posedge clk);
                    if (s_axi_awvalid && s_axi_awready)
                        break;

                    timeout_count++;
                    if (timeout_count >= 30)
                        $fatal(1, "FAIL: AW-first handshake timed out");
                end while (1);

                @(negedge clk);
                s_axi_awvalid = 1'b0;

                // Ensure address and data arrive in different cycles.
                @(negedge clk);
            end else begin
                // Phase 1: Send write data without the address.
                s_axi_wdata  = data;
                s_axi_wstrb  = strb;
                s_axi_wvalid = 1'b1;
                s_axi_awvalid = 1'b0;

                do begin
                    @(posedge clk);
                    if (s_axi_wvalid && s_axi_wready)
                        break;

                    timeout_count++;
                    if (timeout_count >= 30)
                        $fatal(1, "FAIL: W-first handshake timed out");
                end while (1);

                @(negedge clk);
                s_axi_wvalid = 1'b0;

                // Ensure address and data arrive in different cycles.
                @(negedge clk);
            end

            // Phase 2: Send the channel that has not arrived yet.
            timeout_count = 0;

            if (address_first) begin
                s_axi_wdata  = data;
                s_axi_wstrb  = strb;
                s_axi_wvalid = 1'b1;

                do begin
                    @(posedge clk);
                    if (s_axi_wvalid && s_axi_wready)
                        break;

                    timeout_count++;
                    if (timeout_count >= 30)
                        $fatal(1, "FAIL: W handshake after AW timed out");
                end while (1);

                @(negedge clk);
                s_axi_wvalid = 1'b0;
            end else begin
                s_axi_awaddr  = addr;
                s_axi_awvalid = 1'b1;

                do begin
                    @(posedge clk);
                    if (s_axi_awvalid && s_axi_awready)
                        break;

                    timeout_count++;
                    if (timeout_count >= 30)
                        $fatal(1, "FAIL: AW handshake after W timed out");
                end while (1);

                @(negedge clk);
                s_axi_awvalid = 1'b0;
            end

            // Wait for the write response.
            timeout_count = 0;
            while (!s_axi_bvalid && timeout_count < 30) begin
                @(negedge clk);
                timeout_count++;
            end

            if (!s_axi_bvalid)
                $fatal(1, "FAIL: Independent-channel write response timed out");

            resp = s_axi_bresp;

            // Accept the response.
            s_axi_bready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            s_axi_bready = 1'b0;
        end
    endtask
    logic [31:0] read_data;
    logic [1:0]  read_resp;
    logic [1:0]  write_resp;

    initial begin
        $dumpfile("waveforms/axi4_lite_slave.vcd");
        $dumpvars(0, tb_axi4_lite_slave);

        // Reset
        repeat (3) @(negedge clk);
        rst_n = 1'b1;
        repeat (2) @(negedge clk);

        // Test 1: Reset value
        read_txn(32'h00000000, read_data, read_resp);
        if (read_data !== 32'h00000000 || read_resp !== RESP_OKAY)
            $fatal(1, "FAIL: Reset readback incorrect");
        tests_passed++;
        $display("PASS: Reset register value");

        // Test 2: Full-word write/readback
        write_txn(32'h00000004, 32'h12345678, 4'b1111, write_resp);
        if (write_resp !== RESP_OKAY)
            $fatal(1, "FAIL: Full-word write response incorrect");

        read_txn(32'h00000004, read_data, read_resp);
        if (read_data !== 32'h12345678 || read_resp !== RESP_OKAY)
            $fatal(1, "FAIL: Full-word write/readback");
        tests_passed++;
        $display("PASS: Full-word write/readback");

        // Test 3: Partial-byte write
        write_txn(32'h00000004, 32'h0000AABB, 4'b0011, write_resp);
        if (write_resp !== RESP_OKAY)
            $fatal(1, "FAIL: Partial write response incorrect");

        read_txn(32'h00000004, read_data, read_resp);
        if (read_data !== 32'h1234AABB)
            $fatal(1, "FAIL: WSTRB partial-byte write");
        tests_passed++;
        $display("PASS: WSTRB partial-byte write");

        // Test 4: Invalid address
        write_txn(32'h00000040, 32'hDEADBEEF, 4'b1111, write_resp);
        if (write_resp !== RESP_SLVERR)
            $fatal(1, "FAIL: Invalid write address response");

        read_txn(32'h00000040, read_data, read_resp);
        if (read_resp !== RESP_SLVERR)
            $fatal(1, "FAIL: Invalid read address response");
        tests_passed++;
        $display("PASS: Invalid address responses");

                // Test 5: Address arrives before write data (AW first)
        write_channels_independent(
            32'h00000008,
            32'hA1B2C3D4,
            4'b1111,
            1'b1,
            write_resp
        );

        if (write_resp !== RESP_OKAY)
            $fatal(1, "FAIL: AW-first write response incorrect");

        read_txn(32'h00000008, read_data, read_resp);

        if (read_data !== 32'hA1B2C3D4 || read_resp !== RESP_OKAY)
            $fatal(1, "FAIL: AW-first write/readback incorrect");

        tests_passed++;
        $display("PASS: Independent channels - AW first");

        // Test 6: Write data arrives before address (W first)
        write_channels_independent(
            32'h0000000C,
            32'h5678ABCD,
            4'b1111,
            1'b0,
            write_resp
        );

        if (write_resp !== RESP_OKAY)
            $fatal(1, "FAIL: W-first write response incorrect");

        read_txn(32'h0000000C, read_data, read_resp);

        if (read_data !== 32'h5678ABCD || read_resp !== RESP_OKAY)
            $fatal(1, "FAIL: W-first write/readback incorrect");

        tests_passed++;
        $display("PASS: Independent channels - W first");

        // Test 7: Write-response backpressure
        // Keep BREADY low and verify BVALID/BRESP remain stable.

        @(negedge clk);
        s_axi_awaddr  = 32'h00000010;
        s_axi_awvalid = 1'b1;
        s_axi_wdata   = 32'hCAFEBABE;
        s_axi_wstrb   = 4'b1111;
        s_axi_wvalid  = 1'b1;
        s_axi_bready  = 1'b0;

        // Wait for both write-channel handshakes.
        begin
            bit aw_done;
            bit w_done;
            int timeout_count;

            aw_done = 0;
            w_done = 0;
            timeout_count = 0;

            while ((!aw_done || !w_done) && timeout_count < 30) begin
                @(posedge clk);

                if (s_axi_awvalid && s_axi_awready)
                    aw_done = 1;

                if (s_axi_wvalid && s_axi_wready)
                    w_done = 1;

                @(negedge clk);

                if (aw_done)
                    s_axi_awvalid = 1'b0;

                if (w_done)
                    s_axi_wvalid = 1'b0;

                timeout_count++;
            end

            if (!aw_done || !w_done)
                $fatal(1, "FAIL: Test 7 write-channel handshake timed out");
        end

        // Wait for BVALID while keeping BREADY low.
        begin
            int timeout_count;

            timeout_count = 0;

            while (!s_axi_bvalid && timeout_count < 30) begin
                @(negedge clk);
                timeout_count++;
            end

            if (!s_axi_bvalid)
                $fatal(1, "FAIL: Test 7 write response timed out");
        end

        // Capture the response and verify it remains stable.
        begin
            logic [1:0] held_bresp;

            held_bresp = s_axi_bresp;

            if (held_bresp !== RESP_OKAY)
                $fatal(1, "FAIL: Test 7 initial BRESP incorrect");

            repeat (4) begin
                @(posedge clk);
                #1;

                if (s_axi_bvalid !== 1'b1)
                    $fatal(1, "FAIL: BVALID dropped during backpressure");

                if (s_axi_bresp !== held_bresp)
                    $fatal(1, "FAIL: BRESP changed during backpressure");
            end

            // Accept the response only after the stability checks.
            @(negedge clk);
            s_axi_bready = 1'b1;

            @(posedge clk);
            @(negedge clk);
            s_axi_bready = 1'b0;

            if (s_axi_bvalid !== 1'b0)
                $fatal(1, "FAIL: BVALID did not clear after response handshake");
        end

        // Confirm that the write actually reached the register bank.
        read_txn(32'h00000010, read_data, read_resp);

        if (read_data !== 32'hCAFEBABE || read_resp !== RESP_OKAY)
            $fatal(1, "FAIL: Test 7 write/readback incorrect");

        tests_passed++;
        $display("PASS: Write-response backpressure");

                // Test 8: Read-response backpressure
        // Keep RREADY low and verify RVALID, RDATA, and RRESP remain stable.

        // Prepare a known value in register address 0x14.
        write_txn(32'h00000014, 32'hDEADBEEF, 4'b1111, write_resp);

        if (write_resp !== RESP_OKAY)
            $fatal(1, "FAIL: Test 8 setup write response incorrect");

        // Issue a read request while keeping RREADY low.
        @(negedge clk);
        s_axi_araddr  = 32'h00000014;
        s_axi_arvalid = 1'b1;
        s_axi_rready  = 1'b0;

        begin
            int timeout_count;

            timeout_count = 0;

            do begin
                @(posedge clk);

                if (s_axi_arvalid && s_axi_arready)
                    break;

                timeout_count++;

                if (timeout_count >= 30)
                    $fatal(1, "FAIL: Test 8 read-address handshake timed out");
            end while (1);
        end

        @(negedge clk);
        s_axi_arvalid = 1'b0;

        // Wait for the read response.
        begin
            int timeout_count;

            timeout_count = 0;

            while (!s_axi_rvalid && timeout_count < 30) begin
                @(negedge clk);
                timeout_count++;
            end

            if (!s_axi_rvalid)
                $fatal(1, "FAIL: Test 8 read response timed out");
        end

        // Capture the response and verify stability under backpressure.
        begin
            logic [31:0] held_rdata;
            logic [1:0]  held_rresp;

            held_rdata = s_axi_rdata;
            held_rresp = s_axi_rresp;

            if (held_rdata !== 32'hDEADBEEF)
                $fatal(1, "FAIL: Test 8 initial RDATA incorrect");

            if (held_rresp !== RESP_OKAY)
                $fatal(1, "FAIL: Test 8 initial RRESP incorrect");

            repeat (4) begin
                @(posedge clk);
                #1;

                if (s_axi_rvalid !== 1'b1)
                    $fatal(1, "FAIL: RVALID dropped during backpressure");

                if (s_axi_rdata !== held_rdata)
                    $fatal(1, "FAIL: RDATA changed during backpressure");

                if (s_axi_rresp !== held_rresp)
                    $fatal(1, "FAIL: RRESP changed during backpressure");
            end

            // Accept the response after the stability checks.
            @(negedge clk);
            s_axi_rready = 1'b1;

            @(posedge clk);
            @(negedge clk);
            s_axi_rready = 1'b0;

            if (s_axi_rvalid !== 1'b0)
                $fatal(1, "FAIL: RVALID did not clear after response handshake");
        end

        // Test 9: Register boundaries and unaligned addresses
        $display("\nTest 9: Register boundaries and unaligned addresses");

        // Test 9.1: Write and read the first valid register (0x00)
        write_txn(32'h00000000, 32'hA5A55A5A, 4'b1111, write_resp);

        if (write_resp !== RESP_OKAY)
            $fatal(1, "FAIL: Test 9 write to address 0x00");

        read_txn(32'h00000000, read_data, read_resp);

        if (read_resp !== RESP_OKAY || read_data !== 32'hA5A55A5A)
            $fatal(1, "FAIL: Test 9 readback from address 0x00");

        // Test 9.2: Write and read the last valid register (0x3C)
        write_txn(32'h0000003C, 32'h1234ABCD, 4'b1111, write_resp);

        if (write_resp !== RESP_OKAY)
            $fatal(1, "FAIL: Test 9 write to last valid address 0x3C");

        read_txn(32'h0000003C, read_data, read_resp);

        if (read_resp !== RESP_OKAY || read_data !== 32'h1234ABCD)
            $fatal(1, "FAIL: Test 9 readback from last valid address 0x3C");

        // Test 9.3: Address 0x40 is outside the 16-register bank
        write_txn(32'h00000040, 32'hFFFFFFFF, 4'b1111, write_resp);

        if (write_resp !== RESP_SLVERR)
            $fatal(1, "FAIL: Test 9 write to invalid address 0x40");

        read_txn(32'h00000040, read_data, read_resp);

        if (read_resp !== RESP_SLVERR)
            $fatal(1, "FAIL: Test 9 read from invalid address 0x40");

        // Test 9.4: Unaligned write and read at address 0x01
        write_txn(32'h00000001, 32'hFFFFFFFF, 4'b1111, write_resp);

        if (write_resp !== RESP_SLVERR)
            $fatal(1, "FAIL: Test 9 unaligned write at 0x01");

        read_txn(32'h00000001, read_data, read_resp);

        if (read_resp !== RESP_SLVERR)
            $fatal(1, "FAIL: Test 9 unaligned read at 0x01");

        // Test 9.5: Unaligned write and read at address 0x02
        write_txn(32'h00000002, 32'hFFFFFFFF, 4'b1111, write_resp);

        if (write_resp !== RESP_SLVERR)
            $fatal(1, "FAIL: Test 9 unaligned write at 0x02");

        read_txn(32'h00000002, read_data, read_resp);

        if (read_resp !== RESP_SLVERR)
            $fatal(1, "FAIL: Test 9 unaligned read at 0x02");

        // Test 9.6: Unaligned write and read at address 0x03
        write_txn(32'h00000003, 32'hFFFFFFFF, 4'b1111, write_resp);

        if (write_resp !== RESP_SLVERR)
            $fatal(1, "FAIL: Test 9 unaligned write at 0x03");

        read_txn(32'h00000003, read_data, read_resp);

        if (read_resp !== RESP_SLVERR)
            $fatal(1, "FAIL: Test 9 unaligned read at 0x03");

        tests_passed++;
        $display("PASS: Register boundaries and unaligned addresses");

        tests_passed++;
        $display("PASS: Read-response backpressure");

        // Test 10: Reset during pending write and read responses
        $display("\nTest 10: Reset during pending transactions");

        // --------------------------------------------------
        // Test 10.1: Reset while write response is pending
        // --------------------------------------------------

        @(negedge clk);
        s_axi_awaddr  = 32'h00000018;
        s_axi_awvalid = 1'b1;
        s_axi_wdata   = 32'hCAFED00D;
        s_axi_wstrb   = 4'b1111;
        s_axi_wvalid  = 1'b1;
        s_axi_bready  = 1'b0;

        // Track AW and W handshakes independently.
        begin
            integer timeout_count;
            logic aw_done;
            logic w_done;

            timeout_count = 0;
            aw_done = 1'b0;
            w_done = 1'b0;

            while ((!aw_done || !w_done) && timeout_count < 30) begin
                @(posedge clk);

                if (s_axi_awvalid && s_axi_awready)
                    aw_done = 1'b1;

                if (s_axi_wvalid && s_axi_wready)
                    w_done = 1'b1;

                @(negedge clk);

                if (aw_done)
                    s_axi_awvalid = 1'b0;

                if (w_done)
                    s_axi_wvalid = 1'b0;

                timeout_count++;
            end

            if (!aw_done)
                $fatal(1, "FAIL: Test 10 AW handshake timed out");

            if (!w_done)
                $fatal(1, "FAIL: Test 10 W handshake timed out");
        end

        // Wait until the write response is pending.
        begin
            integer timeout_count;
            timeout_count = 0;

            while (!s_axi_bvalid && timeout_count < 30) begin
                @(posedge clk);
                #1;
                timeout_count++;
            end

            if (!s_axi_bvalid)
                $fatal(1, "FAIL: Test 10 write response timed out");
        end

        // Assert asynchronous reset while BVALID is high.
        #1;
        rst_n = 1'b0;
        #1;

        if (s_axi_bvalid !== 1'b0)
            $fatal(1, "FAIL: Test 10 BVALID did not clear during reset");

        repeat (2) @(negedge clk);
        rst_n = 1'b1;

        // --------------------------------------------------
        // Test 10.2: Reset while read response is pending
        // --------------------------------------------------

        // Write a known value before testing the read response.
        write_txn(32'h00000014, 32'hDEADBEEF, 4'b1111, write_resp);

        if (write_resp !== RESP_OKAY)
            $fatal(1, "FAIL: Test 10 register setup write failed");

        // Start a read and keep RREADY low.
        @(negedge clk);
        s_axi_araddr  = 32'h00000014;
        s_axi_arvalid = 1'b1;
        s_axi_rready  = 1'b0;

        begin
            integer timeout_count;
            timeout_count = 0;

            while (!(s_axi_arvalid && s_axi_arready) &&
                   timeout_count < 30) begin
                @(posedge clk);
                #1;
                timeout_count++;
            end

            if (!(s_axi_arvalid && s_axi_arready))
                $fatal(1, "FAIL: Test 10 read-address handshake timed out");
        end

        @(negedge clk);
        s_axi_arvalid = 1'b0;

        // Wait for the read response.
        begin
            integer timeout_count;
            timeout_count = 0;

            while (!s_axi_rvalid && timeout_count < 30) begin
                @(posedge clk);
                #1;
                timeout_count++;
            end

            if (!s_axi_rvalid)
                $fatal(1, "FAIL: Test 10 read response timed out");
        end

        // Assert asynchronous reset while RVALID is high.
        #1;
        rst_n = 1'b0;
        #1;

        if (s_axi_rvalid !== 1'b0)
            $fatal(1, "FAIL: Test 10 RVALID did not clear during reset");

        repeat (2) @(negedge clk);
        rst_n = 1'b1;

        // Confirm the register bank was cleared by reset.
        read_txn(32'h00000014, read_data, read_resp);

        if (read_resp !== RESP_OKAY || read_data !== 32'h00000000)
            $fatal(1, "FAIL: Test 10 register bank did not clear after reset");

        tests_passed++;
        $display("PASS: Reset during pending transactions");

        // Test 11: Consecutive writes and reads
        $display("\nTest 11: Consecutive transactions");

        // Write the first value to register 0x08.
        write_txn(32'h00000008, 32'h11112222, 4'b1111, write_resp);

        if (write_resp !== RESP_OKAY)
            $fatal(1, "FAIL: Test 11 first write");

        // Overwrite the same register with a new value.
        write_txn(32'h00000008, 32'hAABBCCDD, 4'b1111, write_resp);

        if (write_resp !== RESP_OKAY)
            $fatal(1, "FAIL: Test 11 overwrite");

        // Read back the latest value.
        read_txn(32'h00000008, read_data, read_resp);

        if (read_resp !== RESP_OKAY || read_data !== 32'hAABBCCDD)
            $fatal(1, "FAIL: Test 11 overwrite readback");

        // Initialize another register before checking consecutive reads.
        write_txn(32'h00000000, 32'hA5A55A5A, 4'b1111, write_resp);

        if (write_resp !== RESP_OKAY)
            $fatal(1, "FAIL: Test 11 setup write");

        read_txn(32'h00000000, read_data, read_resp);

        if (read_resp !== RESP_OKAY || read_data !== 32'hA5A55A5A)
            $fatal(1, "FAIL: Test 11 consecutive read");

        tests_passed++;
        $display("PASS: Consecutive writes, overwrite, and reads");

        // Test 12: Overlapping read and write activity
        $display("\nTest 12: Concurrent read and write activity");

        // Initialize the register that will be read.
        write_txn(32'h00000004, 32'h12345678, 4'b1111, write_resp);

        if (write_resp !== RESP_OKAY)
            $fatal(1, "FAIL: Test 12 setup write");

        // Start a read and write independently.
        fork
            begin
                read_txn(32'h00000004, read_data, read_resp);
            end

            begin
                write_txn(32'h0000000C, 32'hDEADBEEF, 4'b1111, write_resp);
            end
        join

        // Check the read result and response.
        if (read_resp !== RESP_OKAY || read_data !== 32'h12345678)
            $fatal(1, "FAIL: Test 12 concurrent read");

        // Confirm the concurrent write completed correctly.
        read_txn(32'h0000000C, read_data, read_resp);

        if (read_resp !== RESP_OKAY || read_data !== 32'hDEADBEEF)
            $fatal(1, "FAIL: Test 12 concurrent write readback");

        tests_passed++;
        $display("PASS: Concurrent read and write activity");

        $display("------------------------------------");
        $display("TESTS PASSED: %0d", tests_passed);
        $display("ALL INITIAL TESTS PASSED");
        $finish;
    end

endmodule
