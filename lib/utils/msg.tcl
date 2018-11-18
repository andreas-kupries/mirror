## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## General utilities - messaging

# @@ Meta Begin
# Package m::msg 0
# Meta author   {Andreas Kupries}
# Meta location https://core.tcl.tk/akupries/mirror
# Meta platform tcl
# Meta summary     Messaging
# Meta description Messaging
# Meta subject     message print
# Meta require {Tcl 8.5-}
# @@ Meta End

package provide m::msg 0
package require debug
package require debug::caller

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5

# # ## ### ##### ######## ############# ######################

debug level  m/msg
debug prefix m/msg {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval m {
    namespace export msg msg* emsg
    namespace ensemble create
}

namespace eval m::msg {
}

# # ## ### ##### ######## ############# ######################

proc ::m::msg {text} {
    debug.m/msg {}
    msg::Write $text
    return
}

proc ::m::emsg {text} {
    debug.m/msg {}
    msg::EWrite $text
    return
}

proc ::m::msg* {text} {
    debug.m/msg {}
    msg::Write -nonewline $text
    return
}

proc ::m::msg::set {args} {
    debug.m/msg {}
    variable writecmd $args
    return
}

proc ::m::msg::sete {args} {
    debug.m/msg {}
    variable writecmde $args
    return
}

proc ::m::msg::Write {args} {
    debug.m/msg {}
    variable writecmd
    if {![llength $writecmd]} return
    uplevel #0 [list {*}$writecmd {*}$args]
    return
}

proc ::m::msg::EWrite {args} {
    debug.m/msg {}
    variable writecmde
    if {![llength $writecmde]} return
    uplevel #0 [list {*}$writecmde {*}$args]
    return
}

proc ::m::msg::PO {args} {
    ::puts {*}$args
    flush  stdout
    return
}

proc ::m::msg::PE {args} {
    ::puts stderr {*}$args
    flush  stderr
    return
}

namespace eval m::msg {
    variable writecmd  ::m::msg::PO
    variable writecmde ::m::msg::PE
}

# # ## ### ##### ######## ############# #####################
return
