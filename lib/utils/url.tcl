## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## Helpers for url handling (validation, follow redirection)

# @@ Meta Begin
# Package m::url 0
# Meta author   {Andreas Kupries}
# Meta location https://core.tcl.tk/akupries/????
# Meta platform tcl
# Meta summary     Helpers for file access
# Meta description Helpers for file access
# Meta subject     {file utilities} cat append grep write
# Meta require {Tcl 8.5-}
# @@ Meta End

package provide m::url 0

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require debug
package require debug::caller

package require http 2
package require tls
http::register https 443 tls::socket
# tls::init for good ciphers and protocols

# # ## ### ##### ######## ############# ######################

debug level  m/url
debug prefix m/url {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval ::m {
    namespace export url
    namespace ensemble create
}

namespace eval ::m::url {
    namespace export ok
    namespace ensemble create
}

# # ## ### ##### ######## ############# #####################

proc ::m::url::ok {url rv {follow yes}} {
    debug.m/url {}
    debug.m/url {httpLog setup [proc ::http::Log {args} { package require cmdr::color ; puts [cmdr::color magenta HTTP:[join $args { }]] }]}
    debug.m/url {tls callback  [proc ::intercept {args} { package require cmdr::color ; puts [cmdr::color magenta TLS:[join $args { }]] ; return 1 }]}
    debug.m/url {tls intercept [http::register https 443 {tls::socket -command ::intercept}]}
    debug.m/url {http [package provide http]}
    debug.m/url {tls  [package provide tls]}
    debug.m/url {ssl  [tls::version]}
    debug.m/url {}
    debug.m/url {cmd  [package ifneeded http [package provide http]]}
    debug.m/url {cmd  [package ifneeded tls [package provide tls]]}
    debug.m/url {}
    upvar 1 $rv resolved

    try {
	set token [http::geturl $url -validate 1]
    } on error {e o} {
	if {[string match "*software caused connection abort*" $e]} {
	    # Do nothing, treat as ok. We have no token left however.
	    # Unable to follow redirections. OTOH with such an abort
	    # there is no redirection. So return as is.
	    set resolved $url
	    return 1
	}
	
	debug.m/url {EM $e}
	debug.m/url {EO $o}
	#puts stderr "___ $e [list $o]"
	#puts stderr $::errorInfo
	debug.m/url {--> FAIL}
	return 0
    }

    set state [array get $token]
    http::cleanup $token

    debug.m/url {State: $state}

    if {$follow} {
	set ok [Resolve state]
	if {!$ok} {
	    set resolved {}
	    debug.m/url {--> $ok}
	    return $ok
	}
    }

    set ncode [lindex [dict get $state http] 1]
    debug.m/url {Code: $ncode}

    if {($ncode == 404) &&
	([string match {https://git.code.sf.net/p/*}          $url] ||
	 [string match {https://git.code.sourceforge.net/p/*} $url])
    } {
	# Fake out SourceForge. It reports 404 for its git repository
	# urls yet git itself works fine (seems to ignore this).
	set ncode 200
    }
    
    if {$ncode != 200} {
	set resolved {}
	debug.m/url {--> FAIL}
	return 0
    }

    set resolved [dict get $state url]
    debug.m/url {--> OK}
    return 1
}

proc ::m::url::Resolve {statevar} {
    debug.m/url {}
    upvar 1 $statevar state

    dict set seen [dict get $state url] .
    debug.m/url {Seen: [dict get $state url]}

    while {[dict exists $state meta Location]} {
	set new [dict get $state meta Location]
	if {[dict exists $seen $new]} {
	    # Redirection cycle: Url is not ok.
	    return 0
	}

	try {
	    set token [http::geturl $new -validate 1]
	} on error {e o} {
	    debug.m/url {E $e}
	    #puts stderr "___ $e [list $o]"
	    #puts stderr $::errorInfo
	    return 0
	}

	set state [array get $token]
	http::cleanup $token

	debug.m/url {State: $state}

	dict set seen $new .
	debug.m/url {Seen: $new}
    }
    # No further redirection.
    return 1
}

# # ## ### ##### ######## ############# #####################
## State

namespace eval ::m::url {}

# # ## ### ##### ######## ############# #####################
return
