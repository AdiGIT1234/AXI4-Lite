module register_bank #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int NUM_REGS = 16
)(
    input logic clk,
    input logic rst_n,

    //write port
    input logic wr_en,
    input logic [ADDR_WIDTH-1:0] wr_addr,
    input logic [DATA_WIDTH-1:0] wr_data,
    input logic [DATA_WIDTH/8 - 1:0] wr_strb,

    //read port
    input logic rd_en,
    input logic [ADDR_WIDTH-1:0] rd_addr,
    output logic [DATA_WIDTH-1:0] rd_data,

    //status
    output logic wr_valid_addr,
    output logic rd_valid_addr
);
    localparam int ADDR_LSB = $clog2(DATA_WIDTH/8);
    localparam int REG_INDEX_WIDTH = $clog2(NUM_REGS);

    logic [DATA_WIDTH-1:0] regs [0:NUM_REGS-1];

    logic [REG_INDEX_WIDTH-1:0] wr_index;
    logic [REG_INDEX_WIDTH-1:0] rd_index;

    integer i;
    integer byte_lane;

    //convert byte addresses to word indices
    always_comb begin
        wr_index = wr_addr[ADDR_LSB +: REG_INDEX_WIDTH];
        rd_index = rd_addr[ADDR_LSB +: REG_INDEX_WIDTH];

        //only aligned addresses within the register bank are valid
        wr_valid_addr = (wr_addr[ADDR_LSB-1:0] == '0) &&
                        (wr_addr[ADDR_WIDTH-1:ADDR_LSB+REG_INDEX_WIDTH] == '0);

        rd_valid_addr = (rd_addr[ADDR_LSB-1:0] == '0) &&
                        (rd_addr[ADDR_WIDTH-1:ADDR_LSB+REG_INDEX_WIDTH] == '0);
    end

    // Reset registers and apply byte-enabled writes.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < NUM_REGS; i = i + 1)
                regs[i] <= '0;
        end else if (wr_en && wr_valid_addr) begin
            for (byte_lane = 0; byte_lane < DATA_WIDTH/8;
                 byte_lane = byte_lane + 1) begin
                if (wr_strb[byte_lane]) begin
                    regs[wr_index][byte_lane*8 +: 8]
                        <= wr_data[byte_lane*8 +: 8];
                end
            end
        end
    end

    // Combinational register read.
    always_comb begin
        rd_data = '0;

        if (rd_en && rd_valid_addr)
            rd_data = regs[rd_index];
    end

endmodule
