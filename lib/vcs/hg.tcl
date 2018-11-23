## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## Version Control Systems - Hg (mercurial) implementation

# @@ Meta Begin
# Package m::vcs::hg 0
# Meta author   {Andreas Kupries}
# Meta location https://core.tcl.tk/akupries/????
# Meta platform tcl
# Meta summary     Version control Hg
# Meta description Version control Hg
# Meta subject    {version control - hg}
# Meta require {Tcl 8.5-}
# @@ Meta End

package provide m::vcs::hg 0

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require m::futil
package require m::exec
package require debug
package require debug::caller

# # ## ### ##### ######## ############# ######################

debug level  m/vcs/hg
debug prefix m/vcs/hg {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval m::vcs {
    namespace export hg
    namespace ensemble create
}
namespace eval m::vcs::hg {
    namespace export setup cleanup update check split merge \
	version detect remotes export
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################

proc ::m::vcs::hg::LogNormalize {o e} {
    debug.m/vcs/hg {}
    # Nothing, for now
    return [list $o $e]
}

proc ::m::vcs::hg::detect {url} {
    debug.m/vcs/hg {}
    if {
	![string match *hg.code.sf.net/*          $url] &&
	![string match *hg.code.sourceforge.net/* $url]
    } return
    if {[catch {
	m exec silent hg help
    }]} {
	m msg "[color note "hg"] [color warning "not available"]"
	# Fall through
	return
    }
    return -code return hg
}

proc ::m::vcs::hg::version {iv} {
    debug.m/vcs/hg {}
    if {[llength [auto_execok hg]]} {
	m exec post-hook ;# clear

	set v [m exec get hg version]   ; debug.m/vcs/hg {raw = (($v))}
	set v [::split $v \n]           ; debug.m/vcs/hg {split    = '$v'}
	set v [lindex $v 0]             ; debug.m/vcs/hg {sel line = '$v'}
	set v [lindex $v end]           ; debug.m/vcs/hg {sel col  = '$v'}
	set v [string trimright $v ")"] ; debug.m/vcs/hg {trim     = '$v'}

	return $v
    }
    upvar 1 $iv issues
    lappend issues "`hg` not found in PATH"
    return
}

proc ::m::vcs::hg::setup {path url} {
    debug.m/vcs/hg {}

    set repo [HgOf $path]
    Hg clone --noupdate $url $repo
    return
}

proc ::m::vcs::hg::cleanup {path} {
    debug.m/vcs/hg {}
    return
}

proc ::m::vcs::hg::update {path urls first} {
    debug.m/vcs/hg {}
    set repo   [HgOf $path]
    set before [Count $path]

    foreach url $urls {
	Hg pull $url -R $repo
    }

    return [list $before [Count $path]]
}

proc ::m::vcs::hg::check {primary other} {
    debug.m/vcs/hg {}
    return 1 ;#[string equal [ProjectCode $primary] [ProjectCode $other]]
}

proc ::m::vcs::hg::split {origin dst} {
    debug.m/vcs/hg {}
    return
}

proc ::m::vcs::hg::merge {primary secondary} {
    debug.m/vcs/hg {}
    return
}

proc ::m::vcs::hg::remotes {path} {
    debug.m/vcs/hg {}
    # No automatic forks to track
    return
}

proc ::m::vcs::hg::export {path} {
    debug.m/vcs/hg {}
    # no publication of the local repo
    return ""
}

# # ## ### ##### ######## ############# #####################
## Helpers

proc ::m::vcs::hg::Hg {args} {
    debug.m/vcs/hg {}
    m exec post-hook ::m::vcs::hg::LogNormalize
    m exec go hg {*}$args
    return
}

proc ::m::vcs::hg::HgGet {args} {
    debug.m/vcs/hg {}
    m exec post-hook ::m::vcs::hg::LogNormalize
    return [m exec get hg {*}$args]
}

proc ::m::vcs::hg::HgOf {path} {
    debug.m/vcs/hg {}
    return [file join $path source.hg]
}

proc ::m::vcs::hg::Count {path} {
    debug.m/vcs/hg {}
    set tip [HgGet identify --num --rev tip -R [HgOf $path]]
    incr tip
    debug.m/vcs/hg { --> $tip }
    return $tip
}

# # ## ### ##### ######## ############# #####################
return
