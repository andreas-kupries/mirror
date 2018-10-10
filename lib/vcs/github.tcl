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
package require m::exec
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
    namespace import ::m::vcs::git::setup
    namespace import ::m::vcs::git::cleanup
    namespace import ::m::vcs::git::check
    namespace import ::m::vcs::git::split
    namespace import ::m::vcs::git::merge
    
    namespace export setup cleanup update check split merge
    namespace ensemble create
}
    
proc m::vcs::github::update {path urls} {
    debug.m/vcs/github {}
    global env
    set env(TERM) xterm

    foreach fork [m::vcs::git::Get hub forks --raw] {
	set repo https://github.com/$fork
	try {
	    m exec silent curl $repo
	} on ok {e o} {
	    lappend urls $repo
	} on error {e o} {
	    # report missing user/repo
	}
    }

    # TODO: Check each fork if actually available.
    # fork api returns hidden repos and users.
    
    # TODO: capture stdout/err, post process both for better error
    # detection. Show errors. Store status.

    return [m vcs git update $path $urls]

    return
    if 0 {
	XXX STOP
	export TERM=xterm
	# Save the forks git hub knows about the repository.
	( cd $repo ; git hub forks --raw ) > ${repo}.forks
	# lines - line = org/repo

	org=$(dirname $fork)
	echo "gh_afork_${org}	git@github.com:$fork"
	url = 


	Do our own check for added/removed forks, and adding custom tags for the removed things.



	# Check for new forks to add or reactivate
	dict for {name location} $incoming {
	    # Skip remotes already managed
	    if {[dict exists $current $name]} continue
	    # New remote. It is no problem if the USER had a remote before.  Such a
	    # remote was removed. And while we have tags for the old branches these
	    # have a serial number (1, 2, ...), so even a second, etc removal will not
	    # cause clashes. Just more tags.

	    lappend lines "git remote add $name $location"
	}

	# Check for forks to deactivate - This done by adding its as tags, and then
	# removing the remote.
	dict for {name location} $current {
	    # Ignore unmanaged
	    if {![string match gh_afork_* $name]} continue
	    # Skip remotes still present
	    if {[dict exists $incoming $name]} continue

	    # Managed remote is gone from origin. Remove, keep as tags
	    set md "mkdir -p refs/tags/attic"
	    set cp "cp -rf refs/remotes/$name [tagname $name]"
	    set rm "git remote remove $name"
	    lappend lines "$md && $cp && $rm"
	}
    }
}

# # ## ### ##### ######## ############# #####################
## Helpers

proc m::vcs::github:://tagname {name} {
    set n 1
    while {1} {
	set tag refs/tags/attic/${name}_$n
	if {![file exists $tag]} { return $tag }
	incr n
    }
}

# # ## ### ##### ######## ############# #####################
return
