// =============================================================
// AXI4 UVM Tests
// =============================================================

// -----------------------------------------------------------
// Base test — builds env, sets up vif
// -----------------------------------------------------------
class axi4_base_test extends uvm_test;
    `uvm_component_utils(axi4_base_test)

    axi4_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = axi4_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        run_test_body(phase);
        phase.drop_objection(this);
    endtask

    // Override in derived tests
    virtual task run_test_body(uvm_phase phase);
    endtask

endclass : axi4_base_test


// -----------------------------------------------------------
// Smoke test — single write/read pair
// -----------------------------------------------------------
class axi4_smoke_test extends axi4_base_test;
    `uvm_component_utils(axi4_smoke_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_test_body(uvm_phase phase);
        axi4_wr_rd_seq seq = axi4_wr_rd_seq::type_id::create("seq");
        seq.num_pairs = 1;
        seq.start(env.agent.sequencer);
    endtask

endclass : axi4_smoke_test


// -----------------------------------------------------------
// Random test — constrained-random traffic
// -----------------------------------------------------------
class axi4_rand_test extends axi4_base_test;
    `uvm_component_utils(axi4_rand_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_test_body(uvm_phase phase);
        axi4_rand_seq seq = axi4_rand_seq::type_id::create("seq");
        seq.num_txns = 100;
        seq.start(env.agent.sequencer);
    endtask

endclass : axi4_rand_test


// -----------------------------------------------------------
// Write-read integrity test
// -----------------------------------------------------------
class axi4_integrity_test extends axi4_base_test;
    `uvm_component_utils(axi4_integrity_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_test_body(uvm_phase phase);
        axi4_wr_rd_seq seq = axi4_wr_rd_seq::type_id::create("seq");
        seq.num_pairs = 50;
        seq.start(env.agent.sequencer);
    endtask

endclass : axi4_integrity_test


// -----------------------------------------------------------
// Boundary test — OOB and last-valid address
// -----------------------------------------------------------
class axi4_boundary_test extends axi4_base_test;
    `uvm_component_utils(axi4_boundary_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_test_body(uvm_phase phase);
        axi4_boundary_seq seq = axi4_boundary_seq::type_id::create("seq");
        seq.start(env.agent.sequencer);
    endtask

endclass : axi4_boundary_test


// -----------------------------------------------------------
// Max burst test
// -----------------------------------------------------------
class axi4_max_burst_test extends axi4_base_test;
    `uvm_component_utils(axi4_max_burst_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_test_body(uvm_phase phase);
        axi4_max_burst_seq seq = axi4_max_burst_seq::type_id::create("seq");
        seq.start(env.agent.sequencer);
    endtask

endclass : axi4_max_burst_test


// -----------------------------------------------------------
// Partial strobe test
// -----------------------------------------------------------
class axi4_strobe_test extends axi4_base_test;
    `uvm_component_utils(axi4_strobe_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_test_body(uvm_phase phase);
        axi4_partial_strobe_seq seq = axi4_partial_strobe_seq::type_id::create("seq");
        seq.start(env.agent.sequencer);
    endtask

endclass : axi4_strobe_test


// -----------------------------------------------------------
// Back-to-back single beat test
// -----------------------------------------------------------
class axi4_bb_test extends axi4_base_test;
    `uvm_component_utils(axi4_bb_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_test_body(uvm_phase phase);
        axi4_bb_single_seq seq = axi4_bb_single_seq::type_id::create("seq");
        seq.start(env.agent.sequencer);
    endtask

endclass : axi4_bb_test


// -----------------------------------------------------------
// Full regression — runs all sequences in order
// -----------------------------------------------------------
class axi4_regression_test extends axi4_base_test;
    `uvm_component_utils(axi4_regression_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_test_body(uvm_phase phase);
        axi4_wr_rd_seq         wr_rd  = axi4_wr_rd_seq        ::type_id::create("wr_rd");
        axi4_rand_seq          rand_s = axi4_rand_seq          ::type_id::create("rand_s");
        axi4_boundary_seq      bnd    = axi4_boundary_seq      ::type_id::create("bnd");
        axi4_max_burst_seq     mburst = axi4_max_burst_seq     ::type_id::create("mburst");
        axi4_partial_strobe_seq strb  = axi4_partial_strobe_seq::type_id::create("strb");
        axi4_bb_single_seq     bb     = axi4_bb_single_seq     ::type_id::create("bb");

        `uvm_info("TEST", "=== Regression: wr_rd integrity ===", UVM_NONE)
        wr_rd.num_pairs = 30;
        wr_rd.start(env.agent.sequencer);

        `uvm_info("TEST", "=== Regression: constrained random ===", UVM_NONE)
        rand_s.num_txns = 100;
        rand_s.start(env.agent.sequencer);

        `uvm_info("TEST", "=== Regression: boundary ===", UVM_NONE)
        bnd.start(env.agent.sequencer);

        `uvm_info("TEST", "=== Regression: max burst ===", UVM_NONE)
        mburst.start(env.agent.sequencer);

        `uvm_info("TEST", "=== Regression: partial strobe ===", UVM_NONE)
        strb.start(env.agent.sequencer);

        `uvm_info("TEST", "=== Regression: back-to-back single ===", UVM_NONE)
        bb.start(env.agent.sequencer);
    endtask

endclass : axi4_regression_test
