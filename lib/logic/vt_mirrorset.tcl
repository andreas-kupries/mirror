## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## Repositories - Validation

# @@ Meta Begin
# Package m::validate::mset 0 
# Meta author   {Andreas Kupries}
# Meta location https://core.tcl.tk/akupries/????
# Meta platform tcl
# Meta summary     mirror set validation
# Meta description mirror set validation
# Meta subject    {mirror set - validation}
# Meta require {Tcl 8.5-}
# @@ Meta End

package provide m::validate::mset 0

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

debug level  m/validate/mset
debug prefix m/validate/mset {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval ::m {
    namespace export validate
    namespace ensemble create
}
namespace eval ::m::validate {
    namespace export mset
    namespace ensemble create
}
namespace eval ::m::validate::mset {
    namespace export default validate complete release
    namespace ensemble create

    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}
# # ## ### ##### ######## ############# #####################

debug define m/validate/mset
debug level  m/validate/mset
debug prefix m/validate/mset {[debug caller] | }

# # ## ### ##### ######## ############# #####################

proc ::m::validate::mset::release  {p x} { return }
proc ::m::validate::mset::default  {p}   {
    return [m repo mset [m rolodex top]]
}
proc ::m::validate::mset::complete {p x} {
    debug.m/validate/mset {} 10
    return [complete-enum [dict keys [m mset known]] 0 $x]
}
proc ::m::validate::mset::validate {p x} {
    debug.m/validate/mset {}

    set known [m repo known]
    set match [m match substring id $known nocase $x]

    switch -exact -- $match {
	ok        { return $id }
	fail      { fail $p MSET "a mirror set"              $x }
	ambiguous { fail $p MSET "an unambiguous mirror set" $x }
    }
}

# # ## ### ##### ######## ############# #####################
## Ready
return
