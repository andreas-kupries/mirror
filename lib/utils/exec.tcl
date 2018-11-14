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
package require m::futil

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
    namespace export verbose cmdverbose go get silent capture
    namespace ensemble create
}

namespace eval ::m::exec::capture {
    namespace export to on off clear get path active append
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

proc ::m::exec::capture::append {key verbose content} {
    # Get captured content
    debug.m/exec {}
    V $key
    set path [P $key]
    if {$path ne {}} {
	m futil append $path $content
    }
    if {$verbose} {
	# pass to regular std channel
	puts -nonewline std$key $content
	flush std$key
    }
    return
}

proc ::m::exec::capture::get {key} {
    # Get captured content
    debug.m/exec {}
    V $key
    set path [P $key]
    if {$path eq {}} return
    return [m futil cat $path]
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
	capture::B $newvalue
	set verbose $newvalue
    }
    return $verbose
}

proc ::m::exec::cmdverbose {{newvalue {}}} {
    debug.m/exec {}
    variable cmdverb
    if {[llength [info level 0]] == 2} {
	capture::B $newvalue
	set cmdverb $newvalue
    }
    return $cmdverb
}

# # ## ### ##### ######## ############# #####################

proc ::m::exec::go {cmd args} {
    debug.m/exec {}
    variable verbose
    variable cmdverb
    set args [linsert $args 0 $cmd]

    # V C |
    # ----+-
    # 0 0 | (a) null
    # 0 1 | (b) capture
    # 1 0 | (c) pass to inherited out/err
    # 1 1 | (d) capture, pass to inherited

    if {$verbose || $cmdverb} {
	# c, d
	m msg "> $args"
    }
    if {[capture active]} {
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

proc ::m::exec::get {cmd args} {
    debug.m/exec {}
    variable verbose
    variable cmdverb
    set args [linsert $args 0 $cmd]

    # V C |
    # ----+-
    # 0 0 | (a) null to stderr, return stdout
    # 0 1 | (b) capture, return stdout
    # 1 0 | (c) pass to stderr, return stdout
    # 1 1 | (d) capture, return stdout, pass stderr
    
    if {$verbose || $cmdverb} {
	# (c)
	m msg "> $args"
    }

    if {[capture active]} {
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

proc ::m::exec::silent {cmd args} {
    debug.m/exec {}
    variable verbose
    variable cmdverb
    set args [linsert $args 0 $cmd]
    
    # V C |
    # ----+-
    # 0 0 | (a) null
    # 0 1 | (b) capture
    # 1 0 | (c) null
    # 1 1 | (d) capture
    # ----> a == c
    # ----> b == d
    
    if {$verbose || $cmdverb} {
	# c, d
	m msg "> $args"
    }
    if {[capture active]} {
	# b, d
	set o [capture path out]
	set e [capture path err]
	exec 2> $e > $o {*}$args
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
	exec 2> $e.now > $o.now {*}$cmd
    } finally {
	set oc [POST $o.now out $vo]
	set ec [POST $e.now err $ve]
    }

    list $oc $ec
}

proc ::m::exec::POST {p key v} {
    debug.m/exec {}
    set d [m futil cat $p]
    capture append $key $v $d
    file delete $p
    return $d
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
    variable verbose 0
    variable cmdverb 0
}
namespace eval ::m::exec::capture {
    variable active 0
    variable out    {}
    variable err    {}
}

# # ## ### ##### ######## ############# #####################
return
