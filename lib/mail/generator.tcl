## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package m::mail::generator 0
# Meta author      {Andreas Kupries}
# Meta category    ?
# Meta description ?
# Meta location    http:/core.tcl.tk/akupries/mirror
# Meta platform    tcl
# Meta require     
# Meta subject     
# Meta summary     ?
# @@ Meta End

# # ## ### ##### ######## ############# ######################

package require Tcl 8.5
package require m::state
package require m::mail::asm
package require m::reply
package require debug
package require debug::caller

# # ## ### ##### ######## ############# ######################

namespace eval ::m {
    namespace export mail::generator
    namespace ensemble create
}
namespace eval ::m::mail::generator {
    namespace export test reply
    namespace ensemble create
    
    namespace import ::m::mail::asm
}

# # ## ### ##### ######## ############# ######################

debug level  m/mail/generator
debug prefix m/mail/generator {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::m::mail::generator::test {} {
    debug.m/mail/generator {}
    asm begin [m state mail-sender] "Mirror mail configuration test mail"
    asm body  [m state mail-header]
    asm +     "Testing ... 1, 2, 3 ..."
    asm done  [m state mail-footer]
}

proc ::m::mail::generator::reply {template submission} {
    debug.m/mail/generator {}
    # submission data ... receiver, url, other things ...
    ##
    # url
    # mset name
    # submitter name
    # email
    # submission date (epoch)

    dict for {k v} $submission {
	lappend map @s:${k}@ [T-$k $v]
    }

    # First line of the template is the mail subject.
    # The remainder is the mail body.
    set template [m mail template $template]
    set body     [join [lassign [split $template \n] subject] \n]
    
    asm begin [m state sender] [string map $map $subject]
    asm body [string map $map [m state header]]
    asm +    [string map $map $body]
    asm done [string map $map [m state footer]]
}

# # ## ### ##### ######## ############# ######################

proc ::m::mail::generator::T- {value} {
    set value
}

# # ## ### ##### ######## ############# ######################
package provide m::mail::generator 0
return
