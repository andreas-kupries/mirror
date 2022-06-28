## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## Version Control Systems - Fossil implementation

# @@ Meta Begin
# Package m::vcs::fossil 0
# Meta author   {Andreas Kupries}
# Meta location https://core.tcl.tk/akupries/????
# Meta platform tcl
# Meta summary     Version control Fossil
# Meta description Version control Fossil
# Meta subject    {version control - fossil}
# Meta require {Tcl 8.5-}
# @@ Meta End

package provide m::vcs::fossil 0

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require cmdr::color
package require m::futil
package require m::exec
package require debug
package require debug::caller

# # ## ### ##### ######## ############# ######################

debug level  m/vcs/fossil
debug prefix m/vcs/fossil {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval m {
    namespace export vcs
    namespace ensemble create
}
namespace eval m::vcs {
    namespace export fossil
    namespace ensemble create
}
namespace eval m::vcs::fossil {
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

proc ::m::vcs::fossil::version {} {
    debug.m/vcs/fossil {}
    if {![llength [auto_execok fossil]]} {
	m ops client err {`fossil` not found in PATH}
	m ops client fail
	return
    }
    
    set version [lindex [m exec get-- fossil version] 4]

    m ops client result $version
    m ops client ok
    return 
}

proc ::m::vcs::fossil::setup {path url} {
    debug.m/vcs/fossil {}
    
    set repo [FossilOf $path]
    Fossil clone $url $repo

    if {[m exec err-last-get]} {
	m ops client fail ; return
    }
    
    Fossil remote-url off -R $repo
    PostPull $path
    return
}

proc ::m::vcs::fossil::cleanup {path} {
    debug.m/vcs/fossil {}
    # Nothing special. No op.
    m ops client ok
    return
}

proc ::m::vcs::fossil::update {path url first} {
    debug.m/vcs/fossil {}

    set repo [FossilOf $path]
    Fossil pull $url --once -R $repo
    PostPull $path
    return
}

proc ::m::vcs::fossil::mergable? {primary other} {
    debug.m/vcs/fossil {}
    if {[ProjectCode $primary] eq [ProjectCode $other]} {
	m ops client result 1
    } else {
	m ops client result 0
    }
    m ops client ok
    return
}

proc ::m::vcs::fossil::merge {primary secondary} {
    debug.m/vcs/fossil {}
    # Nothing special. No op.
    m ops client ok
    return
}

proc ::m::vcs::fossil::split {origin dst} {
    debug.m/vcs/fossil {}
    # Nothing special. No op.
    m ops client ok
    return
}

proc ::m::vcs::fossil::export {path} {
    debug.m/vcs/fossil {}
    m ops client result "#!/usr/bin/env fossil"
    m ops client result "repository: [FossilOf $path]"
    m ops client result ""
    m ops client ok
    return
}

proc ::m::vcs::fossil::url-to-name {url} {
    debug.m/vcs/fossil {}
    
    regsub -- {/index$}    $url {} url
    regsub -- {/timeline$} $url {} url
    set name [lindex [file split $url] end]

    m ops client result $name
    m ops client ok
    return
}

# # ## ### ##### ######## ############# ######################
## Old code

proc ::m::vcs::fossil::detect {url} {
    debug.m/vcs/fossil {}
    if {![llength [auto_execok fossil]]} {
	set p "PATH: "
	puts stderr "fossil = [auto_execok fossil]"
	puts stderr $p[join [::split $::env(PATH) :] \n$p]

	m msg "[cmdr color note "fossil"] [cmdr color warning "not available"]"
	# Fall through
	return
    }
    return -code return fossil
}

# # ## ### ##### ######## ############# #####################
## Helpers

proc ::m::vcs::fossil::PostPull {path} {
    debug.m/vcs/fossil {}

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

proc ::m::vcs::fossil::Count {path} {
    debug.m/vcs/fossil {}
    return [2nd [Grep check-ins:* [FossilGet info -R [FossilOf $path]]]]
}

proc ::m::vcs::fossil::ProjectCode {path} {
    debug.m/vcs/fossil {}
    return [2nd [Grep project-code:* [FossilGet info -R [FossilOf $path]]]]
}

proc ::m::vcs::fossil::FossilOf {path} {
    debug.m/vcs/fossil {}
    return [file join $path source.fossil]
}

proc ::m::vcs::fossil::FossilGet {args} {
    debug.m/vcs/fossil {}
    return [m exec get+route \
		::m::vcs::fossil::Router \
		fossil {*}$args]
}

proc ::m::vcs::fossil::Fossil {args} {
    debug.m/vcs/fossil {}
    # get, and ignore captured result
    m exec get+route \
	::m::vcs::fossil::Router \
	fossil {*}$args
    return
}

proc ::m::vcs::fossil::Grep {pattern lines} {
    debug.m/vcs/fossil {}
    foreach line [::split $lines \n] {
	if {![string match $pattern $line]} continue
	return $line
    }
    return -code error "$pattern missing"
}

proc ::m::vcs::fossil::2nd {line} {
    return [lindex $line 1]
}

proc ::m::vcs::fossil::Router {rv line} {
    upvar 1 $rv route
    # Route time skew warnings from error log to standard log.
    # Route authorization issues from standard log to error log.
    if {[string match {*time skew*}      $line]} { R out }
    if {[string match {*not authorized*} $line]} { R err }
    if {[string match {*% complete*} $line]}     { R ignore }
    return
}

proc ::m::vcs::fossil::R {to} {
    upvar 1 route route
    set route $to
    return -code return
}

# # ## ### ##### ######## ############# #####################
return
