## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## Version Control Systems - Git for Github

# @@ Meta Begin
# Package m::vcs::github 0
# Meta author   {Andreas Kupries}
# Meta location https://core.tcl.tk/akupries/????
# Meta platform tcl
# Meta summary     Version control Git for Github
# Meta description Version control Git for Github
# Meta subject    {version control - git} github
# Meta require {Tcl 8.5-}
# @@ Meta End

package provide m::vcs::github 0

# # ## ### ##### ######## ############# #####################

# The github derivation of the plain git VCS makes use of the `git
# hub` tooling to detect and report forks. The higher parts of the
# system will then add them as remotes.

# The majority of the VCS operations are plain pass through, to git.
# The main exceptions are `update` and `setup`. They perform the
# necessary operations to detect all applicable forks after calling on
# the git operation.

# This package has knowledge of the internals of m::vcs::git, namely
# the various execution helpers, to avoid having to define its own.

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require cmdr::color
package require struct::set
package require fileutil
package require m::exec
package require m::msg
package require m::futil
package require m::url
package require m::vcs::git
package require debug
package require debug::caller

# # ## ### ##### ######## ############# ######################

debug level  m/vcs/github
debug prefix m/vcs/github {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval m {
    namespace export vcs
    namespace ensemble create
}
namespace eval m::vcs {
    namespace export github
    namespace ensemble create
}
namespace eval m::vcs::github {
    namespace import ::m::vcs::git::cleanup
    namespace import ::m::vcs::git::mergable?
    namespace import ::m::vcs::git::merge
    namespace import ::m::vcs::git::split
    namespace import ::m::vcs::git::export

    # Operation backend implementations
    namespace export version \
	setup cleanup update mergable? merge split \
	export url-to-name

    namespace export detect
    namespace ensemble create

    namespace import ::cmdr::color
}

# # ## ### ##### ######## ############# ######################
## Operations implemented for separate process/backend
#
# [/] version                  | Local
# [/] setup       S U          |
# [/] cleanup     S            |       Inherited from git.
# [/] update      S U 1st      |
# [/] mergable?   SA SB        |       Inherited from git.
# [/] merge       S-DST S-SRC  |       Inherited from git.
# [/] split       S-SRC S-DST  |       Inherited from git.
# [/] export      S            |       Inherited from git.
# [/] url-to-name U            |
#

# Operations backend: version
proc ::m::vcs::github::version {} {
    debug.m/vcs/github {}

    if {![llength [auto_execok git]]} {
	m ops client err "`git` not found in PATH"
	m ops client fail
	return
    }

    if 0 {
	# git hub cannot be looked for in the path. Must be available as a
	# subcommand of `git` however.
	if {[catch {
	    m exec silent git hub help
	}]} {
	    m ops client err "`git hub` not installed."
	    m ops client fail
	    return
	}
    }

    if {![llength [auto_execok curl]]} {
	m ops client err "`curl` not found in PATH"
	m ops client fail
	return
    }

    set path [file join ~ .mirror github-authorization]
    if {![file exists $path]} {
	m ops client err "No github authorization file found at $path"
	m ops client fail
	return
    }

    if 0 {
	set v [m exec get-- git hub version]
	set v [::split $v \n]
	set v [lindex $v 0 end]
	set v [string trim $v ']
    }

    set vg [lindex [m exec get-- git version] end]

    set v [m exec get-- curl --version]
    set v [::split $v \n]
    set v [lindex $v 0 1]

    m ops client result "git $vg, curl $v"
    m ops client ok
    return
}

proc ::m::vcs::github::setup {path url} {
    debug.m/vcs/github {}

    m vcs git setup $path $url

    if {![m ops client ok?]} {
	debug.m/vcs/github {git fail - abort}

	# git setup has already cleaned up.
	return
    }

    debug.m/vcs/github {fork processing: count}

    m ops client clear fork
    m ops client fork [CountForks $url]
    return
}

proc ::m::vcs::github::update {path url first} {
    debug.m/vcs/github {}

    # # ## ### ##### ######## #############
    # # ## discard leftover v2 github state files
    file delete $path/origin
    file delete $path/forks-local
    file delete $path/forks-remote
    file delete $path/forks-unverified
    # # ## ### ##### ######## #############

    m vcs git update $path $url $first

    if {![m ops client ok?]} {
	debug.m/vcs/github {git fail - abort}

	# git update has already cleaned up.
	return
    }

    m ops client clear fork
    if {$first} {
	debug.m/vcs/github {fork processing: list}
	foreach f [ListForks $url] { m ops client fork $f }
    } else {
	debug.m/vcs/github {fork processing: count}
	m ops client fork [CountForks $url]
    }
    return
}

proc ::m::vcs::github::url-to-name {url} {
    debug.m/vcs/github {}

    lappend map "https://"        {}
    lappend map "http://"         {}
    lappend map "git@github.com:" {}

    set url [string map $map $url]
    lassign [lreverse [file split $url]] repo owner

    set uinfo [m exec get git hub user $owner]
    set name  [lindex [m futil grep Name [::split $uinfo \n]] 0]

    try {
	set desc [string trim [m exec get git hub repo-get $owner/$repo description]]
    } on error {e o} {
	debug.m/vcs/github {error: $e}
	set desc {}
	#puts stderr $e
	#puts stderr $o
    }

    if {$desc ne {}} {
	debug.m/vcs/github {+ desc: $desc}

	append n $desc
    } else {
	debug.m/vcs/github {+ repo}

	append n $repo
    }
    if {$name ne {}} {
	debug.m/vcs/github {+ name: $name}

	regexp {^([^[:space:]]*[[:space:]]*)(.*)$} $name -> _ name
	set name [string trim $name "{}"]
	append n " - $name - $owner"
    } else {
	debug.m/vcs/github {+ owner: $owner}

	append n "@gh - $owner"
    }

    debug.m/vcs/github {name: $n}

    m ops client result $n
    m ops client ok
    return
}

# # ## ### ##### ######## ############# #####################

proc ::m::vcs::github::detect {url} {
    debug.m/vcs/github {}

    if {![string match *github* $url]} return
    if {[catch {
	m exec silent git hub help
    }]} {
	m msg "[cmdr color note "git hub"] [cmdr color warning "not available"]"
	# Fall through
	return
    }
    if {![llength [auto_execok git]]} {
	m msg "[cmdr color note "git"] [cmdr color warning "not available"]"
	# Fall through
	return
    }
    return -code return github
}

# # ## ### ##### ######## ############# #####################
## Helpers

proc ::m::vcs::github::Link {headers direction} {
    debug.m/vcs/github {}

    # matches ~ ((link: <https://api.github.com/*?sort=newest&per_page=1&page=2>; rel="next"
    #                 , <https://api.github.com/*?sort=newest&per_page=1&page=1423>; rel="last"))

    set lines [::split [m futil cat $headers] \n]

    debug.m/vcs/github {headers: $headers}
    debug.m/vcs/github {lines:   [llength $lines]}

    lassign [m futil grep link: $lines] matches _

    debug.m/vcs/github {matches: [llength $matches]}

    if {[llength $matches]} {
	debug.m/vcs/github {match: [lindex $matches 0]}

	set pattern "*rel=\"$direction\""

	# strip `link:` header
	set header [string map {{link: } {}} [lindex $matches 0]]

	foreach piece [::split $header ,] {
	    debug.m/vcs/github {piece: ($piece)}

	    lassign [::split $piece \;] link key

	    debug.m/vcs/github {link:  ($link)}
	    debug.m/vcs/github {key:   ($key)}

	    if {![string match $pattern $key]} continue

	    return [string trim $link {> <}]
	}
    }

    return
}

proc ::m::vcs::github::ListForks {url} {
    debug.m/vcs/github {}

    set orgrepo [OrgAndRepo $url]
    set url     "https://api.github.com/repos/$orgrepo/forks?sort=newest;per_page=100"
    # per page 100 - max sized chunks of data

    set forks {}
    while {1} {
	debug.m/vcs/github {query: ($url)}

	lassign [QueryAPI $url]	headers stdout stderr
	lassign [m futil grep full_name [::split [m futil cat $stdout] \n]] matches _

	m ops client note matches=[llength $matches]

	foreach match $matches {
	    debug.m/vcs/github {match: ($match)}
	    #    "full_name": "cyanogilvie/critcl",
	    set repo [string trim [lindex [::split $match :] end] ",\" "]

	    debug.m/vcs/github {repo:  $repo}

	    lappend forks https://github.com/$repo
	}

	set url [Link $headers next]

	file delete $headers $stdout $stderr

	if {$url eq {}} break
    }

    return [lsort -dict $forks]
}

proc ::m::vcs::github::CountForks {url} {
    debug.m/vcs/github {}

    set orgrepo [OrgAndRepo $url]

    # The `per_page=1` modifier o nthe url means that we get #forks as #pages,
    # and only the minimal amount of additional data (description of first fork).
    lassign [QueryAPI "https://api.github.com/repos/$orgrepo/forks?sort=newest;per_page=1"] \
	headers stdout stderr

    set url [Link $headers last]

    file delete $headers $stdout $stderr

    if {$url eq {}} {
	# No link `last` found. No forks!
	return 0
    }

    if {[regexp {page=(\d+)$} $url -> count]} {
	debug.m/vcs/github {count: ($count)}
	return $count
    }

    m ops client err "Unable to find fork count"
    m ops client fail
    return
}

proc ::m::vcs::github::QueryAPI {url} {
    debug.m/vcs/github {}

    set path [file join ~ .mirror github-authorization]
    if {![file exists $path]} {
	m ops client err "No github authorization file found at $path"
	m ops client fail
	exit 0
    }

    set token   [string trim [m futil cat $path]]
    set headers [fileutil::tempfile mirror_vcs_gh_hdr_]
    set stdout  [fileutil::tempfile mirror_vcs_gh_out_]
    set stderr  [fileutil::tempfile mirror_vcs_gh_err_]

    m exec get-- curl \
	--request GET \
        $url \
	--header      "Authorization: token $token" \
        --user-agent  curl-mirror-0 \
        --dump-header $headers \
        --output      $stdout \
        --stderr      $stderr \
        --silent \
        --show-error

    list $headers $stdout $stderr
}

proc ::m::vcs::github::OrgAndRepo {url} {
    debug.m/vcs/github {}
    # url = https://github.com/owner/repo
    # origin = ................^^^^^^^^^^

    return [join [lrange [file split $url] end-1 end] /]
}

proc ::m::vcs::github::ReportForks {url} {
    debug.m/vcs/github {}
    upvar 1 path path
    # for `git::Get` - TODO - redesign with proper state in the low-level code.

    # url = https://github.com/owner/repo
    # origin = ................^^^^^^^^^^

    set origin [join [lrange [file split $url] end-1 end] /]
    set forks  [lsort -dict [m::vcs::git::Get hub forks --raw $origin]]

    if {[m exec err-last-get]} {
	m ops client fail ; return
    }

    foreach fork $forks {
	# unverified estimate (saved)
	m ops client fork https://github.com/$fork
    }
    return
}

# # ## ### ##### ######## ############# #####################
return
