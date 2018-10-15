## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## Repositories - Validation

# @@ Meta Begin
# Package m::validate::submission 0 
# Meta author   {Andreas Kupries}
# Meta location https://core.tcl.tk/akupries/????
# Meta platform tcl
# Meta summary     mirror set validation
# Meta description mirror set validation
# Meta subject    {mirror set - validation}
# Meta require {Tcl 8.5-}
# @@ Meta End

package provide m::validate::submission 0

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

debug level  m/validate/submission
debug prefix m/validate/submission {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval ::m {
    namespace export validate
    namespace ensemble create
}
namespace eval ::m::validate {
    namespace export submission
    namespace ensemble create
}
namespace eval ::m::validate::submission {
    namespace export default validate complete release
    namespace ensemble create

    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}
# # ## ### ##### ######## ############# #####################

debug define m/validate/submission
debug level  m/validate/submission
debug prefix m/validate/submission {[debug caller] | }

# # ## ### ##### ######## ############# #####################

proc ::m::validate::submission::release  {p x} { return }
proc ::m::validate::submission::default  {p}   { return }
proc ::m::validate::submission::complete {p x} {
    debug.m/validate/submission {} 10
    return [complete-enum [dict keys [m submission known]] 0 $x]
}
proc ::m::validate::submission::validate {p x} {
    debug.m/validate/submission {}

    set known [m submission known]
    set match [m match substring id $known nocase $x]

    switch -exact -- $match {
	ok        { return $id }
	fail      { fail $p SUBMISSION "a submission"              $x }
	ambiguous { fail $p SUBMISSION "an unambiguous submission" $x }
    }
}

# # ## ### ##### ######## ############# #####################
## Ready
return
