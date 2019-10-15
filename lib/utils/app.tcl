## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## Database utilities - Operation tracking

# @@ Meta Begin
# Package m::app 0
# Meta author   {Andreas Kupries}
# Meta location https://core.tcl.tk/akupries/????
# Meta platform tcl
# Meta summary     Shared app support
# Meta description Shared app support
# Meta subject {app support}
# Meta require {Tcl 8.5-}
# @@ Meta End

package provide m::app 0
package require debug
package require debug::caller

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5

# # ## ### ##### ######## ############# ######################

debug level  m/app
debug prefix m/app {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval m {
    namespace export app
    namespace ensemble create
}
namespace eval m::app {
    namespace export debugflags
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################

proc ::m::app::debugflags {} {
    global argv env
    
    # (1) Process all --debug flags we can find. This is done before
    #     cmdr gets hold of the command line to enable the debugging
    #     of the innards of cmdr itself.
    # 
    # (2) Further activate debugging early when specified through the
    #     environment
    #
    # TODO: Put both of these into Cmdr, as convenience commands.

    set copy $argv
    while {[llength $copy]} {
	set copy [lassign $copy first]
	if {$first ne "--debug"} continue
	set copy [lassign $copy tag]
	debug on $tag
    }

    if {[info exists env(MIRROR_DEBUG)]} {
	foreach tag [split $env(MIRROR_DEBUG) ,] {
	    debug on [string trim $tag]
	}
	# Do not pass to any children.
	unset env(MIRROR_DEBUG)
    }
    return
}

# # ## ### ##### ######## ############# #####################
return
