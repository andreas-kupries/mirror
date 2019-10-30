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
package require cmdr::color
package require m::futil
package require m::exec
package require debug
package require debug::caller

# # ## ### ##### ######## ############# ######################

debug level  m/vcs/hg
debug prefix m/vcs/hg {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval m {
    namespace export vcs
    namespace ensemble create
}
namespace eval m::vcs {
    namespace export hg
    namespace ensemble create
}
namespace eval m::vcs::hg {
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

# Operations backend: version
proc ::m::vcs::hg::version {} {
    debug.m/vcs/hg {}

    if {![llength [auto_execok hg]]} {
	m ops client err {`hg` not found in PATH}
	m ops client fail
	return
    }

    set v [m exec get-- hg version]   ; debug.m/vcs/hg {raw = (($v))}
    set v [::split  $v \n]            ; debug.m/vcs/hg {split    = '$v'}
    set v [lindex $v 0]               ; debug.m/vcs/hg {sel line = '$v'}
    set v [lindex $v end]             ; debug.m/vcs/hg {sel col  = '$v'}
    set v [string trimright $v ")"]   ; debug.m/vcs/hg {trim     = '$v'}

    m ops client result $v
    m ops client ok
    return
}

proc ::m::vcs::hg::setup {path url} {
    debug.m/vcs/hg {}

    set repo [HgOf $path]
    Hg clone --noupdate $url $repo
    PostPull $path
    return
}

proc ::m::vcs::hg::cleanup {path} {
    debug.m/vcs/hg {}
    m ops client ok
    return
}

proc ::m::vcs::hg::update {path url first} {
    debug.m/vcs/hg {}

    set repo [HgOf $path]
    Hg pull $url -R $repo
    PostPull $path
    return
}

proc ::m::vcs::hg::mergable? {primary other} {
    debug.m/vcs/hg {}
    # Hg repositories can be merged at will.  Disparate projects
    # simply cause storage of a forest of independent trees.  The user
    # is responsible for keeping disparate projects apart.
    m ops client ok
    return    
}

proc ::m::vcs::hg::merge {primary secondary} {
    debug.m/vcs/hg {}
    # Nothing special. No op.
    m ops client ok
    return
}

proc ::m::vcs::hg::split {origin dst} {
    debug.m/vcs/hg {}
    # Nothing special. No op.
    m ops client ok
    return
}

proc ::m::vcs::hg::export {path} {
    debug.m/vcs/hg {}
    # no publication of the local repo
    m ops client ok
    return
}

proc ::m::vcs::hg::url-to-name {url} {
    debug.m/vcs/hg {}
    m ops client fail
    return
}

# # ## ### ##### ######## ############# ######################
    
proc ::m::vcs::hg::detect {url} {
    debug.m/vcs/hg {}
    if {
	![string match *hg.code.sf.net/*          $url] &&
	![string match *hg.code.sourceforge.net/* $url]
    } return
    if {![llength [auto_execok hg]]} {
	m msg "[cmdr color note "hg"] [cmdr color warning "not available"]"
	# Fall through
	return
    }
    return -code return hg
}

# # ## ### ##### ######## ############# #####################
## Helpers

proc ::m::vcs::hg::PostPull {path} {
    debug.m/vcs/hg {}

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
    
    m ops client commits $count
    m ops client size    $kb
    m ops client ok
    return
}

proc ::m::vcs::hg::Count {path} {
    debug.m/vcs/hg {}
    set tip [HgGet identify --num --rev tip -R [HgOf $path]]
    incr tip
    debug.m/vcs/hg { --> $tip }
    return $tip
}

proc ::m::vcs::hg::Hg {args} {
    debug.m/vcs/hg {}
    m exec get-- hg {*}$args
    return
}

proc ::m::vcs::hg::HgGet {args} {
    debug.m/vcs/hg {}
    return [m exec get-- hg {*}$args]
}

proc ::m::vcs::hg::HgOf {path} {
    debug.m/vcs/hg {}
    return [file join $path source.hg]
}

# # ## ### ##### ######## ############# #####################
return
