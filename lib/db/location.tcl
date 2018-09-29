## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## Database utilities - Mirror specific - Location

# @@ Meta Begin
# Package m::db::location 0
# Meta author   {Andreas Kupries}
# Meta location https://core.tcl.tk/akupries/????
# Meta platform tcl
# Meta summary     Database location
# Meta description Database location
# Meta subject    {database location}
# Meta require {Tcl 8.5-}
# @@ Meta End

package provide m::db::location 0

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval m::db::location {
    namespace export set get
    namespace ensemble create
}

proc m::db::location::get {} {
    variable thelocation
    return $thelocation
}

proc m::db::location::set {loc} {
    variable thelocation $loc
    return
}

namespace eval m::db::location {
    variable thelocation ~/.local/mirror.sqlite
}

# # ## ### ##### ######## ############# #####################
return
