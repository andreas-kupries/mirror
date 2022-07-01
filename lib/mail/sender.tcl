## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package m::mailer 0
# Meta author      {Andreas Kupries}
# Meta category    ?
# Meta description ?
# Meta location    http:/core.tcl.tk/akupries/mirror
# Meta platform    tcl
# Meta require     
# Meta subject     
# Meta summary     ?
# @@ Meta End

# # ## ### ##### ######## ############# ######################

package require Tcl 8.5
package require cmdr::color
package require tls
package require smtp
package require mime
package require debug
package require debug::caller
package require m::msg

# # ## ### ##### ######## ############# ######################

namespace eval ::m {
    namespace export mailer
    namespace ensemble create
}
namespace eval ::m::mailer {
    namespace export to
    namespace ensemble create

    namespace import ::cmdr::color
}

# # ## ### ##### ######## ############# ######################

debug level  m/mailer
debug prefix m/mailer {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::m::mailer::to {receiver corpus} {
    debug.m/mailer {}

    debug.m/mailer {    ================================================}
    debug.m/mailer {[textutil::adjust::indent $corpus {        }]}
    debug.m/mailer {    ================================================}

    set token [mime::initialize -string $corpus]

    m msg* "    To: [color name $receiver] ... "

    try {
	set res [smtp::sendmessage $token -header [list To $receiver] {*}[Config]]
	# XXX REVISIT This may exit on issues, instead of throwing an error ?!
	foreach item $res {
	    m msg "    ERR $item"
	}
    } on error {e o} {
	m msg [color bad $e]
    } finally {
    }
    
    mime::finalize $token
    m msg [color good OK]
    return
}

# # ## ### ##### ######## ############# ######################

proc ::m::mailer::Config {} {
    debug.m/mailer {}

    foreach {option listify setting} {
	-debug    0 debug
	-usetls   0 tls
	-username 0 user
	-password 0 pass
	-servers  1 host
	-ports    0 port
    } {
	set value [m state mail-$setting]
	if {$listify} { set value [list $value] }
	lappend mconfig $option $value
    }

    lappend mconfig -tlspolicy ::m::mailer::TlsPolicy
    lappend mconfig -header [list From [m state mail-sender] ]

    debug.m/mailer {=> ($mconfig)}
    return $mconfig
}

proc ::m::mailer::TlsPolicy {args} {
    debug.m/mailer {}
    m msg $args
    return secure
}

# # ## ### ##### ######## ############# ######################
package provide m::mailer 0
return
