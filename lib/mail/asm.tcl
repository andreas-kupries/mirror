## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package m::mail::asm 0
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
package require debug
package require debug::caller

# # ## ### ##### ######## ############# ######################

namespace eval ::m {
    namespace export mail::asm
    namespace ensemble create
}
namespace eval ::m::mail::asm {
    namespace export begin done headers body +
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################

debug level  m/mail/asm
debug prefix m/mail/asm {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::m::mail::asm::begin {sender subject} {
    debug.m/mail/asm {}
    upvar 1 __lines __lines __sender sender
    set     lines {}

    set date [clock format [clock seconds] -format {%d %b %Y %H:%M:%S %z}]
    + "Subject: $subject"
    + "Date:    $date"
    + "X-Mirror-Note:"
    + "X-Tool-Origin: http://core.tcl.tk/akupries/mirror"
    return
}

proc ::m::mail::asm::done {footer} {
    debug.m/mail/asm {}
    upvar 1 __lines __lines __sender sender

    if {$footer ne {}} {
	# separate footer from mail body
	lappend map @sender@ $sender
	lappend map @cmd@    [file tail $::argv0]

	+ ""
	+ [string repeat - 60]
	+ [string map $map $footer]
	+ [string repeat - 60]
    }

    + ""
    return -code return [join $lines \n]
}

proc ::m::mail::asm::+ {line} {
    debug.m/mail/asm {}
    upvar 1 __lines __lines
    lappend __lines $line
    return
}

proc ::m::mail::asm::body {header} {
    debug.m/mail/asm {}
    upvar 1 __lines __lines __sender sender
    + ""
    if {$header ne {}} {
	lappend map @sender@ $sender
	lappend map @sender  $sender
	lappend map @cmd@    [file tail $::argv0]
	+ [string map $map $header]
	+ ""
    }
    return
}

# # ## ### ##### ######## ############# ######################
package provide m::mail::asm 0
return
