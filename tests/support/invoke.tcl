## -*- tcl -*- (c) 2018
# # ## ### ##### ######## ############# #####################
## Test support - Application simulator I - mirror

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
kt local   testing m::vcs::hg
kt local   testing m::vcs::svn

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

kt::source support/invoke-core.tcl

# # ## ### ##### ######## ############# #####################

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
