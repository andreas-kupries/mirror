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
package require m::exec
package require debug
package require debug::caller

# # ## ### ##### ######## ############# ######################

debug level  m/vcs/fossil
debug prefix m/vcs/fossil {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval m::vcs {
    namespace export fossil
    namespace ensemble create
}
namespace eval m::vcs::fossil {
    namespace export setup cleanup update check split merge \
	issues detect
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################

proc ::m::vcs::fossil::detect {url} {
    debug.m/vcs/fossil {}
    return -code return fossil
}

proc ::m::vcs::fossil::issues {} {
    debug.m/vcs/fossil {}
    if {[llength [auto_execok fossil]]} return
    return "`fossil` not found in PATH"
}

proc ::m::vcs::fossil::setup {path url} {
    debug.m/vcs/fossil {}
    
    set repo [FossilOf $path]
    
    Fossil clone $url $repo
    Fossil remote-url off -R $repo

    update $path [list $url]
    return
}

proc ::m::vcs::fossil::cleanup {path} {
    debug.m/vcs/fossil {}
    return
}

proc ::m::vcs::fossil::update {path urls} {
    debug.m/vcs/fossil {}
    set repo   [FossilOf $path]
    set before [Count $path]

    foreach url $urls {
	# TODO: capture stdout/err, post process both for better error
	# detection. Show errors. Store status.
	Fossil pull $url --once -R $repo
    }

    return [list $before [Count $path]]
}

proc ::m::vcs::fossil::check {primary other} {
    debug.m/vcs/fossil {}
    return [string equal [ProjectCode $primary] [ProjectCode $other]]
}

proc ::m::vcs::fossil::split {origin dst} {
    debug.m/vcs/fossil {}
    return
}

proc ::m::vcs::fossil::merge {primary secondary} {
    debug.m/vcs/fossil {}
    return
}

# # ## ### ##### ######## ############# #####################
## Helpers

proc ::m::vcs::fossil::Fossil {args} {
    debug.m/vcs/fossil {}
    m exec go fossil {*}$args
    return
}

proc ::m::vcs::fossil::FossilGet {args} {
    debug.m/vcs/fossil {}
    return [m exec get fossil {*}$args]
}

proc ::m::vcs::fossil::FossilOf {path} {
    debug.m/vcs/fossil {}
    return [file join $path source.fossil]
}

proc ::m::vcs::fossil::Count {path} {
    debug.m/vcs/fossil {}
    set f  [FossilOf $path]
    return [Sel 1 [Grep1 check-ins:* [::split [FossilGet info -R $f] \n]]]
}

proc ::m::vcs::fossil::ProjectCode {path} {
    debug.m/vcs/fossil {}
    set f  [FossilOf $path]
    return [Sel 1 [Grep1 project-code:* [::split [FossilGet info -R $f] \n]]]
}

proc ::m::vcs::fossil::Grep1 {pattern lines} {
    debug.m/vcs/fossil {}
    foreach line $lines {
	if {![string match $pattern $line]} continue
	return $line
    }
    return -code error "$pattern missing"
}

proc ::m::vcs::fossil::Sel {index line} {
    return [lindex $line $index]
}

# # ## ### ##### ######## ############# #####################
return
