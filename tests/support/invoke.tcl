## -*- tcl -*- (c) 2018
# # ## ### ##### ######## ############# #####################
## Test support - Application simulator

kt require support linenoise::facade ;# m::cmdr references, cannot local cannot use modules
kt require support cmdr::history
kt require support cmdr::color
kt require support fileutil

# level 0
kt local   testing db::setup
kt local   testing db::track
kt local   testing m::db::location
kt local   testing m::futil
kt local   testing m::mail::asm
kt local   testing m::match
kt local   testing m::msg

# level 1
kt local   testing m::exec
kt local   testing m::mailer

# level 2
kt local   testing m::db
kt local   testing m::vcs::fossil
kt local   testing m::vcs::git

# level 3
kt local   testing m::reply
kt local   testing m::state
kt local   testing m::submission
kt local   testing m::vcs::github

# level 4
kt local   testing m::mail::generator
kt local   testing m::rolodex
kt local   testing m::validate::notreply
kt local   testing m::validate::reply
kt local   testing m::validate::submission
kt local   testing m::vcs

# level 5
kt local   testing m::mset
kt local   testing m::repo
kt local   testing m::store

# level 6
kt local   testing m::validate::mset
kt local   testing m::validate::repository

# level 7
				kt local   testing m::web::site
kt local   testing m::cmdr
kt local   testing m::glue

kt::source support/capture.tcl

# # ## ### ##### ######## ############# #####################

proc td {} { tcltest::testsDirectory }
proc md {} { return [td]/tm }

proc mapp {args} {
    #puts XXX\t(([info level 0]))

    capture-on
    try {
        list [m::cmdr::main $args] [capture-get]
    } finally {
	capture-done
	#puts XXX\t//
    }
}

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

## Initialization of the pseudo-application to redirect all its state
## files and any input/output into locations related to the testsuite.
## Keep away from any installation files. Also cleanup of said state.

proc mdb-initialize {} {
    file delete -force -- [md]
    file mkdir            [md]

    cmdr color activate 0

    cmdr history initial-limit 0
    cmdr history save-to [md]/history

    m::db::location::set [md]/sqlite3
    m::state store       [md]/store
    m::state site-store  [md]/site

    set ::argv0 mirror
}

proc mdb-finalize {} {
    file delete -force -- [md]
}

proc mdb-reset {} {
    m::db::reset
    mdb-initialize
}

mdb-initialize

# Intercept process exit for state cleanup
rename ::exit ::exit_orig
proc   ::exit {args} {
    mdb-finalize
    ::exit_orig {*}$args
}

# # ## ### ##### ######## ############# #####################
return
