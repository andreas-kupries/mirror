## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## Repositories - Validation

# @@ Meta Begin
# Package m::validate::project 0
# Meta author   {Andreas Kupries}
# Meta location https://core.tcl.tk/akupries/????
# Meta platform tcl
# Meta summary     mirror set validation
# Meta description mirror set validation
# Meta subject    {mirror set - validation}
# Meta require {Tcl 8.5-}
# @@ Meta End

package provide m::validate::project 0

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require cmdr::validate::common 1.2
package require try
package require m::project
package require m::repo
package require m::rolodex
package require m::match
package require debug
package require debug::caller

# # ## ### ##### ######## ############# ######################

debug level  m/validate/project
debug prefix m/validate/project {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval ::m {
    namespace export validate
    namespace ensemble create
}
namespace eval ::m::validate {
    namespace export project
    namespace ensemble create
}
namespace eval ::m::validate::project {
    namespace export default validate complete release
    namespace ensemble create

    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}
# # ## ### ##### ######## ############# #####################

debug define m/validate/project
debug level  m/validate/project
debug prefix m/validate/project {[debug caller] | }

# # ## ### ##### ######## ############# #####################

proc ::m::validate::project::release  {p x} { return }
proc ::m::validate::project::default  {p}   {
    return [m repo project [m rolodex top]]
}
proc ::m::validate::project::complete {p x} {
    debug.m/validate/project {} 10
    return [complete-enum [dict keys [m project known]] 0 $x]
}
proc ::m::validate::project::validate {p x} {
    debug.m/validate/project {}

    set known [m project known]
    set match [m match substring id $known nocase $x]

    switch -exact -- $match {
	ok        { return $id }
	fail      { fail $p PROJECT "a project"              $x }
	ambiguous { fail $p PROJECT "an unambiguous project" $x }
    }
}

# # ## ### ##### ######## ############# #####################
## Ready
return
