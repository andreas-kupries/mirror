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
    namespace export verbose go get nc-get silent capture post-hook \
	job err-last-get get-- get+route diskuse notecmd
    namespace ensemble create

    variable notecmd {}
}

namespace eval ::m::exec::capture {
    namespace export to on off clear get path active
    namespace ensemble create
}

# # ## ### ##### ######## ############# #####################
## Highlevel shared exec: disk usage in kibibyte (du -sk).

proc ::m::exec::notecmd {args} {
    debug.m/exec {}
    variable notecmd $args
    return
}

# # ## ### ##### ######## ############# #####################
## Highlevel shared exec: disk usage in kibibyte (du -sk).

proc ::m::exec::diskuse {path} {
    debug.m/exec {}
    return [lindex [get-- du -sk $path] 0]
}

# # ## ### ##### ######## ############# #####################
## Background jobs.

proc ::m::exec::job {done out args} {
    debug.m/exec {}
    set pipe [open "|[linsert $args end 2>@1]"]
    fconfigure $pipe -blocking 0
    fileevent  $pipe readable [list ::m::exec::Job $done $out $pipe]
    return $pipe
}

proc ::m::exec::Job {done report pipe args} {
    debug.m/exec {}
    if {[eof $pipe]} {
	fconfigure $pipe -blocking 1
	set ok 1
	if {[catch {
	    close $pipe
	} msg]} {
	    set ok 0
	}
	Do $done $ok $msg
	return
    }
    if {[gets $pipe line] < 0} return
    Do $report $line
    return
}

proc ::m::exec::Do {cmd args} {
    debug.m/exec {}
    uplevel #0 [list {*}$cmd {*}$args]
}

# # ## ### ##### ######## ############# #####################
## Get for use in backends (report out/err, capture out)

proc ::m::exec::err-last-get {} {
    variable get ; return $get(err)
}

proc ::m::exec::get-- {args} {
    debug.m/exec {}
    get+route {} {*}$args
}

proc ::m::exec::get+route {router args} {
    debug.m/exec {}
    variable get
    variable getid

    NOTE note "> [join $args]"

    set id [incr getid]
    set get(o,$id) {}
    set get(e,$id) 0

    # Alternate exec get ...
    # - stdout/err are reported as info/error progress reports.
    # - stdout is further captured and returned.
    lassign [chan pipe] err w
    set out [open "|[linsert $args end 2>@ $w]"]

    fconfigure $out -blocking 0
    fileevent  $out readable [list ::m::exec::Get $router $out $id]

    fconfigure $err -blocking 0
    fileevent  $err readable [list ::m::exec::Err $router $err $id]

    vwait m::exec::get(r,$id)
    set res $get(r,$id)
    unset get(r,$id)
    return $res
}

proc ::m::exec::Get {router chan id} {
    debug.m/exec {}
    # Stderr transforms into progress reports, as info.
    # Also saved, i.e. captured for further processing.
    if {[eof $chan]} {
	close $chan
	variable get
	set get(r,$id) [join $get(o,$id) \n]
	set get(err)   $get(e,$id)
	unset get(o,$id) get(e,$id)
	return
    }
    if {[gets $chan line] < 0} return
    set route out
    if {[llength $router]} {
	{*}$router route $line
    }
    Process $route $id $line
    return
}

proc ::m::exec::Err {router chan id} {
    debug.m/exec {}
    # Stderr transforms into progress reports, as errors.
    if {[eof $chan]} { close $chan ; return }
    if {[gets $chan line] < 0} return
    set route err
    if {[llength $router]} {
	{*}$router route $line
    }
    Process $route $id $line
    return
}

proc ::m::exec::Process {dst id line} {
    debug.m/exec {}
    switch -exact -- $dst {
	ignore {}
	out {
	    NOTE info $line
	    variable get
	    lappend get(o,$id) $line
	}
	err {
	    NOTE err $line
	    variable get
	    incr get(e,$id)
	}
    }
    return
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
    if {!$reset} {
	debug.m/exec { /done}
	return
    }
    variable out {}
    variable err {}

    debug.m/exec {/done+reset}
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

proc ::m::exec::post-hook {args} {
    debug.m/exec {}
    variable posthook $args
    return $posthook
}

# # ## ### ##### ######## ############# #####################

proc ::m::exec::go {cmd args} {
    debug.m/exec {}
    variable verbose
    set args [linsert $args 0 $cmd]

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
    if {[capture active]} {
	# b, d
	CAP $args $verbose $verbose
	# d - verbose ^----^
    } elseif {$verbose} {
	# c
	debug.m/exec {2>@ stderr >@ stdout $args}
	exec          2>@ stderr >@ stdout {*}$args
    } else {
	# a
	debug.m/exec {2> [NULL] > [NULL] $args}
	exec          2> [NULL] > [NULL] {*}$args
    }
    return
}

proc ::m::exec::get {cmd args} {
    debug.m/exec {}
    variable verbose
    set args [linsert $args 0 $cmd]

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

    if {[capture active]} {
	# b, d
	lassign [CAP $args 0 $verbose] oc ec
	# d - verbose -------^
	debug.m/exec {==> ($oc)}
	return $oc
    } elseif {$verbose} {
	# c
	debug.m/exec {2>@ stderr $args}
	return [exec  2>@ stderr {*}$args]
    } else {
	# a
	debug.m/exec {2>  [NULL] $args}
	return [exec  2>  [NULL] {*}$args]
    }
}

proc ::m::exec::nc-get {cmd args} {
    debug.m/exec {}
    variable verbose
    set args [linsert $args 0 $cmd]

    if {$verbose} {
	# c
	m msg "> $args"
	debug.m/exec {2>@ stderr $args}
	return [::exec  2>@ stderr {*}$args]
    } else {
	# a
	debug.m/exec {2>  [NULL] $args}
	return [::exec  2>  [NULL] {*}$args]
    }
}

proc ::m::exec::silent {cmd args} {
    debug.m/exec {}
    variable verbose
    set args [linsert $args 0 $cmd]

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
    if {[capture active]} {
	# b, d
	set o [capture path out]
	set e [capture path err]
	debug.m/exec {2> $e > $o $args}
	exec          2> $e > $o {*}$args
    } else {
	# a, c
	debug.m/exec {2> [NULL] > [NULL] $args}
	exec          2> [NULL] > [NULL] {*}$args
    }
    return
}

proc ::m::exec::CAP {cmd vo ve} {
    debug.m/exec {}
    # Note: Temp files capture just current execution,
    #       Main capture then extended from these.

    variable posthook
    set o [capture path out]
    set e [capture path err]

    try {
	debug.m/exec {2> $e.now > $o.now $cmd}
	exec          2> $e.now > $o.now {*}$cmd
    } finally {
	set oc [m futil cat $o.now]
	set ec [m futil cat $e.now]

	# Run the post command hook, if present
	if {[llength $posthook]} {
	    set oc [split $oc \n]
	    set ec [split $ec \n]
	    lassign [uplevel #0 [list {*}$posthook $oc $ec]] oc ec
	    set oc [join $oc \n]
	    set ec [join $ec \n]
	}

	POST $oc $o $vo stdout
	POST $ec $e $ve stderr
    }

    list $oc $ec
}

proc ::m::exec::POST {content path verbose stdchan} {
    debug.m/exec {}
    # Extend capture
    m futil append $path $content
    if {$verbose} {
	# Pass to inherited std channel
	puts -nonewline $stdchan $content
	flush $stdchan
    }
    file delete ${path}.now
    return
}

proc ::m::exec::NOTE {args} {
    variable notecmd
    if {![llength $notecmd]} return
    uplevel #0 [list {*}$notecmd {*}$args]
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
    variable verbose 0
    variable posthook {}
}
namespace eval ::m::exec::capture {
    variable active 0
    variable out    {}
    variable err    {}
}

# # ## ### ##### ######## ############# #####################
return
