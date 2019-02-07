## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## Version Control Systems - Svn (mercurial) implementation

# @@ Meta Begin
# Package m::vcs::svn 0
# Meta author   {Andreas Kupries}
# Meta location https://core.tcl.tk/akupries/????
# Meta platform tcl
# Meta summary     Version control Svn
# Meta description Version control Svn
# Meta subject    {version control - svn}
# Meta require {Tcl 8.5-}
# @@ Meta End

package provide m::vcs::svn 0

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require cmdr::color
package require m::futil
package require m::exec
package require debug
package require debug::caller

# # ## ### ##### ######## ############# ######################

debug level  m/vcs/svn
debug prefix m/vcs/svn {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval m::vcs {
    namespace export svn
    namespace ensemble create
}
namespace eval m::vcs::svn {
    namespace export setup cleanup update check cleave merge \
	version detect remotes export name-from-url revs
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################

proc ::m::vcs::svn::LogNormalize {o e} {
    debug.m/vcs/svn {}
    # Nothing, for now
    return [list $o $e]
}

proc ::m::vcs::svn::name-from-url {url} {
    debug.m/vcs/svn {}
    return
}
    
proc ::m::vcs::svn::detect {url} {
    debug.m/vcs/svn {}
    if {
	![string match svn://*                     $url] &&
	![string match *svn.code.sf.net/*          $url] &&
	![string match *svn.code.sourceforge.net/* $url]
    } return
    if {![llength [auto_execok svn]]} {
	m msg "[cmdr color note "svn"] [cmdr color warning "not available"]"
	# Fall through
	return
    }
    return -code return svn
}

proc ::m::vcs::svn::version {iv} {
    debug.m/vcs/svn {}
    if {[llength [auto_execok svn]]} {
	m exec post-hook ;# clear

	set v [m exec get svn --version]; debug.m/vcs/svn {raw = (($v))}
	set v [split  $v \n]            ; debug.m/vcs/svn {split    = '$v'}
	set v [lindex $v 0]             ; debug.m/vcs/svn {sel line = '$v'}
	set v [lindex $v 2]             ; debug.m/vcs/svn {sel col  = '$v'}

	return $v
    }
    upvar 1 $iv issues
    lappend issues "`svn` not found in PATH"
    return
}

proc ::m::vcs::svn::setup {path url} {
    debug.m/vcs/svn {}

    set repo [SvnOf $path]
    Svn checkout $url $repo
    return
}

proc ::m::vcs::svn::cleanup {path} {
    debug.m/vcs/svn {}
    return
}

proc ::m::vcs::svn::revs {path} {
    debug.m/vcs/svn {}
    return [Count $path]
}

proc ::m::vcs::svn::update {path urls first} {
    debug.m/vcs/svn {}
    set repo   [SvnOf $path]
    set before [Count $path]

    Svn update $repo

    return [list $before [Count $path]]
}

proc ::m::vcs::svn::check {primary other} {
    debug.m/vcs/svn {}
    return 0 ;# Cannot merge SVN checkouts. Each has a single origin url
}

proc ::m::vcs::svn::cleave {origin dst} {
    debug.m/vcs/svn {}
    return
}

proc ::m::vcs::svn::merge {primary secondary} {
    debug.m/vcs/svn {}
    return
}

proc ::m::vcs::svn::remotes {path} {
    debug.m/vcs/svn {}
    # No automatic forks to track
    return
}

proc ::m::vcs::svn::export {path} {
    debug.m/vcs/svn {}
    # no publication of the local repo
    return ""
}

# # ## ### ##### ######## ############# #####################
## Helpers

proc ::m::vcs::svn::Svn {args} {
    debug.m/vcs/svn {}
    m exec post-hook ::m::vcs::svn::LogNormalize
    m exec go svn {*}$args
    return
}

proc ::m::vcs::svn::SvnGet {args} {
    debug.m/vcs/svn {}
    m exec post-hook ::m::vcs::svn::LogNormalize
    return [m exec get svn {*}$args]
}

proc ::m::vcs::svn::SvnOf {path} {
    debug.m/vcs/svn {}
    return [file join $path source.svn]
}

proc ::m::vcs::svn::Count {path} {
    debug.m/vcs/svn {}
    set tip [string trim [SvnGet info -r HEAD --show-item revision [SvnOf $path]]]
    debug.m/vcs/svn { --> $tip }
    return $tip
}

# # ## ### ##### ######## ############# #####################
return
