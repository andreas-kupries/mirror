## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## Helpers for file processing. Simplified tcllib fileutil.

# @@ Meta Begin
# Package m::futil 0 
# Meta author   {Andreas Kupries}
# Meta location https://core.tcl.tk/akupries/????
# Meta platform tcl
# Meta summary     Helpers for file access
# Meta description Helpers for file access
# Meta subject     {file utilities} cat append grep write
# Meta require {Tcl 8.5-}
# @@ Meta End

package provide m::futil 0

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require debug
package require debug::caller
package require m::msg

# # ## ### ##### ######## ############# ######################

debug level  m/futil
debug prefix m/futil {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval ::m {
    namespace export futil
    namespace ensemble create
}

namespace eval ::m::futil {
    namespace export cat write append grep m-grep
    namespace ensemble create
}

# # ## ### ##### ######## ############# #####################

proc ::m::futil::cat {path} {
    debug.m/futil {}
    set c [open $path r]
    set d [read $c]
    close $c
    return $d
}

proc ::m::futil::write {path content} {
    debug.m/futil {}
    set c [open $path w]
    puts -nonewline $c $content
    close $c
    return
}

proc ::m::futil::append {path content} {
    debug.m/futil {}
    set c [open $path a]
    puts -nonewline $c $content
    close $c
    return
}

proc ::m::futil::grep {pattern lines} {
    debug.m/futil {}
    set match {}
    set mis   {}
    foreach line $lines {
	if {[regexp -- $pattern $line]} {
	    lappend match $line
	} else {
	    lappend mis $line
	}
    }
    return [list $match $mis]
}

proc ::m::futil::m-grep {patterns lines} {
    debug.m/futil {}
    set match {}
    set mis   {}
    foreach line $lines {	
	if {[MG $patterns $line]} {
	    lappend match $line
	} else {
	    lappend mis $line
	}
    }
    return [list $match $mis]
}

proc ::m::futil::MG {patterns line} {
    debug.m/futil {}
    foreach pattern $patterns {
	if {[regexp -- $pattern $line]} {return 1}
    }
    return 0
}

# # ## ### ##### ######## ############# #####################
## State

namespace eval ::m::futil {}

# # ## ### ##### ######## ############# #####################
return
