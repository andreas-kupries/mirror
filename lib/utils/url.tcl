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

#package require http 2
#package require tls
#http::register https 443 tls::socket
# tls::init for good ciphers and protocols

package require m::exec	;# delegate to external curl

# # ## ### ##### ######## ############# ######################

debug level  m/url
debug prefix m/url {[debug caller] | }
#debug level  m/url/sock
#debug prefix m/url/sock {}

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

proc ::m::url::ok {url rv {mcmd {}} {follow yes}} {
    debug.m/url {}
    #debug.m/url {[debug on m/url/sock]}
    #debug.m/url {httpLog setup [proc ::http::Log {args} { m::url::HTTP $args }]}
    #debug.m/url {tls callback  [proc ::intercept {args} { m::url::TLS  $args ; return 1 }]}
    #debug.m/url {tls intercept [http::register https 443 {tls::socket -command ::intercept}]}
    #debug.m/url {http [package provide http]}
    #debug.m/url {tls  [package provide tls]}
    #debug.m/url {ssl  [tls::version]}
    #debug.m/url {}
    #debug.m/url {cmd  [package ifneeded http [package provide http]]}
    #debug.m/url {cmd  [package ifneeded tls  [package provide tls ]]}
    #debug.m/url {}
    upvar 1 $rv resolved

    set ok [Curl MAIN state $url $mcmd]
    if {!$ok} { return 0 }

    if {$follow} {
	set ok [Resolve state $mcmd]
	if {!$ok} {
	    set resolved {}
	    debug.m/url {--> $ok}
	    return $ok
	}
    }

    set ncode [lindex [dict get $state http] 1]

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

proc ::m::url::Resolve {statevar mcmd} {
    debug.m/url {}
    upvar 1 $statevar state

    dict set seen [dict get $state url] .
    debug.m/url {Seen: [dict get $state url]}
    debug.m/url {Meta: [dict get $state meta]}

    while {[dict exists $state meta Location]} {
	set new [dict get $state meta Location]
	if {[dict exists $seen $new]} {
	    # Redirection cycle: Url is not ok.
	    debug.m/url {--> LOOP}
	    return 0
	}

	set ok [Curl REDIRECTED state $new $mcmd]
	if {!$ok} {
	    debug.m/url {--> FAIL}
	    return 0
	}

	dict set seen $new .
	debug.m/url {Seen: $new}
    }

    # No further redirection.
    debug.m/url {--> OK}
    return 1
}


proc ::m::url::Curl {label statevar url {mcmd {}}} {
    debug.m/url {}
    upvar 1 $statevar state

    while {true} {
	set headers [fileutil::tempfile mirror_url_ok_hdr_]
	set stdout  [fileutil::tempfile mirror_url_ok_out_]
	set stderr  [fileutil::tempfile mirror_url_ok_err_]

	m exec get-- curl \
	    --head \
	    $url \
	    --user-agent  curl-mirror-0 \
	    --dump-header $headers \
	    --output      $stdout \
	    --stderr      $stderr \
	    --silent \
	    --show-error

	set hdrs [split [m futil cat $headers] \n]
	file delete $headers $stdout $stderr

	set ncode [lindex $hdrs 0 end]

	debug.m/url {Code: $ncode}

	if {$ncode == 429} {
	    # HTTP/1.1 429 too many requests
	    if {[dict exists $state meta Retry-After]} {
		set delay [dict get $state meta Retry-After]
		debug.m/url {Too many requests, delay $delay as requested}
	    } else {
		set delay 60
		debug.m/url {Too many requests, delay $delay by default}
	    }

	    if {[llength $mcmd]} { uplevel #0 [list {*}$mcmd $delay] }

	    set delay [expr {$delay * 1000}]
	    after $delay

	    # loop and retry -- TODO ZZZ --- stop and fail after 5 trials
	    continue
	}

	# Fake a httpget state
	set      state {}
	dict set state http [lindex $hdrs 0]
	dict set state url  $url

	foreach line [lrange $hdrs 1 end] {
	    regexp {^([^:]*):(.*)$} $line -> key value
	    set key   [string trim $key]
	    set value [string trim $value]
	    dict set state meta [string totitle $key] $value
	}

	return 1
    }
}

# # ## ### ##### ######## ############# #####################
## HTTP, TLS tracing
#
# proc ::m::url::HTTP {words} {
#     debug.m/url/sock {HTTP: [cmdr::color magenta [join $words { }]]}
# }
#
# proc ::m::url::TLS {words} {
#     debug.m/url/sock {TLS:  [cmdr::color magenta [join $words { }]]}
# }

# # ## ### ##### ######## ############# #####################
## State

namespace eval ::m::url {}

# # ## ### ##### ######## ############# #####################
return
