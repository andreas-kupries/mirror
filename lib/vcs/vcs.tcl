## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## Version Control Systems - Core

# @@ Meta Begin
# Package m::vcs 0 
# Meta author   {Andreas Kupries}
# Meta location https://core.tcl.tk/akupries/????
# Meta platform tcl
# Meta summary     Version control core
# Meta description Version control core
# Meta subject    {version control - core}
# Meta require {Tcl 8.5-}
# @@ Meta End

package provide m::vcs 0

# TODO: vcs/plugin extension - extract size
# TODO: vcs/plugin extension - extract description

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require fileutil
package require cmdr::color
package require m::db
package require m::state
package require m::exec
package require m::msg
package require m::futil
package require m::url
package require m::vcs::fossil
package require m::vcs::git
package require m::vcs::github
package require m::vcs::hg
package require m::vcs::svn
package require debug
package require debug::caller

# # ## ### ##### ######## ############# ######################

debug level  m/vcs
debug prefix m/vcs {[pid] [debug caller] | }

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval ::m {
    namespace export vcs
    namespace ensemble create
}

namespace eval ::m::vcs {
    namespace export \
	setup cleanup update check cleave merge \
	rename id supported all code name \
	detect url-norm name-from-url version \
	move size caps remotes export path revs
    namespace ensemble create

    namespace import ::cmdr::color

    # Operation state: Id counter, and state per operation.
    variable opsid 0
    variable ops   {}
}

# # ## ### ##### ######## ############# #####################

proc ::m::vcs::caps {store} {
    debug.m/vcs {}
    set path [Path $store]

    # Handle missing files ... TODO: future - stricter
    try { lappend r [m futil cat $path/%stdout] } on error {} { lappend r {} }
    try { lappend r [m futil cat $path/%stderr] } on error {} { lappend r {} }
    return $r
}

# proc ::m::vcs::size {store} {
#     debug.m/vcs {}
#     # store id -> Using for path.
#     # vcs   id -> Decode to plugin name
#
#     set path [Path $store]
#     set kb   [lindex [m exec get du -sk $path] 0]
#
#     debug.m/vcs {=> $kb}
#     return $kb
# }
#
# proc ::m::vcs::revs {store vcs} {
#     debug.m/vcs {}
#     # store id -> Using for path.
#     # vcs   id -> Decode to plugin name
#
#     set path  [Path $store]
#     set vcode [code $vcs]
#     return [$vcode revs $path]
# }

proc ::m::vcs::setup {store vcs name url} {
    debug.m/vcs {}
    # store id -> Using for path.
    # vcs   id -> Decode to plugin name
    # name     -  mset name
    # url      -  repo url
    set path  [Path $store]
    set vcode [code $vcs]

    # Ensure clean new environment
    file delete -force -- $path
    file mkdir            $path

    m futil write $path/%name $name  ;# Mirror set
    m futil write $path/%vcs  $vcode ;# Manager

    # Redirect through an external command. This command is currently
    # always `mirror-vcs VCS LOG setup STORE URL`.

    # Ask plugin to fill the store.
    
    Operation ::m::vcs::OpComplete $vcode setup {*}[OpCmd $vcode $path $url]
    set state [OpWait]

    dict with state {}
    # [x] ok
    # [x] commits
    # [x] size
    # [x] forks
    # [ ] results
    # [x] msg
    # [x] duration

    if {!$ok} {
	# Roll back filesystem changes
	file delete -force -- $path

	# Rethrow as something more distinguished for trapping
	return -code error -errorcode {M VCS CHILD} $msg
    }

    dict unset state results
    dict unset state msg
    return $state
}

proc ::m::vcs::update {store vcs urls} {
    debug.m/vcs {}
    # store id -> Using for path.
    # vcs   id -> Decode to plugin name
    # urls     -  repo urls to use as sources

    set path  [Path $store]
    set vcode [code $vcs]

    # Validate incoming urls to ensure that they are still present. No
    # need to go for the vcs client when we know that it must
    # fail. That said, we store our failure as a pseudo error log for
    # other parts to pick up on.

    m futil write $path/%stderr ""
    m futil write $path/%stdout "Verifying urls ...\n"
    set failed 0
    foreach u $urls {
	debug.m/vcs {Verifying $u ...}
	if {[m url ok $u xr]} continue
	m futil append $path/%stderr "  Bad url: $u\n"
	set failed 1
    }
    if {$failed} {
	m futil append $path/%stderr "Unable to reach remotes\n"
	# Fake 'no changes', and error
	return {-1 -1 {}}
    }

    try {
	CAP $path {
	    set counts [$vcode update $path $urls 0]
	}
    } on error {e o} {
	# Fake 'no changes', and error.
	# Note, CAP already saved the errorInfo into %stderr
	return {-1 -1 {}}
    }
    if {[llength $counts] < 3} { lappend counts {} }
    debug.m/vcs {==> ($counts)}
    return $counts
}

proc ::m::vcs::rename {store name} {
    debug.m/vcs {}
    # store id -> Using for path.
    # name     -  new mset name
    set path [Path $store]
    m futil write $path/%name $name
    return
}

proc ::m::vcs::cleanup {store vcs} {
    debug.m/vcs {}
    # store id -> Using for path.
    # vcs   id -> Decode to plugin name
    set path [Path $store]
    set vcode [code $vcs]

    # TODO MAYBE: check vcode against contents of $path/%vcs.
    
    # Release vcs-specific special resources, if any
    $vcode cleanup $path

    # ... and the store directory
    file delete -force -- $path
    return 
}

proc ::m::vcs::move {newpath} {
    debug.m/vcs {}

    set oldpath [m state store]
    
    m state store $newpath
    file mkdir $newpath
    
    foreach store [glob -directory $oldpath -nocomplain *] {
	set newstore [file join $newpath [file tail $store]]
	m msg "Moving [color note $store]"
	m msg "    To [color note $newstore]"
	try {
	    file rename $store $newstore
	    lappend moved $store $newstore
	} on error {e o} {
	    m msg "Move failure: [color bad $e]"
	    m msg "Shifting transfered stores back"

	    foreach {oldstore newstore} $moved {
		m msg "- Restoring [color note $oldstore] ..."
		file rename $newstore $oldstore
	    }

	    # Rethrow
	    return {*}$o $e
	}
    }
    return
}

proc ::m::vcs::check {vcs storea storeb} {
    debug.m/vcs {}
    set patha [Path $storea]
    set pathb [Path $storeb]
    set vcode [code $vcs]

    # Check if the two stores are mergable
    return [$vcode check $patha $pathb]
}

proc ::m::vcs::merge {vcs target origin} {
    debug.m/vcs {}
    set ptarget [Path $target]
    set porigin [Path $origin]
    set vcode   [code $vcs]

    # Merge vcs specific special resources, if any ...
    $vcode merge $ptarget $porigin

    # Destroy the merged store
    cleanup $origin $vcs
    return
}

proc ::m::vcs::cleave {vcs origin dst dstname} {
    debug.m/vcs {}
    set pdst    [Path $dst]
    set porigin [Path $origin]
    set vcode   [code $vcs]
    
    # Ensure clean copy
    file delete -force -- $pdst
    file copy   -force -- $porigin $pdst

    # Inlined rename of origin's new copy
    m futil write $pdst/%name $dstname
    
    # Split/create vcs specific special resources, if any ...
    $vcode cleave $porigin $pdst
    return
}

proc ::m::vcs::path {store} {
    debug.m/vcs {}
    return [Path $store]
}

proc ::m::vcs::remotes {vcs store} {
    debug.m/vcs {}
    set path  [Path $store]
    set vcode [code $vcs]

    # Ask plugin for remotes it may have.
    return [$vcode remotes $path]
}

proc ::m::vcs::export {vcs store} {
    debug.m/vcs {}
    set path  [Path $store]
    set vcode [code $vcs]

    # Redirect through an external command. This command is currently
    # always `mirror-vcs VCS LOG export STORE`.

    # Ask plugin for CGI script to access the store.
    
    Operation ::m::vcs::OpComplete $vcode export {*}[OpCmd $vcode $path]
    set state [OpWait]

    dict with state {}
    # [x] ok
    # [ ] commits
    # [ ] size
    # [ ] forks
    # [x] results
    # [ ] msg
    # [ ] duration

    if {!$ok} {
	if {![llength $results]} {
	    lappend results "Failed to retrieve export script for $vcs on $path"
	}
	return -errorcode {MIRROR VCS EXPORT} -code error [join $results \n]
    } else {
	set script [join $results \n]
	debug.m/vcs {--> $script}
	return $script
    }
}

# # ## ### ##### ######## ############# #####################

proc ::m::vcs::version {vcode iv} {
    debug.m/vcs {}
    upvar 1 $iv issues
    set issues {}

    # Redirect through an external command. This command is currently
    # always `mirror-vcs VCS LOG version`.
    
    Operation ::m::vcs::OpComplete $vcode version {*}[OpCmd $vcode]
    set state [OpWait]

    dict with state {}
    # [x] ok
    # [ ] commits
    # [ ] size
    # [ ] forks
    # [x] results
    # [x] msg
    # [ ] duration

    if {!$ok} {
	if {[llength $msg]}     { lappend issues {*}$msg     }
	if {[llength $results]} { lappend issues {*}$results }
	return
    } else {
	set version [lindex $results 0]
	debug.m/vcs {--> $version}
	return $version
    }
}

proc ::m::vcs::detect {url} {
    debug.m/vcs {}

    # Note: Ordering is important.
    # Capture specific things first (github)
    # Least specific (fossil) is last.

    github detect $url
    git    detect $url
    hg     detect $url
    svn    detect $url
    fossil detect $url

    return -code error "Unable to determine vcs for $url"
}

proc ::m::vcs::url-norm {vcode url} {
    debug.m/vcs {}
    # Normalize the incoming url
    # I.e. for a number of known sites, force the use of the https
    # they support. Further strip known irrelevant trailers.
    # Resolve short host names to the proper full name

    lappend map sf.net               sourceforge.net
    lappend map git@github.com:      https://github.com/
    lappend map http://github.com    https://github.com
    lappend map http://chiselapp.com https://chiselapp.com
    lappend map http://core.tcl.tk   https://core.tcl.tk

    if {$vcode eq "fossil"} {
	# Strip query fragment
	regsub -- {\?[^?]*$}   $url {} url
	# Strip page fragment
	regsub -- "#.*\$"      $url {} url
	# Strip various toplevel pages
	regsub -- {/index$}    $url {} url
	regsub -- {/timeline$} $url {} url
	regsub -- {/login$}    $url {} url
    }
    
    return [string map $map $url]
}

proc ::m::vcs::name-from-url {vcode url} {
    debug.m/vcs {}
    return [$vcode name-from-url $url]
}

# # ## ### ##### ######## ############# #####################

proc ::m::vcs::code {id} {
    debug.m/vcs {}
    return [m db onecolumn {
	SELECT code
	FROM   version_control_system
	WHERE  id = :id
    }]
}

proc ::m::vcs::name {id} {
    debug.m/vcs {}
    return [m db onecolumn {
	SELECT name
	FROM   version_control_system
	WHERE  id = :id
    }]
}

proc ::m::vcs::all {} {
    debug.m/vcs {}
    return [m db eval {
	SELECT code
	,      name
	FROM   version_control_system
	ORDER BY name ASC
    }]
}

proc ::m::vcs::supported {} {
    debug.m/vcs {}
    lappend r [m db eval {
	SELECT code
	FROM   version_control_system
    }]
    lappend r [m db eval {
	SELECT name
	FROM   version_control_system
    }]
    return [lsort -dict $r]
}

proc ::m::vcs::id {x} {
    debug.m/vcs {}
    set id [m db onecolumn {
	SELECT id
	FROM   version_control_system
	WHERE  code = :x
    }]

    if {$id eq {}} {
	set id [m db onecolumn {
	    SELECT id
	    FROM   version_control_system
	    WHERE  name = :x
	}]
    }

    if {$id eq {}} {
	return -code error "Invalid vcs code or name"
    }

    return $id
}

# # ## ### ##### ######## ############# #####################

proc ::m::vcs::CAP {path script} {
    debug.m/vcs {}
    try {
	m exec capture to $path/%stdout $path/%stderr
	uplevel 1 $script
    } on error {e o} {
	debug.m/vcs {Caught}
	debug.m/vcs {-- $o}
	debug.m/vcs {M: $e}

	m exec capture off
	m futil append $path/%stderr \nCaught:\n\n$::errorInfo\n\n

	return {*}$o $e
    } finally {
	m exec capture off
    }
    debug.m/vcs {/done}
}

proc ::m::vcs::Path {dir} {
    debug.m/vcs {}
    set path [file normalize [file join [m state store] $dir]]
    debug.m/vcs {=> $path}
    return $path
}

# # ## ### ##### ######## ############# #####################
## Background operations. Based on jobs.
#
## Caller side
# - Operation DONE VCS OP ...
# - OpCmd VCS ...
#

proc ::m::vcs::OpComplete {state} {
    debug.m/vcs {}
    variable opsresult $state
    return
}

proc ::m::vcs::OpWait {} {
    debug.m/vcs {}
    vwait ::m::vcs::opsresult
    return $::m::vcs::opsresult
}

proc ::m::vcs::OpCmd {vcs args} {
    debug.m/vcs {}
    # Currently only fallback for builtin systems.
    # TODO: Query system configuration first.
    list mirror-vcs %vcs% %log% %operation% {*}$args
    #list %self% vcs-op %operation% %vcs% %log% {*}$args
}

proc ::m::vcs::Operation {done vcs op args} {
    debug.m/vcs {}
    variable opsid ; incr opsid
    variable ops

    set logfile [fileutil::tempfile mirror_vcs_]
    
    lappend map %self%      $::argv0
    lappend map %operation% $op
    lappend map %vcs%       $vcs
    lappend map %log%       $logfile
    lappend map %%          %
    
    set args  [lmap w $args { string map $map $w }]
    set jdone [list ::m::vcs::OpDone     $opsid]
    set jout  [list ::m::vcs::OpProgress $opsid]

    dict set ops $opsid ok       1
    dict set ops $opsid log      $logfile
    dict set ops $opsid commits  {}
    dict set ops $opsid size     {}
    dict set ops $opsid forks    {}
    dict set ops $opsid results  {}
    dict set ops $opsid start    [clock seconds]
    dict set ops $opsid done     $done
    #
    dict set ops $opsid pipe [m exec job $jdone $jout {*}$args]
    return $opsid
}

proc ::m::vcs::OpProgress {opsid line} {
    debug.m/vcs {}
    # Progress reporting from job stdout
    variable ops
    
    if {[catch {
	set words [lassign $line tag]
	set color [dict get {
	    info  black	   note  blue  warn  yellow
	    error magenta  fatal red
	} $tag]
    } msg]} {
	close [dict get $ops $opsid pipe]
	OpDone $opsid 0 $msg
	return
    }

    # When not verbose limit reporting to (potential) trouble,
    # i.e. warnings and higher.

    set level [dict get {
	info 0 note 1 warn 2 error 3 fatal 4
    } $tag]
    if {![m exec verbose] && ($level < 2)} return
    
    m msg [color $color [join $words]]
    return
}

proc ::m::vcs::OpDone {opsid ok msg} {
    debug.m/vcs {}
    # Process the operations log for information.
    variable ops
    set state [dict get $ops $opsid]
    dict unset ops $opsid

    dict unset state pipe
    set log      [dict get $state log]   ; dict unset state log
    set done     [dict get $state done]  ; dict unset state done
    set start    [dict get $state start] ; dict unset state start
    set duration [expr { [clock seconds] - $start }]
    
    dict set state ok       $ok
    dict set state msg      $msg
    dict set state duration $duration

    if {$ok} {
	# Process operations log.
	set chan [open $log r]
	while {[gets $chan line] >= 0} {
	    debug.m/vcs {-- $line}
	    if {[catch {
		set words [lassign $line tag]
	    } msg]} {
		dict set state ok  0
		dict set state msg $msg
		break
	    }
	    set val [lindex $words 0]
	    switch -exact -- $tag {
		info -
		note -
		warn {
		    # Ignore non-error progress reports in the
		    # operations log.
		}
		error -
		fatal {
		    dict set state ok  0
		    dict lappend state msg $val
		}
		commits { dict set     state commits $val }
		size    { dict set     state size    $val }
		fork    { dict lappend state forks   $val }
		ok      { dict set     state ok 1         }
		fail    { dict set     state ok 0         }
		result  { dict lappend state results $val }
		default {
		    # Fail on unknown tags
		    dict set state ok  0
		    dict set state msg "Unknown tag $tag"
		    break
		}
	    }
	}
	close $chan
    }

    # TODO: Save log into a blob...

    #puts $log
    file delete $log

    m::exec::Do $done $state
    return
}

# # ## ### ##### ######## ############# #####################
return
