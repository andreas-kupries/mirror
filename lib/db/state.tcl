## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## Database utilities - Mirror specific - State

# @@ Meta Begin
# Package m::state 0
# Meta author   {Andreas Kupries}
# Meta state https://core.tcl.tk/akupries/????
# Meta platform tcl
# Meta summary     Database state
# Meta description Database state
# Meta subject    {database state}
# Meta require {Tcl 8.5-}
# @@ Meta End

package provide m::state 0

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require m::db
package require debug
package require debug::caller

# # ## ### ##### ######## ############# ######################

debug level  m/state
debug prefix m/state {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval ::m {
    namespace export state
    namespace ensemble create
}
namespace eval ::m::state {
    namespace ensemble create -map [apply {{} {
	foreach k {
	    take store limit top phantom-block-threshold
	    store-window-size
	    report-mail-destination

	    mail-debug
	    mail-footer
	    mail-header
	    mail-host
	    mail-pass
	    mail-port
	    mail-sender
	    mail-tls
	    mail-user
	    mail-width

	    site-active
	    site-logo
	    site-mgr-mail
	    site-mgr-name
	    site-store
	    site-title
	    site-url
	    site-related-url
	    site-related-label

	    start-of-current-cycle
	    start-of-previous-cycle
	} {
	    dict set map $k [list ::m::state::Process $k]
	}
	return $map
    }}]
}

# # ## ### ##### ######## ############# #####################

proc ::m::state::Process {k {v {}}} {
    debug.m/state {}
    if {[llength [info level 0]] == 3} {
	return [Set $k $v]
    }
    return [Get $k]
}

proc ::m::state::Get {key} {
    debug.m/state {}
    return [m db onecolumn {
	SELECT value
	FROM   state
	WHERE  name = :key
    }]
}

proc ::m::state::Set {key value} {
    debug.m/state {}
    m db eval {
	UPDATE state
	SET    value = :value
	WHERE  name  = :key
    }
    return $value
}

# # ## ### ##### ######## ############# #####################
return
