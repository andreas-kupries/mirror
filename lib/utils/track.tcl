## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## Database utilities - Operation tracking

# @@ Meta Begin
# Package db::track 0
# Meta author   {Andreas Kupries}
# Meta location https://core.tcl.tk/akupries/????
# Meta platform tcl
# Meta summary     Operation tracking
# Meta description Operation tracking
# Meta subject database {operation tracking} tracking
# Meta require {Tcl 8.5-}
# @@ Meta End

package provide db::track 0
package require debug
package require debug::caller

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5

# # ## ### ##### ######## ############# ######################

debug level  db/track
debug prefix db/track {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval db::track {
    namespace export set it
    namespace ensemble create
}
namespace eval db {
    namespace export track
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################

proc db::track::set {args} {
    debug.db/track {}
    variable thetrackcmd $args
    return
}

proc db::track::it {args} {
    debug.db/track {}
    variable thetrackcmd
    if {![llength $thetrackcmd]} return
    uplevel #0 [list {*}$thetrackcmd {*}$args]
    return
}

namespace eval db::track {
    variable thetrackcmd {}
}

# # ## ### ##### ######## ############# #####################
return
