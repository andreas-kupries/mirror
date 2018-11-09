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
    B $enable
    # Set clear capture destinations, and start (default).
    # Note: Be independent of future CWD changes.
    variable out [file normalize $stdout]
    variable err [file normalize $stderr]
    clear
    variable active $enable
    return
}

proc ::m::exec::capture::off {{reset 0}} {
    debug.m/exec {}
    # Stop capture.
    B $reset
    variable active 0
    if {!$reset} return
    variable out {}
    variable err {}
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

proc ::m::exec::capture::get {key} {
    # Get captured content
    debug.m/exec {}
    V $key
    set path [P $key]
    if {$path eq {}} return
    set c [open $path r]
    set d [read $c]
    close $c
    return $d
}

proc ::m::exec::capture::path {key} {
    # Get path of capture buffer
    debug.m/exec {}
    V $key
    return [P $key]
}

proc ::m::exec::capture::active {} {
    # Query state of capture system
    debug.m/exec {}
    variable active
    return  $active
}

proc ::m::exec::capture::P {key} {
    # Get path of capture buffer
    debug.m/exec {}
    variable $key
    upvar  0 $key path
    return $path
}

proc ::m::exec::capture::C {key} {
    debug.m/exec {}
    variable $key
    upvar 0 $key path
    if {$path eq {}} return
    # open for writing, truncates.
    close [open $path w]
    return
}

proc ::m::exec::capture::V {key} {
    debug.m/exec {}
    if {$key in {out err}} return
    return -code error \
	    -errorcode {M EXEC CAPTURE BAD KEY} \
	    "Bad channel key $key"
}

proc ::m::exec::capture::B {x} {
    debug.m/exec {}
    if {[string is boolean -strict $x]} return
    return -code error \
	    -errorcode {M EXEC CAPTURE BAD BOOL} \
	    "Expected boolean, got \"$x\""
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
    variable capture::active

    # V C |
    # ----+-
    # 0 0 | (a) null
    # 0 1 | (b) capture
    # 1 0 | (c) pass to inherited out/err
    # 1 1 | (d) capture, pass to inherited

    if {$verbose} {
	# c, d
	m msg "> $args"
    }
    if {$active} {
	# b, d
	CAP $args $verbose $verbose
	# d - verbose ^----^
    } elseif {$verbose} {
	# c
	exec 2>@ stderr >@ stdout {*}$args
    } else {
	# a
	exec 2> [NULL] > [NULL] {*}$args
    }
    return
}

proc ::m::exec::get {args} {
    debug.m/exec {}
    variable verbose
    variable capture::active

    # V C |
    # ----+-
    # 0 0 | (a) null to stderr, return stdout
    # 0 1 | (b) capture, return stdout
    # 1 0 | (c) pass to stderr, return stdout
    # 1 1 | (d) capture, return stdout, pass stderr
    
    if {$verbose} {
	# (c)
	m msg "> $args"
    }

    if {$active} {
	# b, d
	lassign [CAP $args 0 $verbose] oc ec
	# d - verbose -------^
	return $oc
    } elseif {$verbose} {
	# c
	return [exec 2>@ stderr {*}$args]
    } else {
	# a
	return [exec 2>  [NULL] {*}$args]
    }
}

proc ::m::exec::silent {args} {
    debug.m/exec {}
    variable verbose
    variable capture::active

    # V C |
    # ----+-
    # 0 0 | (a) null
    # 0 1 | (b) capture
    # 1 0 | (c) null
    # 1 1 | (d) capture
    # ----> a == c
    # ----> b == d
    
    if {$verbose} {
	# c, d
	m msg "> $args"
    }
    if {$active} {
	# b, d
	set o [capture path out]
	set e [capture path err]
	exec 2> $o > $e {*}$args
    } else {
	# a, c
	exec 2> [NULL] > [NULL] {*}$args
    }
    return
}

proc ::m::exec::CAP {cmd vo ve} {
    # Note: Temp files capture just current execution,
    #       Main capture then extended from these.

    set o [capture path out]
    set e [capture path err]
    try {
	exec 2> $o.now > $e.now {*}$cmd
    } finally {
	set oc [POST $o.now $o $vo stdout]
	set ec [POST $e.now $e $ve stderr]
    }

    list $oc $ec
}

proc ::m::exec::POST {p pe v std} {
    set d [CAT $p]
    APPEND $pe $d
    file delete $p
    if {$v} { PASS $std $d }
    return $d
}

proc ::m::exec::APPEND {path data} {
    set c [open $path a]
    puts -nonewline $c $data
    close $c
    return
}

proc ::m::exec::CAT {path} {
    set c [open $path r]
    set d [read $c]
    close $c
    return $d
}

proc ::m::exec::PASS {c d} {
    puts -nonewline $c $d
    flush $c
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
