## -*- tcl -*- (c) 2019
# # ## ### ##### ######## ############# #####################
## Test support - Application simulator II - mirror-vcs

kt require support fileutil

# level 0
kt local   testing db::setup
kt local   testing db::track
kt local   testing m::db::location
kt local   testing m::futil
kt local   testing m::msg

# level 1
kt local   testing m::exec

# level 2
kt local   testing m::db
kt local   testing m::vcs::fossil
kt local   testing m::vcs::git
kt local   testing m::vcs::github
kt local   testing m::vcs::hg
kt local   testing m::vcs::svn

# level 3
kt local   testing m::vcs::github

# level 4
kt local   testing m::vcs

# level 7
kt local   testing m::ops::client

kt::source support/invoke-core.tcl

# # ## ### ##### ######## ############# #####################

proc mvcs {args} {
    #puts stderr \nCALL\t(([info level 0]))

    capture-on
    try {
	set ::argv $args
	#puts stderr GO
	set r [list [m ops client main] [capture-get]]
    } finally {
	capture-done
	#puts stderr FIN\t//
    }
    return $r
}

# # ## ### ##### ######## ############# #####################

## Initialization of the pseudo-application to redirect all its state
## files and any input/output into locations related to the testsuite.
## Keep away from any installation files. Also cleanup of said state.

proc mvcs-initialize {} {
    file delete -force -- [md]
    file mkdir            [md]

    cmdr color activate 0

    set ::argv0 mirror-vcs
}

proc mvcs-finalize {} {
    file delete -force -- [md]
}

proc mvcs-reset {} {
    mvcs-initialize
}

mvcs-initialize

# Intercept process exit for state cleanup
rename ::exit ::exit_orig
proc   ::exit {args} {
    mvcs-finalize
    ::exit_orig {*}$args
}

# # ## ### ##### ######## ############# #####################
return
