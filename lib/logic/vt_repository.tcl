## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## Repositories - Validation

# @@ Meta Begin
# Package m::validate::repository 0
# Meta author   {Andreas Kupries}
# Meta location https://core.tcl.tk/akupries/????
# Meta platform tcl
# Meta summary     Repository validation
# Meta description Repository validation
# Meta subject    {repository - validation}
# Meta require {Tcl 8.5-}
# @@ Meta End

package provide m::validate::repository 0

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

debug level  m/validate/repository
debug prefix m/validate/repository {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval ::m {
    namespace export validate
    namespace ensemble create
}
namespace eval ::m::validate {
    namespace export repository
    namespace ensemble create
}
namespace eval ::m::validate::repository {
    namespace export default validate complete release
    namespace ensemble create

    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}
# # ## ### ##### ######## ############# #####################

debug define m/validate/repository
debug level  m/validate/repository
debug prefix m/validate/repository {[debug caller] | }

# # ## ### ##### ######## ############# #####################

proc ::m::validate::repository::release  {p x} { return }
proc ::m::validate::repository::default  {p}   {
    return [m rolodex top]
}
proc ::m::validate::repository::complete {p x} {
    debug.m/validate/repository {} 10
    return [complete-enum [dict keys [m repo known]] 0 $x]
}
proc ::m::validate::repository::validate {p x} {
    debug.m/validate/repository {}

    set known [m repo known]
    set match [m match substring id $known nocase $x]

    switch -exact -- $match {
	ok        { return $id }
	fail      { fail $p REPOSITORY "a repository"              $x }
	ambiguous { fail $p REPOSITORY "an unambiguous repository" $x }
    }
}

# # ## ### ##### ######## ############# #####################
## Ready
return
