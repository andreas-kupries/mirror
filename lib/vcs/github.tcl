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

namespace eval m::vcs {
    namespace export github
    namespace ensemble create
}
namespace eval m::vcs::github {
    namespace import ::m::vcs::git::cleanup
    namespace import ::m::vcs::git::revs
    namespace import ::m::vcs::git::check
    namespace import ::m::vcs::git::cleave
    namespace import ::m::vcs::git::merge
    namespace import ::m::vcs::git::export

    namespace export setup cleanup update check cleave merge \
	detect version remotes export name-from-url revs
    namespace ensemble create

    namespace import ::cmdr::color
}

# # ## ### ##### ######## ############# #####################

proc ::m::vcs::github::name-from-url {url} {
    debug.m/vcs/github {}
    lappend map "https://"        {}
    lappend map "http://"         {}
    lappend map "git@github.com:" {}

    set url [string map $map $url]
    lassign [lreverse [file split $url]] repo owner

    set uinfo [m exec get git hub user $owner]
    set name  [lindex [m futil grep Name [split $uinfo \n]] 0]

    try {
	set desc [m exec get git hub repo-get $owner/$repo description]
    } on error {e o} {
	set desc {}
	puts stderr $e
	puts stderr $o
    }

    if {$desc ne {}} {
	append n "$desc"
    } else {
	append n $repo
    }
    if {$name ne {}} {
	regexp {^([^[:space:]]*[[:space:]]*)(.*)$} $name -> _ name
	set name [string trim $name "{}"]
	append n " - $name - $owner"
    } else {
	append n " - $owner"
    }

    return $n
}

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
    if {!$ok} return

    set v [m exec get git hub version]
    set v [split $v \n]
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

    set forks [llength [ForksRemote $path 0 0]] ;# unverified estimate (saved)

    # TODO: Make the fork warn/error thresholds configurable.
    # TODO: Implement --force'd operation.
    if {$forks > 1000} {
	m msg "  Estimated [cmdr color bad $forks] forks to track."
	m msg "  [cmdr color warning "This will be very slow to setup and update."]"
	return -code error -errorcode {M VCS GITHUB FORKS TOOMANY} \
	    "Too slow for sensible operation. You may --force us"
    }
    if {$forks > 500} {
	m msg "  Estimated [cmdr color bad $forks] forks to track."
	m msg [cmdr color warning "This will be slow to setup and update."]
	m msg "  Continuing ..."
    } else {
	m msg "  Estimated [cmdr color note $forks] forks to track."
    }

    return
}

proc ::m::vcs::github::update {path urls first} {
    debug.m/vcs/github {}

    set forks [ForksRemote $path $first] ;# first => skip query
    set old   [ForksLocal  $path]

    debug.m/vcs/github {Got  [llength $forks]}
    debug.m/vcs/github {Have [llength $old]}

    lassign [struct::set intersect3 $old $forks] _ gone new

    debug.m/vcs/github {Same [llength $_]}
    debug.m/vcs/github {New  [llength $new]}
    debug.m/vcs/github {Gone [llength $gone]}
    foreach _ $new  { debug.m/vcs/github {New  ($_)} }
    foreach _ $gone { debug.m/vcs/github {Gone ($_)} }

    # Note about order: Drop removed forks first before adding any
    # new.  The drop/add may be a rename done by a dev, and in that
    # case adding first fails as the dev already has a remote.

    set git [m::vcs::git::GitOf $path]

    foreach fork $gone {
	lassign [split $fork /] user repo
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

	if {[file exists $git/refs/remotes/$label]} {
	    foreach branch [fileutil::find $git/refs/remotes/$label] {
		if {[file isdirectory $branch]} continue
		debug.m/vcs/github {Branch $branch}

		set uuid   [string trim [m futil cat $branch]]
		set branch [file tail $branch]
		set tag    [Tag $git/refs/tags ${user}/${branch}]

		debug.m/vcs/github {Tag    $uuid $tag}
		m::vcs::git::Git tag $tag $uuid
	    }
	}

	debug.m/vcs/github {Remove  $label}
	m::vcs::git::Git remote remove $label
    }

    foreach fork $new {
	lassign [split $fork /] org repo
	set label m-vcs-github-fork-$org
 	set url https://github.com/$fork

	debug.m/vcs/github {Add     $label $url}
	m::vcs::git::Git remote add $label $url
    }

    set counts [m vcs git update $path $urls $first]
    return [linsert $counts end $forks]
}

proc ::m::vcs::github::remotes {path} {
    debug.m/vcs/github {}
    set urls {}
    foreach fork [ForksLocal $path] {
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

proc ::m::vcs::github::OriginSave {path origin} {
    debug.m/vcs/github {}
    m futil write $path/origin $origin
    return
}

proc ::m::vcs::github::OriginLoad {path} {
    debug.m/vcs/github {}
    return [string trim [m futil cat $path/origin]]
}

proc ::m::vcs::github::ForksSave {path suffix forks} {
    debug.m/vcs/github {}
    m futil write $path/forks$suffix [join $forks \n]\n
    return
}

proc ::m::vcs::github::ForksLoad {path suffix} {
    debug.m/vcs/github {}
    return [split [string trim [m futil cat $path/forks$suffix]] \n]
}

proc ::m::vcs::github::ForksRemote {path {skip 0} {verified 1}} {
    debug.m/vcs/github {}

    if {!$skip} {
	global env
	set env(TERM) xterm
	#puts -nonewline \nFORKS\t ; flush stdout

	# Pull the origin to query about forks
	set origin [OriginLoad $path]

	try {
	    set possibleforks [lsort -dict [m::vcs::git::Get hub forks --raw $origin]]
	} trap CHILDSTATUS {e o} {
	    set possibleforks {}
	}

	ForksSave $path -remote-unverified $possibleforks
    } else {
	set possibleforks [ForksLoad $path -remote-unverified]
    }

    if {!$verified} { return $possibleforks }

    set forks {}
    foreach fork $possibleforks {
	debug.m/vcs/github {Verify $fork}

	set url https://github.com/$fork
	# Check if the fork is actually available :: The git hub REST
	# api reports all forks regardless of status wrt the rest of
	# the system. I.e. a user/repo marked as suspicious and hidden
	# is still reported here. Checking against the regular web
	# interface allows us to filter these out.

	#puts -nonewline . ; flush stdout
	if {[m url ok $url _]} {
	    debug.m/vcs/github {    Ok $url}
	    lappend forks $fork
	} else {
	    # report a missing fork
	    debug.m/vcs/github {  FAIL $url}
	}
    }

    #puts PULLED
    ForksSave $path -remote $forks
    return $forks
}

proc ::m::vcs::github::ForksLocal {path} {
    debug.m/vcs/github {}

    lassign [m futil grep {\(fetch\)$} \
		 [split [m::vcs::git::Get remote -v] \n]] \
	forks _

    set r {}
    foreach fork [lsort -dict $forks] {
	lassign $fork label url _
	if {![string match m-vcs-github-fork-* $label]} continue
	set fk [join [lrange [split $url /] end-1 end] /]

	debug.m/vcs/github {$label = $url => $fk}
	lappend r $fk
    }

    ForksSave $path -local $r
    return $r
}

# # ## ### ##### ######## ############# #####################
return
