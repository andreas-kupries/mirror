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

# The github derivation of the plain git VCS makes use of the
# `git hub` tooling to auto-detect forks and use them as remotes.
#
# Note: While the auto-detected forks/remotes are known to the backend
# git store, they are not known at the repository level, i.e. they are
# not seen in the management database.

# The majority of the VCS operations are plain pass through, to git.
# The exception is `update`. It performs the necessary operations to
# detect all applicable forks before calling on the git operation..

# This package has knowledge of the internals of m::vcs::git, namely
# the various execution helpers, to avoid having to define its own.

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require cmdr::color
package require struct::set
package require m::exec
package require m::msg
package require m::futil
package require m::vcs::git
package require debug
package require debug::caller

# # ## ### ##### ######## ############# ######################

debug level  m/vcs/github
debug prefix m/vcs/github {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval m::vcs {
    namespace export github
    namespace ensemble create
}
namespace eval m::vcs::github {
    namespace import ::m::vcs::git::cleanup
    namespace import ::m::vcs::git::check
    namespace import ::m::vcs::git::split
    namespace import ::m::vcs::git::merge
    namespace import ::m::vcs::git::export

    namespace export setup cleanup update check split merge \
	detect version remotes export
    namespace ensemble create

    namespace import ::cmdr::color
}

# # ## ### ##### ######## ############# #####################

proc ::m::vcs::github::detect {url} {
    debug.m/vcs/github {}
    if {![string match *github* $url]} return
    if {[catch {
	m exec silent git hub help
    }]} {
	m msg "[color note "git hub"] [color warning "not available"]"
	# Fall through
	return
    }
    return -code return github
}

proc ::m::vcs::github::version {iv} {
    debug.m/vcs/github {}
    upvar 1 $iv issues
    set ok 1
    if {![llength [auto_execok git]]} {
	set ok 0
	lappend issues "`git` not found in PATH"
    } elseif {[catch {
	m exec silent git hub help
    }]} {
	set ok 0
	lappend issues "`git hub` not installed."
    }
    if {![llength [auto_execok curl]]} {
	lappend issues [color bad "`curl` not found in PATH"]
    }

    if {!$ok} return

    set v [m exec get git hub version]
    set v [::split $v \n]
    set v [lindex $v 0 end]
    set v [string trim $v ']
    return $v
}

proc ::m::vcs::github::setup {path url} {
    debug.m/vcs/github {}
    # url = https://github.com/owner/repo
    # origin = ................^^^^^^^^^^
    #
    # Saving origin information for `git hub fork` to use to always
    # target the proper repository when asking for information about
    # the forks.
    OriginSave $path \
	[join [lrange [file split $url] end-1 end] /]

    m vcs git setup $path $url
    return
}

proc ::m::vcs::github::update {path urls first} {
    debug.m/vcs/github {}

    set forks [Forks $path]
    set old   [ForksLoad $path]

    lassign [struct::set intersect3 $old $forks] _ gone new

    foreach fork $new {
	lassign [::split $fork /] org repo
	set label m-vcs-github-fork-$org
 	set url https://github.com/$fork
	m::vcs::git::Git remote add $label $url
    }

    set git [m::vcs::git::GitOf $path]

    foreach fork $gone {
	lassign [::split $fork /] user repo
	set label m-vcs-github-fork-$user

	# Convert all branches defined by this remote (i.e. user or
	# org) into a versioned tag. The versioning means that there
	# will be no naming conflicts if this fork is added later
	# again, removed again, etc.

	# __Attention__: This code knows a bit about the internal
	# organization of a git repository, directory wise. It uses
	# this to extract the branch names and associated uuids for a
	# remote. Writing the tags however is done through `git`
	# itself.

	foreach branch [glob -nocomplain -directory $git/refs/remotes/$label *] {
	    set uuid   [string trim [m futil cat $branch]]
	    set branch [file tail $branch]
	    set tag    [Tag $git/refs/tags ${user}/${branch}]

	    m::vcs::git::Git tag $tag $uuid
	}

	m::vcs::git::Git remote remove $label
    }

    # Save fork information for future updates. See above for usage
    # (change detection).
    ForksSave $path $forks

    return [m vcs git update $path $urls $first]
}

proc ::m::vcs::github::remotes {path} {
    debug.m/vcs/github {}
    set urls {}
    foreach fork [ForksLoad $path] {
	lappend urls https://github.com/$fork
    }
    return [list Forks $urls]
}

# # ## ### ##### ######## ############# #####################
## Helpers

proc ::m::vcs::github::Tag {path label} {
    debug.m/vcs/github {}
    set n 1
    while {1} {
	set tag attic/${label}/$n
	if {![file exists $path/$tag]} { return $tag }
	incr n
    }
}

proc ::m::vcs::github::Forks {path} {
    debug.m/vcs/github {}
    global env
    set env(TERM) xterm

    # Pull the origin to query about forks
    set origin [OriginLoad $path]

    set forks {}
    foreach fork [m::vcs::git::Get hub forks --raw $origin] {
	set url https://github.com/$fork
	# Check if the fork is actually available :: The git hub REST
	# api reports all forks regardless of status wrt the rest of
	# the system. I.e. a user/repo marked as suspicious and hidden
	# is still reported here. Checking against the regular web
	# interface allows us to filter these out.
	try {
	    m exec nc-get curl -s -f -I $url
	    # -L  Follow temporary and permanent redirections
	    # -I  HEAD only
	    # -f  Silent fail (ignore fail document)
	    # -s  Silence other output
	} on ok {e o} {
	    lappend forks $fork
	} on error {e o} {
	    # report a missing fork
	}
    }

    return $forks
}

proc ::m::vcs::github::OriginSave {path origin} {
    debug.m/vcs/github {}
    m futil write $path/origin $origin
    return
}

proc ::m::vcs::github::OriginLoad {path} {
    debug.m/vcs/github {}
    return [string trim [m futil cat $path/origin]]
}

proc ::m::vcs::github::ForksSave {path forks} {
    debug.m/vcs/github {}
    m futil write $path/forks [join $forks \n]
    return
}

proc ::m::vcs::github::ForksLoad {path} {
    debug.m/vcs/github {}
    if {[catch {
	m futil cat $path/forks
    } forks]} {
	set forks {}
    } else {
	set forks [::split [string trim $forks] \n]
    }
    return $forks
}

# # ## ### ##### ######## ############# #####################
return
