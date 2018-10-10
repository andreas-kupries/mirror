## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## Simplified execution of external commands.

# @@ Meta Begin
# Package m::exec 0 
# Meta author   {Andreas Kupries}
# Meta location https://core.tcl.tk/akupries/????
# Meta platform tcl
# Meta summary     Simplified execution of external commands.
# Meta description Simplified execution of external commands.
# Meta subject     {exec simplified api}
# Meta require {Tcl 8.5-}
# @@ Meta End

package provide m::exec 0

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require debug
package require debug::caller

# # ## ### ##### ######## ############# ######################

debug level  m/exec
debug prefix m/exec {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval ::m {
    namespace export exec
    namespace ensemble create
}

namespace eval ::m::exec {
    namespace export verbose go get silent
    namespace ensemble create
}

# # ## ### ##### ######## ############# #####################

proc ::m::exec::verbose {{newvalue {}}} {
    debug.m/exec {}
    variable verbose
    if {[llength [info level 0]] == 2} {
	set verbose $newvalue
    }
    return $verbose
}

# # ## ### ##### ######## ############# #####################

proc ::m::exec::go {args} {
    debug.m/exec {}
    variable verbose
    if {$verbose} {
	puts "> $args"
	exec 2>@ stderr >@ stdout {*}$args
    } else {
	exec 2>  [NULL] >  [NULL] {*}$args
    }
    return
}

proc ::m::exec::get {args} {
    debug.m/exec {}
    variable verbose
    if {$verbose} {
	puts "> $args"
	return [exec 2>@ stderr {*}$args]
    } else {
	return [exec 2>  [NULL] {*}$args]
    }
}

proc ::m::exec::silent {args} {
    debug.m/exec {}
    exec 2> [NULL] > [NULL] {*}$args
    return
}

if {$tcl_platform(platform) eq "windows"} {
    proc ::m::exec::NULL {} {
	debug.m/exec {}
	return NUL:
    }
} else {
    proc ::m::exec::NULL {} {
	debug.m/exec {}
	return /dev/null
    }
}

namespace eval ::m::exec {
    variable verbose off
}

# # ## ### ##### ######## ############# #####################
return
