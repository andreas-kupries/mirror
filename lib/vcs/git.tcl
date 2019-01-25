## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## Version Control Systems - Git implementation

# @@ Meta Begin
# Package m::vcs::git 0
# Meta author   {Andreas Kupries}
# Meta location https://core.tcl.tk/akupries/????
# Meta platform tcl
# Meta summary     Version control Git
# Meta description Version control Git
# Meta subject    {version control - git}
# Meta require {Tcl 8.5-}
# @@ Meta End

package provide m::vcs::git 0

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require struct::set
package require cmdr::color
package require m::futil
package require m::exec
package require debug
package require debug::caller

# # ## ### ##### ######## ############# ######################

debug level  m/vcs/git
debug prefix m/vcs/git {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval m::vcs {
    namespace export git
    namespace ensemble create
}
namespace eval m::vcs::git {
    namespace export setup cleanup update check cleave merge \
	version detect remotes export name-from-url revs
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################

proc ::m::vcs::git::LogNormalize {o e} {
    debug.m/vcs/git {}

    # Move all non-errors written to stderr over into stdout.
    lassign [m futil m-grep {
	{^[[:space:]]*$}
	{^From }
	{tag update}
	{ -> }
	{^origin }
	{^m-vcs-}
	{warning: redirecting to}
	{Auto packing}
	{manual housekeeping}
    } $e] out err

    if {[llength $out]} { lappend o {*}$out }
    set e $err

    return [list $o $e]
}

proc ::m::vcs::git::name-from-url {url} {
    debug.m/vcs/git {}

    set gl [string match *gitlab* $url]

    lappend map "https://"        {}
    lappend map "http://"         {}
    lappend map "git@github.com:" {}

    set url [string map $map $url]

    if {$gl} {
	return [join [lrange [file split $url] end-1 end] /]@gl
    } else {
	return [lindex [file split $url] end]
    }
}

proc ::m::vcs::git::detect {url} {
    debug.m/vcs/git {}
    if {![string match *git* $url]} return
    if {![llength [auto_execok git]]} {
	m msg "[cmdr color note "git"] [cmdr color warning "not available"]"
	# Fall through
	return
    }
    return -code return git
}

proc ::m::vcs::git::version {iv} {
    debug.m/vcs/git {}
    upvar 1 $iv issues
    if {[llength [auto_execok git]]} {
	m exec post-hook ;# clear
	set v [lindex [m exec get git version] end]
	if {[package vcompare $v 2.6.1] <= 0} {
	    lappend issues "$v <= 2.6.1 not sufficient"
	    return
	}
	return $v
    }
    lappend issues "`git` not found in PATH"
    return
}

proc ::m::vcs::git::setup {path url} {
    debug.m/vcs/git {}
    m exec post-hook ::m::vcs::git::LogNormalize
    m exec go git --bare --git-dir [GitOf $path] init
    return
}

proc ::m::vcs::git::cleanup {path} {
    debug.m/vcs/git {}
    # Nothing special. No op.
    return
}

proc ::m::vcs::git::revs {path} {
    debug.m/vcs/git {}
    if {[catch {
	return [Count $path]
    }]} {
	return 0
    }
}

proc ::m::vcs::git::update {path urls first} {
    debug.m/vcs/git {}
    set remotes [Remotes $path]
    # remotes = (remote-url ...)

    lassign [struct::set intersect3 $remotes $urls] _ gone new

    # Steps
    # - Remove remotes for urls not managed anymore
    # - Add    remotes for urls newly managed
    # - Fetch from all remotes.
    #
    # __Attention__: Using `--prune` would kill all the branches from
    # the non-origin remotes, followed by a full refetch :( Thus, no
    # pruning.

    foreach url $gone { RemoteRemove $url }
    foreach url $new  { RemoteAdd    $url }

    if {$first} {
	# Cannot count git revs before the initial fetch.
	set before 0
    } else {
	set before [Count $path]
    }

    Git fetch --all --tags

    return [list $before [Count $path]]
}

proc ::m::vcs::git::check {primary other} {
    debug.m/vcs/git {}
    # No true check. Any repository can fit with any other.
    # The user is (unfortunately) responsible for keeping
    # non-matching repositories apart.
    return true
}

proc ::m::vcs::git::cleave {origin dst} {
    debug.m/vcs/git {}
    return
}

proc ::m::vcs::git::merge {primary secondary} {
    debug.m/vcs/git {}
    # Note: The remotes missing in primary are fixed by the next call
    # to `update`.
    return
}

proc ::m::vcs::git::remotes {path} {
    debug.m/vcs/git {}
    return
}

proc ::m::vcs::git::export {path} {
    debug.m/vcs/git {}
    return
}

# # ## ### ##### ######## ############# #####################
## Helpers

proc ::m::vcs::git::RemoteAdd {url} {
    debug.m/vcs/git {}
    upvar 1 path path
    Git remote add [RemoteOf $url] $url
    return
}

proc ::m::vcs::git::RemoteRemove {url} {
    debug.m/vcs/git {}
    upvar 1 path path
    Git remote remove [RemoteOf $url]
    return
}

proc ::m::vcs::git::Remotes {path} {
    debug.m/vcs/git {}
    set result {}
    foreach r [Get remote] {
	if {![Owned $r]} continue
	lappend result [UrlOf $r]
    }
    return $result
}

proc ::m::vcs::git::Count {path} {
    debug.m/vcs/git {}
    m exec post-hook ::m::vcs::git::LogNormalize
    set count [string trim [m exec get git --git-dir [GitOf $path] rev-list --all --count]]
    debug.m/vcs/git {==> $count}
    return $count
}

proc ::m::vcs::git::Owned {remote} {
    debug.m/vcs/git {}
    return [string match m-vcs-git-* $remote]
}

proc ::m::vcs::git::UrlOf {remote} {
    debug.m/vcs/git {}
    return [string map \
		{%3a : %2f / %3A : %2F /} \
		[string range $remote [string length m-vcs-git-] end]]
}

proc ::m::vcs::git::RemoteOf {url} {
    debug.m/vcs/git {}
    return "m-vcs-git-[string map {: %3a / %2f} $url]"
}

proc ::m::vcs::git::GitOf {path} {
    debug.m/vcs/git {}
    return [file join $path source.git]
}

proc ::m::vcs::git::Git {args} {
    debug.m/vcs/git {}
    upvar 1 path path
    m exec post-hook ::m::vcs::git::LogNormalize
    m exec go git --git-dir [GitOf $path] {*}$args
    return
}

proc ::m::vcs::git::Get {args} {
    debug.m/vcs/git {}
    upvar 1 path path
    m exec post-hook ::m::vcs::git::LogNormalize
    return [m exec get git --git-dir [GitOf $path] {*}$args]
}

# # ## ### ##### ######## ############# #####################
return
