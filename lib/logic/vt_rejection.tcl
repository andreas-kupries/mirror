## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## Repositories - Validation

# @@ Meta Begin
# Package m::validate::rejection 0
# Meta author   {Andreas Kupries}
# Meta location https://core.tcl.tk/akupries/????
# Meta platform tcl
# Meta summary     mirror set validation
# Meta description mirror set validation
# Meta subject    {mirror set - validation}
# Meta require {Tcl 8.5-}
# @@ Meta End

package provide m::validate::rejection 0

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require cmdr::validate::common 1.2
package require try
package require m::submission
package require m::match
package require debug
package require debug::caller

# # ## ### ##### ######## ############# ######################

debug level  m/validate/rejection
debug prefix m/validate/rejection {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval ::m {
    namespace export validate
    namespace ensemble create
}
namespace eval ::m::validate {
    namespace export rejection
    namespace ensemble create
}
namespace eval ::m::validate::rejection {
    namespace export default validate complete release
    namespace ensemble create

    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}
# # ## ### ##### ######## ############# #####################

debug define m/validate/rejection
debug level  m/validate/rejection
debug prefix m/validate/rejection {[debug caller] | }

# # ## ### ##### ######## ############# #####################

proc ::m::validate::rejection::release  {p x} { return }
proc ::m::validate::rejection::default  {p}   { return }
proc ::m::validate::rejection::complete {p x} {
    debug.m/validate/rejection {} 10
    return [complete-enum [dict keys [m submission rejected-known]] 0 $x]
}
proc ::m::validate::rejection::validate {p x} {
    debug.m/validate/rejection {}

    set known [m submission rejected-known]
    set match [m match substring id $known nocase $x]

    switch -exact -- $match {
	ok        { return $id }
	fail      { fail $p REJECTION "a rejection"              $x }
	ambiguous { fail $p REJECTION "an unambiguous rejection" $x }
    }
}

# # ## ### ##### ######## ############# #####################
## Ready
return
