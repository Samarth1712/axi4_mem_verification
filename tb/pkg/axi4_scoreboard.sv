// =============================================================
// AXI4 UVM Scoreboard
// Reference model: associative array mirrors DUT memory.
// Checks every read against predicted value and every
// response code against expected.
// =============================================================
class axi4_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(axi4_scoreboard)

    uvm_analysis_imp #(axi4_seq_item, axi4_scoreboard) analysis_export;

    // Reference memory (byte-addressable, word-granular)
    logic [31:0] ref_mem [int];

    // Stats
    int unsigned pass_cnt;
    int unsigned fail_cnt;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        analysis_export = new("analysis_export", this);
        pass_cnt = 0;
        fail_cnt = 0;
    endfunction

    // -----------------------------------------------------------
    // Called by monitor via analysis port
    // -----------------------------------------------------------
    function void write(axi4_seq_item item);
        if (item.is_write)
            check_write(item);
        else
            check_read(item);
    endfunction

    // -----------------------------------------------------------
    // Write: update reference model, check BRESP
    // -----------------------------------------------------------
    function void check_write(axi4_seq_item item);
        logic [ADDR_WIDTH-1:0] cur_addr = item.addr;
        logic [1:0]            exp_resp = 2'b00; // OKAY by default

        for (int i = 0; i <= item.burst_len; i++) begin
            int word_addr = int'(cur_addr);
            // Check OOB
            if (cur_addr >= MEM_BYTES) begin
                exp_resp = 2'b10; // SLVERR
            end else begin
                // Apply byte strobes to reference model
                if (!ref_mem.exists(word_addr))
                    ref_mem[word_addr] = 32'h0;
                for (int b = 0; b < STRB_W; b++) begin
                    if (item.wstrb[i][b])
                        ref_mem[word_addr][b*8 +: 8] = item.wdata[i][b*8 +: 8];
                end
            end
            // Advance address (INCR) or stay (FIXED)
            if (item.burst_type == INCR)
                cur_addr += (1 << item.burst_size);
        end

        // Check response
        if (item.bresp !== exp_resp) begin
            `uvm_error("SB", $sformatf(
                "BRESP MISMATCH addr=%0h got=%0h exp=%0h",
                item.addr, item.bresp, exp_resp))
            fail_cnt++;
        end else begin
            `uvm_info("SB", $sformatf(
                "WRITE OK addr=%0h len=%0d bresp=%0h",
                item.addr, item.burst_len, item.bresp), UVM_MEDIUM)
            pass_cnt++;
        end
    endfunction

    // -----------------------------------------------------------
    // Read: compare each beat against reference model
    // -----------------------------------------------------------
    function void check_read(axi4_seq_item item);
        logic [ADDR_WIDTH-1:0] cur_addr = item.addr;

        for (int i = 0; i <= item.burst_len; i++) begin
            int    word_addr = int'(cur_addr);
            logic [31:0] exp_data;
            logic [1:0]  exp_rresp;

            if (cur_addr >= MEM_BYTES) begin
                exp_data  = 32'h0;
                exp_rresp = 2'b10; // SLVERR
            end else begin
                exp_data  = ref_mem.exists(word_addr) ? ref_mem[word_addr] : 32'h0;
                exp_rresp = 2'b00;
            end

            if (item.rdata[i] !== exp_data || item.rresp[i] !== exp_rresp) begin
                `uvm_error("SB", $sformatf(
                    "READ MISMATCH beat=%0d addr=%0h | data got=%0h exp=%0h | rresp got=%0h exp=%0h",
                    i, cur_addr,
                    item.rdata[i], exp_data,
                    item.rresp[i], exp_rresp))
                fail_cnt++;
            end else begin
                `uvm_info("SB", $sformatf(
                    "READ OK beat=%0d addr=%0h data=%0h",
                    i, cur_addr, item.rdata[i]), UVM_MEDIUM)
                pass_cnt++;
            end

            if (item.burst_type == INCR)
                cur_addr += (1 << item.burst_size);
        end
    endfunction

    // -----------------------------------------------------------
    // Final report
    // -----------------------------------------------------------
    function void report_phase(uvm_phase phase);
        `uvm_info("SB", $sformatf(
            "\n========================================\n  SCOREBOARD SUMMARY\n  PASS: %0d   FAIL: %0d\n========================================",
            pass_cnt, fail_cnt), UVM_NONE)
        if (fail_cnt > 0)
            `uvm_error("SB", "TEST FAILED — scoreboard mismatches detected")
        else
            `uvm_info("SB", "ALL CHECKS PASSED", UVM_NONE)
    endfunction

endclass : axi4_scoreboard
