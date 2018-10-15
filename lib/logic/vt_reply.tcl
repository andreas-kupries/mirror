## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## Repositories - Validation

# @@ Meta Begin
# Package m::validate::reply 0 
# Meta author   {Andreas Kupries}
# Meta location https://core.tcl.tk/akupries/????
# Meta platform tcl
# Meta summary     Reply validation
# Meta description Reply validation
# Meta subject    {reply - validation}
# Meta require {Tcl 8.5-}
# @@ Meta End

package provide m::validate::reply 0

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

debug level  m/validate/reply
debug prefix m/validate/reply {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval ::m {
    namespace export validate
    namespace ensemble create
}
namespace eval ::m::validate {
    namespace export reply
    namespace ensemble create
}
namespace eval ::m::validate::reply {
    namespace export default validate complete release
    namespace ensemble create

    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}
# # ## ### ##### ######## ############# #####################

debug define m/validate/reply
debug level  m/validate/reply
debug prefix m/validate/reply {[debug caller] | }

# # ## ### ##### ######## ############# #####################

proc ::m::validate::reply::release  {p x} { return }
proc ::m::validate::reply::default  {p}   {
    debug.m/validate/reply {}
    set d [m reply default]
    debug.m/validate/reply {=> ($d)}
    return $d
}
proc ::m::validate::reply::complete {p x} {
    debug.m/validate/reply {} 10
    return [complete-enum [dict keys [m reply known]] 0 $x]
}
proc ::m::validate::reply::validate {p x} {
    debug.m/validate/reply {}

    set known [m reply known]
    set match [m match substring id $known nocase $x]

    switch -exact -- $match {
	ok        { return $id }
	fail      { fail $p REPLY "a reply name"              $x }
	ambiguous { fail $p REPLY "an unambiguous reply name" $x }
    }
}

# # ## ### ##### ######## ############# #####################
## Ready
return
