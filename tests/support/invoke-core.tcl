## -*- tcl -*- (c) 2019
# # ## ### ##### ######## ############# #####################
## Test support - Application simulator core

kt::source support/capture.tcl

# # ## ### ##### ######## ############# #####################

proc td {} { tcltest::testsDirectory }
proc md {} { return [td]/tm }

proc err {label args} { R 1 $label {*}$args }
proc ok  {label args} { R 0 $label {*}$args }
proc ok* {text}  { list 0 $text }

proc R {state label args} { list $state [V $label {*}$args] }

proc P {label} { return [td]/results/${label} } 

proc V {label args} {
    set path [P $label]
    if {[file exists $path]} {
	return [map [tcltest::viewFile $path] {*}$args]
    } else {
	return {}
    }
}

proc store-scan {} {
    #puts SCAN
    set scan [map [join [lsort -dict [fileutil::find [md]/store]] \n]]
    #puts //
    list 0 $scan
}

proc map {x args} {
    lappend map <MD>   [md]
    lappend map <ACO/> [a-core]/doc/trunk/README.md
    lappend map <ACO>  [a-core]
    lappend map <BCH/> [b-chisel]/index
    lappend map <BCH>  [b-chisel]
    lappend map <BCO/> [b-core]/index
    lappend map <BCO>  [b-core]
    lappend map <BGH>  [b-github]
    lappend map {*}$args

    string map $map $x
}

# # ## ### ##### ######## ############# #####################
## REF
## Use of trailing /index to shortcircuit url redirection.

proc a-core   {} { set _ https://core.tcl-lang.org/akupries/mirror }
proc b-core   {} { set _ https://core.tcl-lang.org/akupries/atom }
proc b-chisel {} { set _ https://chiselapp.com/user/andreas_kupries/repository/atom }
proc b-github {} { set _ https://github.com/andreas-kupries/atom }

# # ## ### ##### ######## ############# #####################
## Make mirror-vcs visible.

set ::env(PATH) "[file join [file dirname [td]] bin]:$::env(PATH)"

# # ## ### ##### ######## ############# #####################
return
