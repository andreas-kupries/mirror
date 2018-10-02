## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## Version Control Systems - Validation

# @@ Meta Begin
# Package m::validate::vcs 0 
# Meta author   {Andreas Kupries}
# Meta location https://core.tcl.tk/akupries/????
# Meta platform tcl
# Meta summary     Version control validation
# Meta description Version control validation
# Meta subject    {version control - validation}
# Meta require {Tcl 8.5-}
# @@ Meta End

package provide m::validate::vcs 0

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require cmdr::validate::common 1.2
package require try
package require m::vcs
package require debug
package require debug::caller

# # ## ### ##### ######## ############# ######################

debug level  m/validate/vcs
debug prefix m/validate/vcs {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval ::m {
    namespace export validate
    namespace ensemble create
}
namespace eval ::m::validate {
    namespace export vcs
    namespace ensemble create
}
namespace eval ::m::validate::vcs {
    namespace export default validate complete release
    namespace ensemble create

    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}
# # ## ### ##### ######## ############# #####################

debug define m/validate/vcs
debug level  m/validate/vcs
debug prefix m/validate/vcs {[debug caller] | }

# # ## ### ##### ######## ############# #####################

proc ::m::validate::vcs::release  {p x} { return }
proc ::m::validate::vcs::default  {p}   { return [m vcs id fossil] }
proc ::m::validate::vcs::complete {p x} {
    debug.m/validate/vcs {} 10
    return [complete-enum [m vcs supported] 0 $x]
}
proc ::m::validate::vcs::validate {p x} {
    debug.m/validate/vcs {}

    try {
	return [m vcs id $x]
    } on error {e o} {
	fail $p VCS-CODE "a vcs code or name" $x
    }
}

# # ## ### ##### ######## ############# #####################
## Ready
return
