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
package require m::rolodex
package require debug
package require debug::caller

# # ## ### ##### ######## ############# ######################

namespace eval ::m {
    namespace export repo
    namespace ensemble create
}
namespace eval ::m::repo {
    namespace export \
	add remove move/mset move/1 has get name \
	known get-n mset
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################

debug level  m/repo
debug prefix m/repo {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::m::repo::known {} {
    # Return map to repository ids.
    # Keys:
    # - rolodex ids (+ '@current', '@', '@prev')
    # - repository urls

    set map {}

    m db eval {
	SELECT id
	,      url
	FROM   repository
    } {
	dict set map [string tolower $url] $id
    }

    # See also m::mset::known
    # Note, different ids! repo, not mset
    set c {}
    set p {}
    set id -1
    foreach r [m rolodex get] {
	set p $c ; set c $r ; incr id
	dict set map "@$id" $r
    }
    if {$p ne {}} {
	dict set map @prev $p
	dict set map @-1   $p
    }
    if {$c ne {}} {
	dict set map @current $c
	dict set map @        $c
    }
    
    return $map
}

proc ::m::repo::name {repo} {
    debug.m/repo {}
    # TODO MAYBE - repo name - cache?    
    return [m db onecolumn {
	SELECT R.url || ' (: ' || N.name || ')'
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

proc ::m::repo::mset {repo} {
    debug.m/repo {}
    set mset [m db onecolumn {
	SELECT mset
	FROM   repository
	WHERE  id = :repo
    }]
    debug.m/repo {=> ($mset)}
    return $mset
}

proc ::m::repo::get {repo} {
    debug.m/repo {}

    # Given a repository (by id) follow all the links in the database
    # to retrieve everything related to it
    # - repository (url)
    # - mirror set (id, and name)
    # - vcs        (id, and code)
    # - store      (id)
    
    set details [m db eval {
	SELECT 'url'  , R.url
	,      'vcs'  , R.vcs
	,      'vcode', V.code
	,      'mset' , R.mset
	,      'name' , N.name
	,      'store', S.id
	FROM   repository             R
	,      mirror_set             M
	,      name                   N
	,      version_control_system V
	,      store                  S
	WHERE  R.id   = :repo
	AND    M.id   = R.mset
	AND    N.id   = M.name
	AND    V.id   = R.vcs
	AND    S.vcs  = R.vcs
	AND    S.mset = R.mset
    }]
    debug.m/repo {=> ($details)}
    return $details
}


proc ::m::repo::get-n {first n} {
    debug.m/repo {}

    # repo : id of first repository to pull.
    #        Default to 1st if not specified
    # n    : Number of repositories to retrieve.
    #
    # Taking n+1 repositories, last becomes top for next call.
    # If we get less than n, top shall be empty, to reset the cursor.
    
    if {![llength $first]} {
	set first [FIRST]
	debug.m/repo {first = ($first)}
    }
    lassign $first mname uname

    set lim [expr {$n + 1}]
    set replist [m db eval {
	SELECT N.name
	,      R.url
	,      R.id
	,      V.code
	,      S.size_kb
	FROM   repository             R
	,      mirror_set             M
	,      name                   N
	,      version_control_system V
	,      store                  S
	WHERE  M.id   = R.mset
	AND    N.id   = M.name
	AND    V.id   = R.vcs
	AND    S.mset = R.mset
	AND    S.vcs  = R.vcs
	-- cursor start clause ...
	AND ((N.name > :mname) OR
	     ((N.name = :mname) AND
	      (R.url >= :uname)))
	ORDER BY N.name ASC
	,        R.url  ASC
	LIMIT :lim
    }]

    debug.m/repo {reps = (($replist))}
    
    # Expect 5lim elements
    #      = 5(n+1)
    set have [expr {[llength $replist]/5}]
    debug.m/repo {have $have of $n requested}
    
    if {$have <= $n} {
	# Short read. Reset to top.
	set next {}
	debug.m/repo {short}
    } else {
	# Full read. Data from the last 5-tuple is next top,
	# and not part of the shown list.
	set next    [lrange $replist end-4 end-3]
	set replist [lrange $replist 0 end-5]
	debug.m/repo {cut}
    }
    
    return [list $next $replist]
}


proc ::m::repo::remove {repo} {
    debug.m/repo {}
    return [m db eval {
	DELETE
	FROM  repository
	WHERE id = :repo
    }]
}

proc ::m::repo::move/mset {msetold msetnew} {
    debug.m/repo {}
    m db eval {
	UPDATE repository
	SET    mset = :msetnew
	WHERE  mset = :msetold
    }
    return
}

proc ::m::repo::move/1 {repo msetnew} {
    debug.m/repo {}
    m db eval {
	UPDATE repository
	SET    mset = :msetnew
	WHERE  id   = :repo
    }
    return
}

# # ## ### ##### ######## ############# ######################

proc ::m::repo::FIRST {} {
    debug.m/repo {}
    # First known repository.
    # Ordered by mirror set name, then url

    return [m db eval {
	SELECT N.name
	,      R.url
	FROM   repository R
	,      mirror_set M
	,      name       N
	WHERE  R.mset = M.id
	AND    M.name = N.id
	ORDER BY N.name ASC
	,        R.url  ASC
	LIMIT 1
    }]
}

# # ## ### ##### ######## ############# ######################
package provide m::repo 0
return
