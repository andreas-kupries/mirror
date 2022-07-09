## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## Repositories - Validation

# @@ Meta Begin
# Package m::validate::limit 0
# Meta author   {Andreas Kupries}
# Meta location https://core.tcl.tk/akupries/????
# Meta platform tcl
# Meta summary     Limit validation
# Meta description Limit validation
# Meta subject    {limit - validation}
# Meta require {Tcl 8.5-}
# @@ Meta End

package provide m::validate::limit 0

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require cmdr::validate::common 1.2
package require try
package require m::repo
package require m::rolodex
package require m::match
package require debug
package require debug::caller

# # ## ### ##### ######## ############# ######################

debug level  m/validate/limit
debug prefix m/validate/limit {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval ::m {
    namespace export validate
    namespace ensemble create
}
namespace eval ::m::validate {
    namespace export limit
    namespace ensemble create
}
namespace eval ::m::validate::limit {
    namespace export default validate complete release
    namespace ensemble create

    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}
# # ## ### ##### ######## ############# #####################

debug define m/validate/limit
debug level  m/validate/limit
debug prefix m/validate/limit {[debug caller] | }

# # ## ### ##### ######## ############# #####################

proc ::m::validate::limit::release  {p x} { return }
proc ::m::validate::limit::default  {p}   { return 20 }
proc ::m::validate::limit::complete {p x} { return {} }
proc ::m::validate::limit::validate {p x} {
    debug.m/validate/limit {}

    if {[string is entier $x] && ($x > 0)} {
	return $x
    }
    if {$x eq "auto"} {
	return 0 ;# internal rep for auto
    }

    fail $p LIMIT "a limit" $x
}

# # ## ### ##### ######## ############# #####################
## Ready
return
