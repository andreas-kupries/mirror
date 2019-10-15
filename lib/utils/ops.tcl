## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## General utilities - VCS plugin side common code.

# @@ Meta Begin
# Package m::ops::client 0
# Meta author   {Andreas Kupries}
# Meta location https://core.tcl.tk/akupries/????
# Meta platform tcl
# Meta summary     Operation backends, common code
# Meta description Operation backends, common code
# Meta subject {operation backends}
# Meta require {Tcl 8.5-}
# @@ Meta End

package provide m::ops::client 0
package require cmdr::color
package require debug
package require debug::caller
package require m::app

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5

# # ## ### ##### ######## ############# ######################

debug level  m/ops/client
debug prefix m/ops/client {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval m {
    namespace export ops
    namespace ensemble create
}
namespace eval m::ops {
    namespace export set client
    namespace ensemble create
}
namespace eval m::ops::client {
    namespace export set main \
	info note warn err fatal \
	result ok fail commits forks size
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################
## API

proc ::m::ops::client::info  {args} { R info  [join $args] }
proc ::m::ops::client::note  {args} { R note  [join $args] }
proc ::m::ops::client::warn  {args} { R warn  [join $args] }
proc ::m::ops::client::err   {args} { R error [join $args] }
proc ::m::ops::client::fatal {args} { R fatal [join $args] }

proc ::m::ops::client::commits {v} { R commits $v }
proc ::m::ops::client::forks   {v} { R forks $v }
proc ::m::ops::client::size    {v} { R size $v }
proc ::m::ops::client::ok      {}  { R ok }
proc ::m::ops::client::fail    {}  { R fail }
proc ::m::ops::client::result  {v} { R result $v }

proc ::m::ops::client::main {} {
    m app debugflags
    debug.m/ops/client {}
    if {[catch {
	set op [Cmdline]
	package require m::vcs::[lindex $op 0]
	m vcs {*}$op
    }]} {
	foreach line [split $::errorInfo \n] { err $line }
	fail
    }
    Done
    return
}

# # ## ### ##### ######## ############# #####################

proc ::m::ops::client::Cmdline {} {
    debug.m/ops/client {}
    global argv
    if {[llength $argv] < 3} {
	Usage "Not enough arguments"
    }
    set argv [lassign $argv vcs logfile operation]
    set ops {
	setup       {Store Url}
	cleanup     {Store}
	update      {Store Url Bool}
	mergable?   {Store Store}
	merge       {Store Store}
	split       {Store Store}
	export      {Store}
	version     {}
	url-to-name {Url}
    }
    if {![dict exists $ops $operation]} {
	Usage "Unknown operation `$operation`"
    }
    set types [dict get $ops $operation]
    if {[llength $argv] != [llength $types]} {
	Usage "Wrong # Args for $operation"
    }
    foreach a $argv t $types {
	if {![$t $a]} { Usage "Expected $t, got '$a'" }
    }
    if {[catch {
	LogTo $logfile
    } msg]} {
	err $msg
	fail
	Done
    }    
    return [linsert $argv 0 $vcs $operation]
}

proc ::m::ops::client::Usage {{note {}}} {
    debug.m/ops/client {}
    global argv0
    if {$note ne {}} {
	fatal $note
	fatal ""
    }
    regsub -all . $argv0 { } blank
    fatal "Usage: $argv0 LOG setup       STORE URL"
    fatal "       $blank     cleanup     STORE"
    fatal "       $blank     update      STORE URL PRIMARY"
    fatal "       $blank     mergable?   STORE STORE"
    fatal "       $blank     merge       STORE STORE"
    fatal "       $blank     split       STORE STORE"
    fatal "       $blank     export      STORE"
    fatal "       $blank     version"
    fatal "       $blank     url-to-name URL"
    fail
    Done
}

proc ::m::ops::client::Store {v} {
    debug.m/ops/client {}
    file isdirectory $v
}

proc ::m::ops::client::Url {v} {
    debug.m/ops/client {}
    return 1
}

proc ::m::ops::client::Bool {v} {
    debug.m/ops/client {}
    string is bool -strict $v
}

proc ::m::ops::client::LogTo {path} {
    debug.m/ops/client {}
    file mkdir [file dirname $path]
    variable logchan [open $path w]
    return
}

proc ::m::ops::client::R {tag args} {
    debug.m/ops/client {}
    variable logchan
    if {$logchan ne {}} {
	# Record everything in the operations log, if present.
	puts  $logchan [linsert $args 0 $tag]
	flush $logchan
    }

    # Report progress to the invoker/caller as well, via stdout.
    if {$tag ni {info note warn error fatal}} return

    # Colorize if called from a terminal, and suppress the tag.
    if {[cmdr color active]} {
	puts [cmdr color [dict get {
	    info  black
	    note  blue
	    warn  yellow
	    error magenta
	    fatal red
	} $tag] [join $args]]
	return
    }

    # No colorization nor tag supression when in a pipe.
    puts  stdout [linsert $args 0 $tag]
    flush stdout
    return
}

proc ::m::ops::client::Done {} {
    debug.m/ops/client {}
    variable logchan
    catch { close $logchan }
    exit
    return
}

# # ## ### ##### ######## ############# #####################
## State

namespace eval ::m::ops::client {
    variable logchan {}    
}

# # ## ### ##### ######## ############# #####################
return
