module axi_write_assertions (
    input logic        clk,
    input logic        check_enable,

    // AXI write response channel
    input logic        bvalid,
    input logic        bready,
    input logic [1:0]  bresp,

    // AXI read response channel
    input logic        rvalid,
    input logic        rready,
    input logic [31:0] rdata,
    input logic [1:0]  rresp
);
/* verilator lint_off SYNCASYNCNET */
    // Write response must remain stable during backpressure.
    property p_bresp_stable_under_backpressure;
        @(posedge clk)
        (check_enable && bvalid && !bready)
        |=> (!check_enable ||
             (bvalid && $stable(bresp)));
    endproperty

    a_bresp_stable_under_backpressure:
        assert property (p_bresp_stable_under_backpressure)
        else $error("Write response changed during backpressure");

    // Write response VALID must remain asserted during backpressure.
    property p_bvalid_stays_high_under_backpressure;
        @(posedge clk)
        (check_enable && bvalid && !bready)
        |=> (!check_enable || bvalid);
    endproperty

    a_bvalid_stays_high_under_backpressure:
        assert property (p_bvalid_stays_high_under_backpressure)
        else $error("BVALID dropped during write-response backpressure");

    // Read response must remain stable during backpressure.
    property p_rresp_stable_under_backpressure;
        @(posedge clk)
        (check_enable && rvalid && !rready)
        |=> (!check_enable ||
             (rvalid && $stable(rdata) && $stable(rresp)));
    endproperty

    a_rresp_stable_under_backpressure:
        assert property (p_rresp_stable_under_backpressure)
        else $error("Read response changed during backpressure");
/* verilator lint_on SYNCASYNCNET */
endmodule
