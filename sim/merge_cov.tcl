# merge_cov.tcl — run via: imc -exec merge_cov.tcl
# Merges all per-test coverage databases into one and reports

set db_list {}
foreach dir [glob -nocomplain results/*/cov.db] {
    lappend db_list $dir
}

if {[llength $db_list] == 0} {
    puts "No coverage databases found under results/"
    exit 1
}

puts "Found [llength $db_list] coverage database(s):"
foreach d $db_list { puts "  $d" }

# {*} expands the list into separate arguments — without it, load -run
# receives the whole list as a single string and silently mishandles it.
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
