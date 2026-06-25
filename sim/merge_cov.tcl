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

if {[catch {load -run {*}$db_list} err]} {
    puts "ERROR during load: $err"
    exit 1
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
