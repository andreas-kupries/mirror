## -*- tcl -*-
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
kt local   testing m::cmdr
kt local   testing m::glue

# # ## ### ##### ######## ############# #####################

proc td {} { tcltest::testsDirectory }
proc md {} { return [td]/tm }

proc mapp {args} {
    rename ::puts    ::puts_orig
    rename ::capture ::puts
    capture-reset
    try {
        list [m::cmdr::main $args] [capture-get]
    } finally {
	rename ::puts	   ::capture
	rename ::puts_orig ::puts
    }
}

proc capture-get {} {
    variable stdout
    return [string trim $stdout]
}

proc capture-reset {} {
    variable stdout {}
    return
}

proc capture {args} {
    set nonewline 0
    if {[lindex $args 0] eq "-nonewline"} {
	set nonewline 1
	set args [lrange $args 1 end]
    }

    switch -exact -- [llength $args] {
	1 {
	    set chan stdout
	    set text [lindex $args 0]
	}
	2 {
	    lassign $args chan text
	}
	default {
	    error "Bad syntax: [info level 0]"
	}
    }

    if {$chan in {stdout stderr}} {
	# capture
	variable stdout
	append   stdout $text
	if {$nonewline} return
	append stdout \n
	return
    }

    # punt to original
    ::puts_orig {*}$args
    return
}

proc err {label} { R 1 $label }
proc ok  {label} { R 0 $label }
proc ok* {text}  { list 0 $text }

proc R {state label} {
    set path [td]/results/${label}
    if {[file exists $path]} {
	list $state [map [tcltest::viewFile $path]]
    } else {
	list $state {}
    }
}

proc store-scan {} {
    list 0 [map [join [lsort -dict [fileutil::find [md]/store]] \n]]
}

proc map {x} {
    lappend map <MD>  [md]
    lappend map <ACO> [a-core]
    lappend map <BCO> [b-core]
    lappend map <BCH> [b-chisel]
    lappend map <BGH> [b-github]
    string map $map $x
}

# # ## ### ##### ######## ############# #####################

proc a-core   {} { set _ https://core.tcl.tk/akupries/mirror }

proc b-core   {} { set _ https://core.tcl.tk/akupries/atom }
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
