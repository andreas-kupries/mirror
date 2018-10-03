## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package m::repo 0
# Meta author      {Andreas Kupries}
# Meta category    ?
# Meta description ?
# Meta location    https://core.tcl-lang.org/akupries/m
# Meta platform    tcl
# Meta require     ?
# Meta subject     ?
# Meta summary     ?
# @@ Meta End

# # ## ### ##### ######## ############# ######################

package require Tcl 8.5
package require m::state
package require m::current
package require debug
package require debug::caller

# # ## ### ##### ######## ############# ######################

namespace eval ::m {
    namespace export repo
    namespace ensemble create
}
namespace eval ::m::repo {
    namespace export add has name known get remove size size/vcs
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################

debug level  m/repo
debug prefix m/repo {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::m::repo::known {} {
    # Return map to repository ids.
    # Keys:
    # - rolodex ids
    # - 'current', '@'
    # - 'prev'
    # - repository urls

    m db eval {
	SELECT id, url
	FROM   repository
    } {
	dict set map $url $id
    }

    m db eval {
	SELECT tag, repository
	FROM   rolodex
    } {
	dict set map "#$tag" $repository
    }

    set c [m current top]
    if {$c ne {}} {
	dict set map current $c
	dict set map @       $c
    }

    set p [m current next]
    if {$p ne {}} {
	dict set map prev $c
    }
    
    return $map
}

proc ::m::repo::name {repo} {
    debug.m/repo {}
    return [m db onecolumn {
	SELECT R.url || ' (in ' || N.name || ')'
	FROM   repository R
	,      mirror_set M
	,      name       N
	WHERE  R.id = :repo
	AND    M.id = R.mset
	AND    N.id = M.name
    }]
}

proc ::m::repo::has {url} {
    debug.m/repo {}
    return [m db onecolumn {
	SELECT count (*)
	FROM   repository
	WHERE  url = :url
    }]
}

proc ::m::repo::add {vcs mset url} {
    debug.m/repo {}

    m db eval {
	INSERT
	INTO   repository
	VALUES ( NULL, :url, :vcs, :mset )
    }

    return [m db last_insert_rowid]
}

proc ::m::repo::get {repo} {
    debug.m/repo {}
    return [m db eval {
	SELECT 'url',  R.url
	,      'vcs',  R.vcs
	,      'mset', R.mset
	,      'name', N.name
	FROM   repository R
	,      mirror_set M
	,      name       N
	WHERE  R.id = :repo
	AND    M.id = R.mset
	AND    N.id = M.name
    }]
}

proc ::m::repo::remove {repo} {
    debug.m/repo {}
    return [m db eval {
	DELETE
	FROM  repository
	WHERE id = :repo
    }]
}

proc ::m::repo::size/vcs {vcs mset} {
    debug.m/repo {}
    return [m db onecolumn {
	SELECT count (*)
	FROM   repository
	WHERE  vcs  = :vcs
	AND    mset = :mset
    }]
}

proc ::m::repo::size {mset} {
    debug.m/repo {}
    return [m db onecolumn {
	SELECT count (*)
	FROM   repository
	WHERE  mset = :mset
    }]
}

# # ## ### ##### ######## ############# ######################
package provide m::repo 0
return
