## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## Validation helper - Matching

# @@ Meta Begin
# Package m::match 0 
# Meta author   {Andreas Kupries}
# Meta location https://core.tcl.tk/akupries/????
# Meta platform tcl
# Meta summary     Match helper for validation
# Meta description Match helper for validation
# Meta subject     validation matching
# Meta require {Tcl 8.5-}
# @@ Meta End

package provide m::match 0

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require cmdr::validate::common
package require debug
package require debug::caller

# # ## ### ##### ######## ############# ######################

debug level  m/match
debug prefix m/match {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval ::m {
    namespace export match
    namespace ensemble create
}

namespace eval ::m::match {
    namespace export substring
    namespace ensemble create

    namespace import ::cmdr::validate::common::complete-substr
    namespace import ::cmdr::validate::common::complete-enum
}

# # ## ### ##### ######## ############# #####################

proc ::::m::match::substring {iv known nocase x} {
    debug.m/match {}

    upvar 1 $iv id

    if {($nocase eq "nocase") || $nocase} { set x [string tolower $x] }

    # Check for exact match first, this trumps substring matching,
    # especially if substring matching would be ambiguous.
    if {[dict exists $known $x]} {
	set id [dict get $known $x]
	return ok
    }

    # Check for substring matches. Convert to ids and deduplicate
    # before deciding if the mismatch was due to ambiguity of the
    # input.

    set matches [complete-substr [dict keys $known] $nocase $x]
    set n [llength $matches]
    if {!$n} {
	return fail
    }

    set ids {}
    foreach m $matches {
	lappend ids [dict get $known $m]
    }
    set ids [lsort -unique $ids]
    set n [llength $ids]

    if {$n > 1} {
	return ambiguous
    }

    # Uniquely identified, success
    set id [lindex $ids 0]
    return ok
}

proc ::::m::match::enum {iv known nocase x} {
    debug.m/match {}

    upvar 1 $iv id

    if {($nocase eq "nocase") || $nocase} { set x [string tolower $x] }

    # Check for exact match first, this trumps prefix matching,
    # especially if prefix matching would be ambigous.
    if {[dict exists $known $x]} {
	set id [dict get $known $x]
	return ok
    }

    # Check for prefix matches. Convert to ids and deduplicate before
    # deciding if the mismatch was due to ambiguity of the input.

    set matches [complete-enum [dict keys $known] $nocase $x]
    set n [llength $matches]
    if {!$n} {
	return fail
    }

    set ids {}
    foreach m $matches {
	lappend ids [dict get $known $m]
    }
    set ids [lsort -unique $ids]
    set n [llength $ids]

    if {$n > 1} {
	return ambiguous
    }

    # Uniquely identified, success
    set id [lindex $ids 0]
    return ok
}

# # ## ### ##### ######## ############# #####################
return
