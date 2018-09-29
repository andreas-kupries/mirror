package require Tcl 8.5
#
package provide db::track 0

namespace eval db::track { namespace export set it ; namespace ensemble create }
namespace eval db        { namespace export track  ; namespace ensemble create }

proc db::track::set {args} {
    variable thetrackcmd $args
    return
}

proc db::track::it {args} {
    variable thetrackcmd
    if {![llength $thetrackcmd]} return
    uplevel #0 [list {*}$thetrackcmd {*}$args]
    return
}

namespace eval db::track {
    variable thetrackcmd {}
}
