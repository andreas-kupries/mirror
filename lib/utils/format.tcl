## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## General utilities - Formatting for display

# @@ Meta Begin
# Package m::format 0
# Meta author   {Andreas Kupries}
# Meta location https://core.tcl.tk/akupries/????
# Meta platform tcl
# Meta summary     Formatting values for display
# Meta description Formatting values for display
# Meta subject formatting display
# Meta require {Tcl 8.5-}
# @@ Meta End

package provide m::format 0
package require debug
package require debug::caller

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5

# # ## ### ##### ######## ############# ######################

debug level  m/format
debug prefix m/format {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval m::format {
    namespace export size epoch
    namespace ensemble create
}
namespace eval m {
    namespace export format
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################

proc m::format::size {x} {
    debug.m/format {}
                              if {$x < 1024} { return ${x}K }
    set x [expr {$x/1024.}] ; if {$x < 1024} { return [format %.1f $x]M }
    set x [expr {$x/1024.}] ; if {$x < 1024} { return [format %.1f $x]G }
    set x [expr {$x/1024.}] ; if {$x < 1024} { return [format %.1f $x]T }
    set x [expr {$x/1024.}] ; if {$x < 1024} { return [format %.1f $x]P }
    set x [expr {$x/1024.}] ;                  return [format %.1f $x]E
    return
}

proc m::format::epoch {epoch} {
    debug.m/format {}
    if {$epoch eq {}} return
    return [clock format $epoch -format {%Y-%m-%d %H:%M:%S}]
}

# # ## ### ##### ######## ############# #####################
return
