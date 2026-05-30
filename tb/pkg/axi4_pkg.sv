// =============================================================
// axi4_pkg — transaction types, constraints, functional coverage
// =============================================================
package axi4_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // -----------------------------------------------------------
    // Parameters (match DUT)
    // -----------------------------------------------------------
    parameter int DATA_WIDTH = 32;
    parameter int ADDR_WIDTH = 16;
    parameter int ID_WIDTH   = 4;
    parameter int STRB_W     = DATA_WIDTH / 8;
    parameter int MEM_DEPTH  = 1024;          // words
    parameter int MEM_BYTES  = MEM_DEPTH * 4; // bytes

    // -----------------------------------------------------------
    // Burst type enum
    // -----------------------------------------------------------
    typedef enum logic [1:0] {
        FIXED = 2'b00,
        INCR  = 2'b01
    } burst_t;

    // -----------------------------------------------------------
    // AXI4 Sequence Item
    // -----------------------------------------------------------
    class axi4_seq_item extends uvm_sequence_item;
        `uvm_object_utils(axi4_seq_item)

        // Direction
        rand bit is_write;

        // Address channel fields
        rand logic [ID_WIDTH-1:0]   id;
        rand logic [ADDR_WIDTH-1:0] addr;
        rand logic [7:0]            burst_len;   // 0 = 1 beat
        rand logic [2:0]            burst_size;  // 2 = 4 bytes (word)
        rand burst_t                burst_type;

        // Write data (one entry per beat, sized to max burst of 16)
        rand logic [DATA_WIDTH-1:0] wdata  [];
        rand logic [STRB_W-1:0]     wstrb  [];

        // Response (filled by monitor, not driven)
        logic [1:0]            bresp;
        logic [DATA_WIDTH-1:0] rdata [];
        logic [1:0]            rresp [];

        // -------------------------------------------------------
        // Constraints
        // -------------------------------------------------------

        // Keep burst_len aligned with wdata/wstrb array size
        constraint c_data_size {
            wdata.size() == burst_len + 1;
            wstrb.size() == burst_len + 1;
        }

        // Only FIXED and INCR supported by DUT
        constraint c_burst_type {
            burst_type inside {FIXED, INCR};
        }

        // Word-aligned transfers (size = 2 → 4 bytes)
        constraint c_burst_size {
            burst_size == 3'h2;
        }

        // Standard: max 16-beat burst (AXI4 allows 256, keep it reasonable)
        constraint c_burst_len {
            burst_len inside {[0:15]};
        }

        // Address must be word-aligned
        constraint c_addr_align {
            addr[1:0] == 2'b00;
        }

        // Default: in-bounds address
        constraint c_addr_inbounds {
            addr + ((burst_len + 1) * 4) <= MEM_BYTES;
        }

        // Weighted: 70% writes, 30% reads (tune as needed)
        constraint c_dir_weight {
            is_write dist {1 := 70, 0 := 30};
        }

        // Full-word strobe by default (byte-enable tests override this)
        constraint c_strb_default {
            foreach (wstrb[i]) wstrb[i] == {STRB_W{1'b1}};
        }

        // -------------------------------------------------------
        // Named constraint sets (test can override with constraint_mode)
        // -------------------------------------------------------

        // For OOB testing — relax addr constraint
        constraint c_addr_oob {
            addr >= MEM_BYTES;
        }

        // Boundary: last beat lands exactly at MEM_BYTES
        constraint c_addr_boundary {
            addr + ((burst_len + 1) * 4) == MEM_BYTES;
        }

        // Back-to-back single-beat
        constraint c_single_beat {
            burst_len == 0;
        }

        // Max-length burst (16 beats)
        constraint c_max_burst {
            burst_len == 8'hF;
        }

        // Partial strobe (random byte enables)
        constraint c_strb_partial {
            foreach (wstrb[i]) wstrb[i] != {STRB_W{1'b1}};
            foreach (wstrb[i]) wstrb[i] != {STRB_W{1'b0}};
        }

        function new(string name = "axi4_seq_item");
            super.new(name);
            // All "override" constraints off by default.
            // Sequences enable exactly the ones they need.
            c_addr_oob.constraint_mode(0);
            c_addr_boundary.constraint_mode(0);
            c_single_beat.constraint_mode(0);    // conflicts with c_burst_len if left on
            c_max_burst.constraint_mode(0);       // conflicts with c_burst_len if left on
            c_strb_partial.constraint_mode(0);    // conflicts with c_strb_default if left on
        endfunction

        function string convert2string();
            return $sformatf(
                "%s id=%0h addr=%0h len=%0d btype=%s data[0]=%0h strb[0]=%0h",
                is_write ? "WR" : "RD",
                id, addr, burst_len,
                burst_type.name(),
                wdata.size() ? wdata[0] : 'x,
                wstrb.size() ? wstrb[0] : 'x
            );
        endfunction

    endclass : axi4_seq_item

    // -----------------------------------------------------------
    // Functional Coverage Collector
    // -----------------------------------------------------------
    class axi4_coverage extends uvm_subscriber #(axi4_seq_item);
        `uvm_component_utils(axi4_coverage)

        axi4_seq_item item;

        // -------------------------------------------------------
        covergroup axi4_cg;

            // Direction
            cp_dir: coverpoint item.is_write {
                bins write = {1};
                bins read  = {0};
            }

            // Burst type
            cp_burst_type: coverpoint item.burst_type {
                bins fixed = {FIXED};
                bins incr  = {INCR};
            }

            // Burst length bins
            cp_burst_len: coverpoint item.burst_len {
                bins single   = {0};
                bins short[]  = {[1:3]};
                bins mid[]    = {[4:7]};
                bins long_b[] = {[8:14]};
                bins max_b    = {15};
            }

            // Address region
            cp_addr_region: coverpoint item.addr {
                bins zero_page  = {[0         : 'h00FF]};
                bins mid_range  = {['h0100    : 'hEFF]};
                bins near_top   = {['hF00     : MEM_BYTES-4]};
                bins oob        = {[MEM_BYTES : {ADDR_WIDTH{1'b1}}]};
            }

            // Strobe patterns — only meaningful for writes; guard against
            // empty wstrb array on read items captured by the monitor.
            cp_strobe: coverpoint item.wstrb[0]
                       iff (item.is_write && item.wstrb.size() > 0) {
                bins full    = {{STRB_W{1'b1}}};
                bins partial = {[1:{STRB_W{1'b1}}-1]};
                bins none    = {0};
            }

            // Cross: direction × burst type
            cx_dir_burst: cross cp_dir, cp_burst_type;

            // Cross: direction × burst length
            cx_dir_len: cross cp_dir, cp_burst_len;

            // Cross: direction × address region
            cx_dir_addr: cross cp_dir, cp_addr_region;

        endgroup

        function new(string name, uvm_component parent);
            super.new(name, parent);
            axi4_cg = new();
        endfunction

        function void write(axi4_seq_item t);
            item = t;
            axi4_cg.sample();
        endfunction

    endclass : axi4_coverage

endpackage : axi4_pkg
