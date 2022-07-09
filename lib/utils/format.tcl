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
    namespace export size epoch epoch/short interval win win-trim
    namespace ensemble create
}
namespace eval m {
    namespace export format
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################

proc m::format::win {lastn} {
    # CSV to list, remove bubbles (empty elements)
    return [lmap x [split $lastn ,] { if {$x eq {}} continue ; set x }]
}

proc m::format::win-trim {lastn max} {
    set len [llength $lastn]
    # As new entries are added at the end trimming is done from the front.
    # This is a naive trimmer, removing elements one by one.
    # Considered ok because we usually need only remove one element anyway.
    while {$len > $max} {
	set lastn [lrange  $lastn 1 end]
	set len   [llength $lastn]
    }
    return $lastn
}

# # ## ### ##### ######## ############# ######################

proc m::format::size {x} {
    # x is in [KB].
    debug.m/format {}
    if {![string is integer -strict $x]} { return $x }

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

proc m::format::epoch/short {epoch} {
    debug.m/format {}
    if {$epoch eq {}} return
    return [clock format $epoch -format {%Y-%m-%d %H:%M}]
}

proc ::m::format::interval {seconds} {
    debug.m/format {}
    if {$seconds eq {}} {
	return "-"
    }
    if {$seconds < 60} {
	return "${seconds}s"
    }

    set minutes [expr {$seconds / 60}]
    set seconds [expr {$seconds % 60}]

    if {$minutes < 60} {
	append r $minutes m
	if {$seconds} { append r $seconds s }
	return $r
    }

    set hours   [expr {$minutes / 60}]
    set minutes [expr {$minutes % 60}]

    if {$hours < 24} {
	append r $hours h
	if {$minutes} { append r $minutes m }
	if {$seconds} { append r $seconds s }
	return $r
    }

    set days  [expr {$hours / 24}]
    set hours [expr {$hours % 24}]

    append r $days d
    if {$hours}   { append r $hours h }
    if {$minutes} { append r $minutes m }
    if {$seconds} { append r $seconds s }
    return $r
}

# # ## ### ##### ######## ############# #####################
return
