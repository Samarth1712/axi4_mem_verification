# run_gui.tcl — passed to xrun via -input when --gui is used
# Opens a waveform database, probes every signal, runs to completion,
# and leaves the GUI open afterward so you can inspect the waveform window.

if {[info exists ::env(WAVE_DB)]} {
    set wave_db $::env(WAVE_DB)
} else {
    set wave_db "waves"
}

database -open $wave_db -shm -default
probe -create -all -depth all -database $wave_db

run
# (no exit — GUI stays open for inspection)
# to exit type 'exit' in 
