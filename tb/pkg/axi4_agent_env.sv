// =============================================================
// AXI4 UVM Agent
// Bundles driver + monitor + sequencer
// =============================================================
class axi4_agent extends uvm_agent;
    `uvm_component_utils(axi4_agent)

    axi4_driver                    driver;
    axi4_monitor                   monitor;
    uvm_sequencer #(axi4_seq_item) sequencer;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        driver    = axi4_driver   ::type_id::create("driver",    this);
        monitor   = axi4_monitor  ::type_id::create("monitor",   this);
        sequencer = new("sequencer", this);  // plain new() — safer than type_id on generic parameterised sequencer
    endfunction

    function void connect_phase(uvm_phase phase);
        driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction

endclass : axi4_agent


// =============================================================
// AXI4 UVM Environment
// Connects agent → scoreboard → coverage
// =============================================================
class axi4_env extends uvm_env;
    `uvm_component_utils(axi4_env)

    axi4_agent      agent;
    axi4_scoreboard scoreboard;
    axi4_coverage   coverage;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent      = axi4_agent     ::type_id::create("agent",      this);
        scoreboard = axi4_scoreboard::type_id::create("scoreboard",  this);
        coverage   = axi4_coverage  ::type_id::create("coverage",    this);
    endfunction

    function void connect_phase(uvm_phase phase);
        // Monitor broadcasts to both scoreboard and coverage
        agent.monitor.ap.connect(scoreboard.analysis_export);
        agent.monitor.ap.connect(coverage.analysis_export);
    endfunction

endclass : axi4_env
