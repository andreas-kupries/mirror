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
package require debug
package require debug::caller

# # ## ### ##### ######## ############# ######################

debug level  m/vcs/fossil
debug prefix m/vcs/fossil {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval m::vcs::fossil {
    namespace export setup cleanup update check split merge
    namespace ensemble create

    #namespace import ::m::vcs::Run ::m::vcs::Runx
}

proc m::vcs::fossil::setup {path args} {
    debug.m/vcs/fossil {}
    set secondaries [lassign $args primary]
    set r [FossilOf $path]
    
    m::vcs::Run fossil clone $primary $r
    m::vcs::Run fossil remote-url off -R $r
    
    foreach url $secondaries {
	m::vcs::Run fossil pull $url --once -R $r
    }
    return
}

proc m::vcs::fossil::cleanup {path} {
    debug.m/vcs/fossil {}
    return
}

proc m::vcs::fossil::update {path args} {
    debug.m/vcs/fossil {}
    set r [FossilOf $path]

    set before [Count $path]

    foreach url $args {
	Run fossil pull $url --once -R $r
    }

    set changed [expr {[Count $path] != $before}]
    return $changed
}

proc m::vcs::fossil::check {path url} {
    debug.m/vcs/fossil {}
    # See if the project code can be pulled with a REST call, instead
    # of only through a clone.
    return true
}

proc m::vcs::fossil::split {origin dst} {
    debug.m/vcs/fossil {}
    file copy [FossilOf $origin] [FossilOf $dst]
    return
}

proc m::vcs::fossil::merge {primary secondary} {
    debug.m/vcs/fossil {}
    return
}

# # ## ### ##### ######## ############# #####################
## Helpers

proc m::vcs::fossil::FossilOf {path} {
    debug.m/vcs/fossil {}
    return [file join $path source.fossil]
}

proc m::vcs::fossil::Count {path} {
    debug.m/vcs/fossil {}
    set f  [FossilOf $path]
    foreach line [Runx fossil info -R $f] {
	if {![string match *check-ins* $line]} continue
	return [lindex $line 1]
    }
    return -code error "Checkin count missing from $f"
}

# # ## ### ##### ######## ############# #####################
return
