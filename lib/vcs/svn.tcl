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

namespace eval m {
    namespace export vcs
    namespace ensemble create
}
namespace eval m::vcs {
    namespace export svn
    namespace ensemble create
}
namespace eval m::vcs::svn {
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

proc ::m::vcs::svn::version {} {
    debug.m/vcs/svn {}

    if {![llength [auto_execok svn]]} {
	m ops client err {`svn` not found in PATH}
	m ops client fail
	return
    }

    set v [m exec get-- svn --version]; debug.m/vcs/svn {raw = (($v))}
    set v [::split  $v \n]            ; debug.m/vcs/svn {split    = '$v'}
    set v [lindex $v 0]               ; debug.m/vcs/svn {sel line = '$v'}
    set v [lindex $v 2]               ; debug.m/vcs/svn {sel col  = '$v'}

    m ops client result $v
    m ops client ok
    return
}

proc ::m::vcs::svn::setup {path url} {
    debug.m/vcs/svn {}

    set repo [SvnOf $path]
    Svn checkout $url $repo
    PostPull $path
    return
}

proc ::m::vcs::svn::cleanup {path} {
    debug.m/vcs/svn {}
    m ops client ok
    return
}

proc ::m::vcs::svn::update {path url first} {
    debug.m/vcs/svn {}

    set repo [SvnOf $path]
    Svn update $repo
    PostPull $path
    return
}

proc ::m::vcs::svn::mergable? {primary other} {
    debug.m/vcs/svn {}
    # Cannot merge SVN checkouts.
    # Each has a single origin url.
    m ops client fail
    return
}

proc ::m::vcs::svn::merge {primary secondary} {
    debug.m/vcs/svn {}
    m ops client ok
    return
}

proc ::m::vcs::svn::split {origin dst} {
    debug.m/vcs/svn {}
    m ops client ok
    return
}

proc ::m::vcs::svn::export {path} {
    debug.m/vcs/svn {}
    # no publication of the local repo
    m ops client ok
    return
}

proc ::m::vcs::svn::url-to-name {url} {
    debug.m/vcs/svn {}
    m ops client fail
    return
}

# # ## ### ##### ######## ############# ######################
    
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

# # ## ### ##### ######## ############# #####################
## Helpers

proc ::m::vcs::svn::PostPull {path} {
    debug.m/vcs/svn {}

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

proc ::m::vcs::svn::Count {path} {
    debug.m/vcs/svn {}
    set tip [string trim [SvnGet info -r HEAD --show-item revision [SvnOf $path]]]
    debug.m/vcs/svn { --> $tip }
    return $tip
}

proc ::m::vcs::svn::SvnOf {path} {
    debug.m/vcs/svn {}
    return [file join $path source.svn]
}

proc ::m::vcs::svn::Svn {args} {
    debug.m/vcs/svn {}
    m exec get-- svn {*}$args
    return
}

proc ::m::vcs::svn::SvnGet {args} {
    debug.m/vcs/svn {}
    return [m exec get-- svn {*}$args]
}

# # ## ### ##### ######## ############# #####################
return
