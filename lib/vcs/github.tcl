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

    # git hub cannot be looked for in the path. Must be available as a
    # subcommand of `git` however.
    if {[catch {
	m exec silent git hub help
    }]} {
	m ops client err "`git hub` not installed."
	m ops client fail
	return
    }

    set v [m exec get-- git hub version]
    set v [::split $v \n]
    set v [lindex $v 0 end]
    set v [string trim $v ']

    m ops client result $v
    m ops client ok
    return
}

proc ::m::vcs::github::setup {path url} {
    debug.m/vcs/github {}

    m vcs git setup $path $url

    if {![m ops client ok?]} {
	# git setup has already cleaned up.
	return
    }

    ReportForks $url
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
	# git update has already cleaned up.
	return
    }

    if {$first} {
	ReportForks $url
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
	set desc {}
	puts stderr $e
	puts stderr $o
    }

    if {$desc ne {}} {
	append n $desc
    } else {
	append n $repo
    }
    if {$name ne {}} {
	regexp {^([^[:space:]]*[[:space:]]*)(.*)$} $name -> _ name
	set name [string trim $name "{}"]
	append n " - $name - $owner"
    } else {
	append n "@gh - $owner"
    }

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
