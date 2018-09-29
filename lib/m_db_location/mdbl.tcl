
package require Tcl 8.5

package provide m::db::location 0

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

return
