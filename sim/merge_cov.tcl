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

# Load and merge
load -run $db_list
merge -out results/merged.vdb -overwrite

# Generate text report
report_summary -out results/cov_summary.txt

puts "\nCoverage summary written to results/cov_summary.txt"
puts "Open merged DB in IMC GUI: imc -load results/merged.vdb"
exit
