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
package require m::futil
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
	version detect remotes export
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################

proc ::m::vcs::fossil::LogNormalize {o e} {
    debug.m/vcs/fossil {}

    # Remove time-skew warnings from the error log. Add authorization
    # issues reported in the regular log to the error log.
    lassign [m futil grep {time skew}      $e] _ errors
    lassign [m futil grep {not authorized} $o] auth _

    # Drop rebuild progress reporting
    lassign [m futil grep {% complete} $o] _ o

    set     e $errors
    lappend e {*}$auth

    return [list $o $e]
}

proc ::m::vcs::fossil::detect {url} {
    debug.m/vcs/fossil {}
    if {[catch {
	m exec silent fossil help
    }]} {
	m msg "[color note "fossil"] [color warning "not available"]"
	# Fall through
	return
    }
    return -code return fossil
}

proc ::m::vcs::fossil::version {iv} {
    debug.m/vcs/fossil {}
    if {[llength [auto_execok fossil]]} {
	m exec post-hook ;# clear
	return [lindex [m exec get fossil version] 4]
    }
    upvar 1 $iv issues
    lappend issues "`fossil` not found in PATH"
    return
}

proc ::m::vcs::fossil::setup {path url} {
    debug.m/vcs/fossil {}

    set repo [FossilOf $path]

    Fossil clone $url $repo
    Fossil remote-url off -R $repo
    return
}

proc ::m::vcs::fossil::cleanup {path} {
    debug.m/vcs/fossil {}
    return
}

proc ::m::vcs::fossil::update {path urls first} {
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

proc ::m::vcs::fossil::remotes {path} {
    debug.m/vcs/fossil {}
    return
}

proc ::m::vcs::fossil::export {path} {
    debug.m/vcs/fossil {}
    return "#!/usr/bin/env fossil\nrepository: [FossilOf $path]\n"
}

# # ## ### ##### ######## ############# #####################
## Helpers

proc ::m::vcs::fossil::Fossil {args} {
    debug.m/vcs/fossil {}
    m exec post-hook ::m::vcs::fossil::LogNormalize
    m exec go fossil {*}$args
    return
}

proc ::m::vcs::fossil::FossilGet {args} {
    debug.m/vcs/fossil {}
    m exec post-hook ::m::vcs::fossil::LogNormalize
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
