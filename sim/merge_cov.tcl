# merge_cov.tcl — run via: imc -exec merge_cov.tcl
# Merges all per-test coverage databases into one and reports

set db_list {}
foreach dir [glob -nocomplain results/*] {
    set tname [file tail $dir]
    set rundir "$dir/cov_work/scope/$tname"
    if {[file isdirectory $rundir]} {
        lappend db_list $rundir
    }
}

if {[llength $db_list] == 0} {
    puts "No coverage databases found under results/"
    exit 1
}

puts "Found [llength $db_list] coverage database(s):"
foreach d $db_list { puts "  $d" }

# load -run only accepts one rundir per call — load each one in turn,
# IMC accumulates them into the current session for merge below.
foreach d $db_list {
    if {[catch {load -run $d} err]} {
        puts "ERROR loading $d: $err"
        exit 1
    }
}

if {[catch {merge -out results/merged.vdb -overwrite} err]} {
    puts "ERROR during merge: $err"
    exit 1
}

if {[catch {report -summary -out results/cov_summary.txt} err]} {
    puts "WARNING: report command failed ($err)."
    puts "Run 'imc -exec \"help report\"' to find the correct syntax for this IMC version."
}

puts "\nCoverage summary written to results/cov_summary.txt"
puts "Open merged DB in IMC GUI: imc -load results/merged.vdb"
exit
