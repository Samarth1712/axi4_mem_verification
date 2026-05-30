// =============================================================
// AXI4 UVM Sequences
// =============================================================

// -----------------------------------------------------------
// Base sequence
// -----------------------------------------------------------
class axi4_base_seq extends uvm_sequence #(axi4_seq_item);
    `uvm_object_utils(axi4_base_seq)

    function new(string name = "axi4_base_seq");
        super.new(name);
    endfunction

    // Convenience task: send one item
    task send(axi4_seq_item item);
        start_item(item);
        if (!item.randomize())
            `uvm_fatal("SEQ", "Randomization failed")
        finish_item(item);
    endtask

endclass : axi4_base_seq


// -----------------------------------------------------------
// Constrained-random sequence (main workhorse)
// Fires N random read/write transactions
// -----------------------------------------------------------
class axi4_rand_seq extends axi4_base_seq;
    `uvm_object_utils(axi4_rand_seq)

    int unsigned num_txns = 50;

    function new(string name = "axi4_rand_seq");
        super.new(name);
    endfunction

    task body();
        axi4_seq_item item;
        repeat (num_txns) begin
            item = axi4_seq_item::type_id::create("rand_item");
            send(item);
        end
    endtask

endclass : axi4_rand_seq


// -----------------------------------------------------------
// Write-then-Read sequence
// Writes N locations, reads them back in order
// Used by scoreboard to verify data integrity
// -----------------------------------------------------------
class axi4_wr_rd_seq extends axi4_base_seq;
    `uvm_object_utils(axi4_wr_rd_seq)

    int unsigned num_pairs = 20;

    function new(string name = "axi4_wr_rd_seq");
        super.new(name);
    endfunction

    task body();
        axi4_seq_item wr, rd;

        repeat (num_pairs) begin
            // Write
            wr = axi4_seq_item::type_id::create("wr_item");
            start_item(wr);
            if (!wr.randomize() with { is_write == 1; })
                `uvm_fatal("SEQ", "Write randomization failed")
            finish_item(wr);

            // Read same address and length
            rd = axi4_seq_item::type_id::create("rd_item");
            start_item(rd);
            if (!rd.randomize() with {
                is_write   == 0;
                addr       == wr.addr;
                burst_len  == wr.burst_len;
                burst_type == wr.burst_type;
            })
                `uvm_fatal("SEQ", "Read randomization failed")
            finish_item(rd);
        end
    endtask

endclass : axi4_wr_rd_seq


// -----------------------------------------------------------
// Boundary address sequence
// Tests last valid address and first OOB address
// -----------------------------------------------------------
class axi4_boundary_seq extends axi4_base_seq;
    `uvm_object_utils(axi4_boundary_seq)

    function new(string name = "axi4_boundary_seq");
        super.new(name);
    endfunction

    task body();
        axi4_seq_item item;

        // 1. Single write to last valid word address
        item = axi4_seq_item::type_id::create("last_valid_wr");
        start_item(item);
        if (!item.randomize() with {
            is_write   == 1;
            addr       == MEM_BYTES - 4;
            burst_len  == 0;
        })
            `uvm_fatal("SEQ", "Boundary wr rand failed")
        finish_item(item);

        // 2. Read it back
        item = axi4_seq_item::type_id::create("last_valid_rd");
        start_item(item);
        if (!item.randomize() with {
            is_write   == 0;
            addr       == MEM_BYTES - 4;
            burst_len  == 0;
        })
            `uvm_fatal("SEQ", "Boundary rd rand failed")
        finish_item(item);

        // 3. OOB write (expect SLVERR)
        item = axi4_seq_item::type_id::create("oob_wr");
        item.c_addr_inbounds.constraint_mode(0);
        item.c_addr_oob.constraint_mode(1);
        start_item(item);
        if (!item.randomize() with { is_write == 1; burst_len == 0; })
            `uvm_fatal("SEQ", "OOB wr rand failed")
        finish_item(item);

        // 4. OOB read (expect SLVERR)
        item = axi4_seq_item::type_id::create("oob_rd");
        item.c_addr_inbounds.constraint_mode(0);
        item.c_addr_oob.constraint_mode(1);
        start_item(item);
        if (!item.randomize() with { is_write == 0; burst_len == 0; })
            `uvm_fatal("SEQ", "OOB rd rand failed")
        finish_item(item);

    endtask

endclass : axi4_boundary_seq


// -----------------------------------------------------------
// Max burst sequence
// Fires max-length (16-beat) bursts only
// -----------------------------------------------------------
class axi4_max_burst_seq extends axi4_base_seq;
    `uvm_object_utils(axi4_max_burst_seq)

    int unsigned num_txns = 10;

    function new(string name = "axi4_max_burst_seq");
        super.new(name);
    endfunction

    task body();
        axi4_seq_item item;
        repeat (num_txns) begin
            item = axi4_seq_item::type_id::create("max_item");
            item.c_burst_len.constraint_mode(0);
            item.c_max_burst.constraint_mode(1);
            send(item);
        end
    endtask

endclass : axi4_max_burst_seq


// -----------------------------------------------------------
// Partial strobe sequence
// Exercises byte-enable paths
// -----------------------------------------------------------
class axi4_partial_strobe_seq extends axi4_base_seq;
    `uvm_object_utils(axi4_partial_strobe_seq)

    int unsigned num_txns = 20;

    function new(string name = "axi4_partial_strobe_seq");
        super.new(name);
    endfunction

    task body();
        axi4_seq_item item;
        repeat (num_txns) begin
            item = axi4_seq_item::type_id::create("strb_item");
            item.c_strb_default.constraint_mode(0);
            item.c_strb_partial.constraint_mode(1);
            start_item(item);
            if (!item.randomize() with { is_write == 1; })
                `uvm_fatal("SEQ", "Strobe rand failed")
            finish_item(item);
        end
    endtask

endclass : axi4_partial_strobe_seq


// -----------------------------------------------------------
// Back-to-back single beat sequence
// Stresses ready/valid handshake at single-beat granularity
// -----------------------------------------------------------
class axi4_bb_single_seq extends axi4_base_seq;
    `uvm_object_utils(axi4_bb_single_seq)

    int unsigned num_txns = 30;

    function new(string name = "axi4_bb_single_seq");
        super.new(name);
    endfunction

    task body();
        axi4_seq_item item;
        repeat (num_txns) begin
            item = axi4_seq_item::type_id::create("bb_item");
            item.c_single_beat.constraint_mode(1);
            send(item);
        end
    endtask

endclass : axi4_bb_single_seq
