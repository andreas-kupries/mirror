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
    namespace export take store limit top
    namespace ensemble create
}

# # ## ### ##### ######## ############# #####################

proc ::m::state::take {{v {}}} {
    debug.m/state {}
    if {[llength [info level 0]] == 2} {
	return [Set take $v]
    }
    return [Get take]
}

proc ::m::state::store {{v {}}} {
    debug.m/state {}
    if {[llength [info level 0]] == 2} {
	return [Set store $v]
    }
    return [Get store]
}

proc ::m::state::limit {{v {}}} {
    debug.m/state {}
    if {[llength [info level 0]] == 2} {
	return [Set limit $v]
    }
    return [Get limit]
}

proc ::m::state::top {{v {}}} {
    debug.m/state {}
    if {[llength [info level 0]] == 2} {
	return [Set top $v]
    }
    return [Get top]
}

# # ## ### ##### ######## ############# #####################

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
