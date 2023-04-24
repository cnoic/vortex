`include "VX_cache_define.vh"

module VX_tag_access #(
    parameter CACHE_ID          = 0,
    parameter BANK_ID           = 0,
    // Size of cache in bytes
    parameter CACHE_SIZE        = 1, 
    // Size of line inside a bank in bytes
    parameter CACHE_LINE_SIZE   = 1, 
    // Number of banks
    parameter NUM_BANKS         = 1, 
    // Size of a word in bytes
    parameter WORD_SIZE         = 1,
    // bank offset from beginning of index range
    parameter BANK_ADDR_OFFSET  = 0
) (
    input wire                          clk,
    input wire                          reset,

`IGNORE_UNUSED_BEGIN
    input wire[`DBG_CACHE_REQ_IDW-1:0]  req_id,
`IGNORE_UNUSED_END

    input wire                          stall,

    // read/fill
    input wire                          lookup,
    input wire[`LINE_ADDR_WIDTH-1:0]    addr,
    input wire                          fill,    
    input wire                          flush,
    output wire                         tag_match
);

    `UNUSED_PARAM (CACHE_ID)
    `UNUSED_PARAM (BANK_ID)
    `UNUSED_VAR (lookup)

    wire [`TAG_SELECT_BITS-1:0] read_tag;
    wire read_valid;
    
    wire [`LINE_SELECT_BITS-1:0] line_addr = addr[`LINE_SELECT_BITS-1:0];
    wire [`TAG_SELECT_BITS-1:0] line_tag = `LINE_TAG_ADDR(addr);
    reg [`TAG_SELECT_BITS-1:0] line_tag_1;

    VX_sp_ram #(
        .DATAW      (`TAG_SELECT_BITS + 1),
        .SIZE       (`LINES_PER_BANK),
        .OUT_REG    (1),
        .NO_RWCHECK (1)
    ) tag_store (
        .clk   (clk),
        .en    (!(stall || reset)),
        .addr  (line_addr),   
        .wren  (fill || flush),
        .wdata ({!flush, line_tag}),
        .rdata ({read_valid, read_tag})
    );

    always_ff @(posedge clk) line_tag_1 <= line_tag;

    assign tag_match = read_valid && (line_tag_1 == read_tag);

`ifdef DBG_TRACE_CACHE_TAG
    wire tag_match_dbg = read_valid && (line_tag == read_tag);
    always @(posedge clk) begin
        if (fill && ~stall) begin
            dpi_trace("%d: cache%0d:%0d tag-fill: addr=%0h, blk_addr=%0d, tag_id=%0h\n", $time, CACHE_ID, BANK_ID, `LINE_TO_BYTE_ADDR(addr, BANK_ID), line_addr, line_tag);
        end
        if (flush) begin
            dpi_trace("%d: cache%0d:%0d tag-flush: addr=%0h, blk_addr=%0d\n", $time, CACHE_ID, BANK_ID, `LINE_TO_BYTE_ADDR(addr, BANK_ID), line_addr);
        end
        if (lookup && ~stall) begin                
            if (tag_match_dbg) begin
                dpi_trace("%d: cache%0d:%0d tag-hit: addr=%0h, blk_addr=%0d, tag_id=%0h (#%0d)\n", $time, CACHE_ID, BANK_ID, `LINE_TO_BYTE_ADDR(addr, BANK_ID), line_addr, line_tag, req_id);
            end else begin
                dpi_trace("%d: cache%0d:%0d tag-miss: addr=%0h, blk_addr=%0d, tag_id=%0h, old_tag_id=%0h (#%0d)\n", $time, CACHE_ID, BANK_ID, `LINE_TO_BYTE_ADDR(addr, BANK_ID), line_addr, line_tag, read_tag, req_id);
            end
        end          
    end    
`endif

endmodule