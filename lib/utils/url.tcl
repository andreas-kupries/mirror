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

package require http
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
    upvar 1 $rv resolved

    try {
	set token [http::geturl $url -validate 1]
    } on error {e o} {
	#puts stderr "___ $e [list $o]"
	#puts stderr $::errorInfo
	return 0
    }
    
    set state [array get $token]
    http::cleanup $token
    
    if {$follow} {
	set ok [Resolve state]
	if {!$ok} {
	    set resolved {}
	    return $ok
	}
    }

    set ncode [lindex [dict get $state http] 1]
    if {$ncode != 200} {
	set resolved {}
	return 0
    }

    set resolved [dict get $state url]
    return 1
}

proc ::m::url::Resolve {statevar} {
    debug.m/url {}
    upvar 1 $statevar state
    
    dict set seen [dict get $state url] .

    while {[dict exists $state meta Location]} {
	set new [dict get $state meta Location]
	if {[dict exists $seen $new]} {
	    # Redirection cycle: Url is not ok.
	    return 0
	}

	try {
	    set token [http::geturl $new -validate 1]
	} on error {e o} {
	    #puts stderr "___ $e [list $o]"
	    #puts stderr $::errorInfo
	    return 0
	}

	set state [array get $token]
	http::cleanup $token

	dict set seen $new .
    }
    # No further redirection.
    return 1
}

# # ## ### ##### ######## ############# #####################
## State

namespace eval ::m::url {}

# # ## ### ##### ######## ############# #####################
return
