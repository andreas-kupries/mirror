## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## Repositories - Validation

# @@ Meta Begin
# Package m::validate::url 0
# Meta author   {Andreas Kupries}
# Meta location https://core.tcl.tk/akupries/????
# Meta platform tcl
# Meta summary     Url validation
# Meta description Url validation
# Meta subject    {url - validation}
# Meta require {Tcl 8.5-}
# @@ Meta End

package provide m::validate::url 0

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require cmdr::validate::common 1.2
package require try
package require m::url
package require debug
package require debug::caller

# # ## ### ##### ######## ############# ######################

debug level  m/validate/url
debug prefix m/validate/url {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval ::m {
    namespace export validate
    namespace ensemble create
}
namespace eval ::m::validate {
    namespace export url
    namespace ensemble create
}
namespace eval ::m::validate::url {
    namespace export default validate complete release
    namespace ensemble create

    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}
# # ## ### ##### ######## ############# #####################

debug define m/validate/url
debug level  m/validate/url
debug prefix m/validate/url {[debug caller] | }

# # ## ### ##### ######## ############# #####################

proc ::m::validate::url::release  {p x} { return }
proc ::m::validate::url::default  {p}   { return {} }
proc ::m::validate::url::complete {p x} { return {} }
proc ::m::validate::url::validate {p x} {
    debug.m/validate/url {}

    if {[m url ok $x xr]} {
	return $xr
    }

    fail $p URL "an url" $x
}

# # ## ### ##### ######## ############# #####################
## Ready
return
