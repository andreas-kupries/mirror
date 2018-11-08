## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## Simplified execution of external commands.

# @@ Meta Begin
# Package m::exec 0 
# Meta author   {Andreas Kupries}
# Meta location https://core.tcl.tk/akupries/????
# Meta platform tcl
# Meta summary     Simplified execution of external commands.
# Meta description Simplified execution of external commands.
# Meta subject     {exec simplified api}
# Meta require {Tcl 8.5-}
# @@ Meta End

package provide m::exec 0

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require debug
package require debug::caller
package require m::msg

# # ## ### ##### ######## ############# ######################

debug level  m/exec
debug prefix m/exec {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval ::m {
    namespace export exec
    namespace ensemble create
}

namespace eval ::m::exec {
    namespace export verbose go get silent capture
    namespace ensemble create
}

namespace eval ::m::exec::capture {
    namespace export to on off clear get path active
    namespace ensemble create
}

# # ## ### ##### ######## ############# #####################
## Capture management

proc ::m::exec::capture::to {stdout stderr {enable 1}} {
    debug.m/exec {}
    # Set clear capture destinations, and start (default).
    variable out $stdout
    variable err $stderr
    clear
    variable active  $enable
    return
}

proc ::m::exec::capture::off {} {
    debug.m/exec {}
    # Stop capture.
    variable active 0
    return
}

proc ::m::exec::capture::on {} {
    # Start capture. Error if no destinations specified
    debug.m/exec {}
    variable out
    variable err
    if {($err eq "") || ($out eq "")} {
	return -code error \
	    -errorcode {M EXEC CAPTURE NO DESTINATION} \
	    "Unable to start capture without destination"
    }
    variable active 1
    return
}

proc ::m::exec::capture::clear {} {
    # Clear the capture buffers
    debug.m/exec {}
    C out
    C err
    return
}

proc ::m::exec::capture::get {var} {
    # Get captured content
    debug.m/exec {}
    set path [path $var]
    if {$path eq {}} return
    set c [open $path r]
    set d [read $c]
    close $c
    return $d
}

proc ::m::exec::capture::path {var} {
    # Get path of capture buffer
    debug.m/exec {}
    variable $var
    upvar  0 $var path
    return $path
}

proc ::m::exec::capture::active {} {
    # Query state of capture system
    debug.m/exec {}
    variable active
    return  $active
}

proc ::m::exec::capture::C {var} {
    debug.m/exec {}
    variable $var
    upvar 0 $var path
    if {$path eq {}} return
    # open for writing, truncates.
    close [open $path w]
    return
}

# # ## ### ##### ######## ############# #####################

proc ::m::exec::verbose {{newvalue {}}} {
    debug.m/exec {}
    variable verbose
    if {[llength [info level 0]] == 2} {
	set verbose $newvalue
    }
    return $verbose
}

# # ## ### ##### ######## ############# #####################

proc ::m::exec::go {args} {
    debug.m/exec {}
    variable verbose
    if {$verbose} {
	m msg "> $args"
	exec 2>@ stderr >@ stdout {*}$args
    } else {
	exec 2>  [NULL] >  [NULL] {*}$args
    }
    return
}

proc ::m::exec::get {args} {
    debug.m/exec {}
    variable verbose
    if {$verbose} {
	m msg "> $args"
	return [exec 2>@ stderr {*}$args]
    } else {
	return [exec 2>  [NULL] {*}$args]
    }
}

proc ::m::exec::silent {args} {
    debug.m/exec {}
    variable verbose
    if {$verbose} {
	m msg "> $args"
    }
    exec 2> [NULL] > [NULL] {*}$args
    return
}

if {$tcl_platform(platform) eq "windows"} {
    proc ::m::exec::NULL {} {
	debug.m/exec {}
	return NUL:
    }
} else {
    proc ::m::exec::NULL {} {
	debug.m/exec {}
	return /dev/null
    }
}

# # ## ### ##### ######## ############# #####################
## State

namespace eval ::m::exec {
    variable verbose off
}

namespace eval ::m::exec::capture {
    variable active  0
    variable out {}
    variable err {}
}

# # ## ### ##### ######## ############# #####################
return
