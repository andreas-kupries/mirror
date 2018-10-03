## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package m::current 0
# Meta author      {Andreas Kupries}
# Meta category    ?
# Meta description ?
# Meta location    https://core.tcl-lang.org/akupries/m
# Meta platform    tcl
# Meta require     ?
# Meta subject     ?
# Meta summary     ?
# @@ Meta End

# # ## ### ##### ######## ############# ######################

package require Tcl 8.5
package require m::state
package require debug
package require debug::caller

# # ## ### ##### ######## ############# ######################

namespace eval ::m {
    namespace export current
    namespace ensemble create
}
namespace eval ::m::current {
    namespace export push swap pop dup top next
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################

debug level  m/current
debug prefix m/current {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::m::current::top {} {
    debug.m/current {}
    return [m state current-repository]
}

proc ::m::current::next {} {
    debug.m/current {}
    return [m state previous-repository]
}

proc ::m::current::push {repo} {
    debug.m/current {}
    m state previous-repository [m state current-repository]
    m state current-repository  $repo
    return
}

proc ::m::current::push {repo} {
    debug.m/current {}
    m state previous-repository [m state current-repository]
    m state current-repository  $repo
    return
}

proc ::m::current::pop {} {
    debug.m/current {}
    m state current-repository  [m state previous-repository]
    m state previous-repository {}
    return
}

proc ::m::current::dup {} {
    debug.m/current {}
    m state previous-repository [m state current-repository]
    return
}

proc ::m::current::swap {} {
    debug.m/current {}
    set c [m state current-repository]
    set p [m state previous-repository]
    m state current-repository  $p
    m state previous-repository $c
    return
}

# # ## ### ##### ######## ############# ######################
package provide m::current 0
return
