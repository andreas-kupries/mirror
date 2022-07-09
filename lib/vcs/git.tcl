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

namespace eval m {
    namespace export vcs
    namespace ensemble create
}
namespace eval m::vcs {
    namespace export git
    namespace ensemble create
}
namespace eval m::vcs::git {
    # Operation backend implementations
    namespace export version \
	setup cleanup update mergable? merge split \
	export url-to-name

    # Regular implementations not yet moved to operations.
    namespace export detect
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################
## Operations implemented for separate process/backend
#
# [/] version
# [/] setup       S U
# [/] cleanup     S
# [/] update      S U 1st
# [/] mergable?   SA SB
# [/] merge       S-DST S-SRC
# [/] split       S-SRC S-DST
# [/] export      S
# [/] url-to-name U
#

proc ::m::vcs::git::version {} {
    debug.m/vcs/git {}

    if {![llength [auto_execok git]]} {
	m ops client err {`git` not found in PATH}
	m ops client fail
	return
    }

    set v [lindex [m exec get-- git version] end]
    if {[package vcompare $v 2.6.1] <= 0} {
	m ops client err "$v <= 2.6.1 not sufficient"
	m ops client fail
	return
    }

    m ops client result $v
    m ops client ok
    return
}

proc ::m::vcs::git::setup {path url} {
    debug.m/vcs/git {}

    set repo   [GitOf $path]
    set remote [RemoteOf $url]

    m exec get+route \
	::m::vcs::git::Router \
	git --bare --git-dir $repo init
    # Cannot use `Git` ? --bare must be front ?!
    if {[m exec err-last-get]} {
	m ops client fail ; return
    }

    RemoteAdd $remote $url
    if {[m exec err-last-get]} {
	m ops client fail ; return
    }

    # Initial update
    Git fetch --tags $remote
    PostPull $path
    return
}

proc ::m::vcs::git::cleanup {path} {
    debug.m/vcs/git {}
    # Nothing special. No op.
    m ops client ok
    return
}

proc ::m::vcs::git::update {path url first} {
    debug.m/vcs/git {}

    set remote [RemoteOf $url]
    if {$remote ni [Get remote]} {
	RemoteAdd $remote $url
	if {[m exec err-last-get]} {
	    m ops client fail ; return
	}
    }

    Git fetch --tags $remote
    PostPull $path
    return
}

proc ::m::vcs::git::mergable? {primary other} {
    debug.m/vcs/git {}
    # Git repositories can be merged at will.  Disparate projects
    # simply cause storage of a forest of independent trees.  The user
    # is responsible for keeping disparate projects apart.
    m ops client result 1
    m ops client ok
    return
}

proc ::m::vcs::git::merge {primary secondary} {
    debug.m/vcs/git {}
    # Note: The remotes missing in primary are fixed by the next call
    # to `update`.
    m ops client ok
    return
}

proc ::m::vcs::git::split {origin dst} {
    debug.m/vcs/git {}
    m ops client ok
    return
}

proc ::m::vcs::git::export {path} {
    debug.m/vcs/git {}
    m ops client ok
    return
}

proc ::m::vcs::git::url-to-name {url} {
    debug.m/vcs/git {}

    set gl [string match *gitlab* $url]

    # Remove schema information first.
    lappend map "https://"        {}
    lappend map "http://"         {}
    lappend map "git@github.com:" {}

    set url [string map $map $url]

    # Extract a name from the end of the remainder, with special case
    # for gitlab projects.
    if {$gl} {
	set name [join [lrange [file split $url] end-1 end] /]@gl
    } else {
	set name [lindex [file split $url] end]
    }

    m ops client result $name
    m ops client ok
    return
}

# # ## ### ##### ######## ############# ######################

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

# # ## ### ##### ######## ############# #####################
## Helpers

proc ::m::vcs::git::PostPull {path} {
    debug.m/vcs/git {}

    if {[m exec err-last-get]} {
	m ops client fail ; return
    }

    set count [Count $path]
    if {[m exec err-last-get]} {
	m ops client fail ; return
    }

    set kb [m exec diskuse $path]
    if {[m exec err-last-get]} {
	m ops client fail ; return
    }

    # TODO :: Execute conversion of git repository to fossil
    # TODO :: Run in background

    m ops client commits $count
    m ops client size    $kb
    m ops client ok
    return
}

proc ::m::vcs::git::Router {rv line} {
    debug.m/vcs/git {}
    upvar 1 $rv route
    # Route all non-errors written from error log to standard log.
    foreach pattern {
	{^[[:space:]]*$}
	{^From }
	{tag update}
	{ -> }
	{^origin }
	{^m-vcs-}
	{warning: redirecting to}
	{Auto packing}
	{manual housekeeping}
    } {
	if {[regexp -- $pattern $line]} { R out }
    }
    return
}

proc ::m::vcs::git::R {to} {
    upvar 1 route route
    set route $to
    return -code return
}

proc ::m::vcs::git::RemoteAdd {name url} {
    debug.m/vcs/git {}
    upvar 1 path path
    Git remote add $name $url
    return
}

# proc ::m::vcs::git::RemoteRemove {url} {
#     debug.m/vcs/git {}
#     upvar 1 path path
#     Git remote remove [RemoteOf $url]
#     return
# }
#
# proc ::m::vcs::git::Remotes {path} {
#     debug.m/vcs/git {}
#     set result {}
#     foreach r [Get remote] {
# 	if {![Owned $r]} continue
# 	lappend result [UrlOf $r]
#     }
#     return $result
# }

proc ::m::vcs::git::Count {path} {
    debug.m/vcs/git {}
    set count [string trim [Get rev-list --all --count]]
    debug.m/vcs/git {==> $count}
    return $count
}

# proc ::m::vcs::git::Owned {remote} {
#     debug.m/vcs/git {}
#     return [string match m-vcs-git-* $remote]
# }
#
# proc ::m::vcs::git::UrlOf {remote} {
#     debug.m/vcs/git {}
#     return [string map \
# 		{%3a : %2f / %3A : %2F /} \
# 		[string range $remote [string length m-vcs-git-] end]]
# }

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
    m exec get+route \
	::m::vcs::git::Router \
	git --git-dir [GitOf $path] {*}$args
    return
}

proc ::m::vcs::git::Get {args} {
    debug.m/vcs/git {}
    upvar 1 path path
    return [m exec get+route \
		::m::vcs::git::Router \
		git --git-dir [GitOf $path] {*}$args]
}

# # ## ### ##### ######## ############# #####################
return
