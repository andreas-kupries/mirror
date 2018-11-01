## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## Test support - Application simulator

kt require support linenoise::facade ;# m::cmdr references, cannot local cannot use modules
kt require support cmdr::history
kt require support cmdr::color

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
    m::msg::set  ::Collect
    m::msg::sete ::Collect
    CollectReset
    list [m::cmdr::main $args] [CollectGet]
}

proc CollectGet {} {
    variable stdout
    return [string trim $stdout]
}

proc CollectReset {} {
    variable stdout {}
    return
}

proc Collect {args} {
    set nonewline 0
    if {[lindex $args 0] eq "-nonewline"} {
	set nonewline 1
	set args [lrange $args 1 end]
    }
    if {[llength $args] != 1} {
	error "Bad syntax: [info level 0]"
    }
    variable stdout
    append   stdout [lindex $args 0]
    if {$nonewline} return
    append stdout \n
    return
}

proc err {label} { R 1 $label }
proc ok  {label} { R 0 $label }
proc ok* {text}  { list 0 $text }

proc R {state label} {
    set path [td]/results/${label}
    if {[file exists $path]} {
	list $state [tcltest::viewFile $path]
    } else {
	list $state {}
    }
}

# # ## ### ##### ######## ############# #####################
## Initialization of the pseudo-application to redirect all its state
## files and any input/output into locations related to the testsuite.
## Keep away from any installation files.

file delete -force -- [md]
file mkdir            [md]

cmdr color activate 0

cmdr history initial-limit 0
cmdr history save-to [md]/history

m::db::location::set [md]/sqlite3
m::state store       [md]/store

set ::argv0 mirror

# # ## ### ##### ######## ############# #####################
return
