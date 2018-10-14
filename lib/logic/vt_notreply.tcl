## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## Repositories - Validation

# @@ Meta Begin
# Package m::validate::notreply 0 
# Meta author   {Andreas Kupries}
# Meta location https://core.tcl.tk/akupries/????
# Meta platform tcl
# Meta summary     Notreply validation
# Meta description Notreply validation
# Meta subject    {notreply - validation}
# Meta require {Tcl 8.5-}
# @@ Meta End

package provide m::validate::notreply 0

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require cmdr::validate::common 1.2
package require try
package require m::reply
package require m::match
package require debug
package require debug::caller

# # ## ### ##### ######## ############# ######################

debug level  m/validate/notreply
debug prefix m/validate/notreply {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval ::m {
    namespace export validate
    namespace ensemble create
}
namespace eval ::m::validate {
    namespace export notreply
    namespace ensemble create
}
namespace eval ::m::validate::notreply {
    namespace export default validate complete release
    namespace ensemble create

    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}
# # ## ### ##### ######## ############# #####################

debug define m/validate/notreply
debug level  m/validate/notreply
debug prefix m/validate/notreply {[debug caller] | }

# # ## ### ##### ######## ############# #####################

proc ::m::validate::notreply::release  {p x} { return }
proc ::m::validate::notreply::default  {p}   { return }
proc ::m::validate::notreply::complete {p x} { return } ;# check cm/fx
proc ::m::validate::notreply::validate {p x} {
    debug.m/validate/notreply {}

    set known [m reply known]
    set match [m match substring id $known nocase $x]

    # check cm/fx for pattern
    switch -exact -- $match {
	ok        { fail $p NOTREPLY "unknown reply name" $x }
	fail      { return $x }
	ambiguous { return $x }
    }
}

# # ## ### ##### ######## ############# #####################
## Ready
return
