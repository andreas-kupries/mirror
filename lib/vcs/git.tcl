## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## Version Control Systems - Git implementation

# @@ Meta Begin
# Package m::vcs::git 0
# Meta author   {Andreas Kupries}
# Meta location https://core.tcl.tk/akupries/????
# Meta platform tcl
# Meta summary     Version control Git
# Meta description Version control Git
# Meta subject    {version control - git}
# Meta require {Tcl 8.5-}
# @@ Meta End

package provide m::vcs::git 0

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require debug
package require debug::caller

# # ## ### ##### ######## ############# ######################

debug level  m/vcs/git
debug prefix m/vcs/git {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval m::vcs::git {
    namespace export setup cleanup update check split merge
    namespace ensemble create

    #namespace import ::m::vcs::Run ::m::vcs::Runx
}

proc m::vcs::git::setup {path args} {
    debug.m/vcs/git {}
    ::m::vcs::Run git --bare --git-dir [GitOf $path] init
    update $path {*}$args
    return
}

proc m::vcs::git::cleanup {path} {
    debug.m/vcs/git {}
    # Nothing special. No op.
    return
}
    
proc m::vcs::git::update {path args} {
    debug.m/vcs/git {}
    set remotes [Remotes $path]
    # remotes = (url remote ...)

    # Old urls managed by the store
    set uold {}
    foreach {u r} $remotes { dict set uold $u $r }

    # New urls to manage
    set unew {}
    foreach u $args { dict set unew $u . }

    # Steps
    # - Remove remotes for urls not managed anymore
    # - Add remotes for urls newly managed
    # - Fetch from all remotes.

    foreach {u r} $remotes {
	if {[dict exists $unew $u]} continue
	# Old remote missing in new, remove
	Git remote remove $r
    }
    foreach $u $args {
	if {[dict exists $uold $u]} continue
	# New remote missing in old, add
	set r [RemoteOf $u]
	dict set uold $u $r
	Git remote add $r $u
    }

    # With remotes on the repository now matching the incoming urls we
    # can now fetch.

    set before [Count $path]
    
    foreach u $args {
	set r [dict get $uold $u]
	catch {   
	    Git fetch --tags $r
	}
    }

    set changed [expr {[Count $path] != $before}]
    return $changed
}

proc m::vcs::git::check {path url} {
    debug.m/vcs/git {}
    # No true check. Any repository can fit with any other.
    # The user is (unfortunately) responsible for keeping
    # non-matching repositories apart.
    return true
}

proc m::vcs::git::split {origin dst} {
    debug.m/vcs/git {}
    # Note: The mismatching remotes are cleared up by the next call to
    # `update`.
    
    file copy [GitOf $origin] [GitOf $dst]
    return
}

proc m::vcs::git::merge {primary secondary} {
    debug.m/vcs/git {}
    # Note: The remotes missing in primary are fixed by the next call
    # to `update`.
    return
}

# # ## ### ##### ######## ############# #####################
## Helpers

proc m::vcs::git::Remotes {path} {
    debug.m/vcs/git {}
    set result {}
    foreach r [Git remote] {
	if {![Owned $r]} continue
	lappend result [UrlfOf $r] $r
    }
    return $result
}

proc m::vcs::git::Count {path} {
    debug.m/vcs/git {}
    return [m::vcs::Runx git --git-dir [GitOf $path] rev-list --all --count]
}

proc m::vcs::git::Owned {remote} {
    debug.m/vcs/git {}
    return [string match m-vcs-git-* $remote]
}

proc m::vcs::git::UrlOf {remote} {
    debug.m/vcs/git {}
    return [string map \
		{%3a : %2f / %3A : %2F /} \
		[string range $remote [string length m-vcs-git-] end]]
}

proc m::vcs::git::RemoteOf {url} {
    debug.m/vcs/git {}
    return "m-vcs-git-[string map {: %3a / %2f} $url]"
}

proc m::vcs::git::GitOf {path} {
    debug.m/vcs/git {}
    return [file join $path _git]
}

proc m::vcs::git::Git {args} {
    debug.m/vcs/git {}
    upvar 1 path path
    m::vcs::Run git --git-dir [GitOf $path] {*}$args
}

proc m::vcs::git::GitX {args} {
    debug.m/vcs/git {}
    upvar 1 path path
    m::vcs::Runx git --git-dir [GitOf $path] {*}$args
}

# # ## ### ##### ######## ############# #####################
return

if 0 {

    # Prune kills all the branches from the non-origin remotes, and
    # then we refetch them :(

    # catch { exec git --git-dir $path fetch --tags --prune --all 2> $elog | tee $log }
    catch { exec git --git-dir $path fetch --tags --all 2> $elog | tee $log }

    
    # get remotes, compare to args ...
    # remove remotes for missing urls
    # add remotes for new urls

    # fetch from all remotes.
    # detect changes ...
    
    / - %2f
    : - %3a

    special characters not allowed in names for remotes

    => encoded url can be remote name


}
