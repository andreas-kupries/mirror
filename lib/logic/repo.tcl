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

# search, get-n - representation
#
# :: list (dict ...)
# :: dict ( name, url, id, vcode, sizekb, active -> value )
#         ( sizep, commits, commitp, mins, maxs, lastn )

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
	add remove enable move/mset move/1 has get name \
	known get-n mset search id count
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
	SELECT R.url || ' (: ' || M.name || ')'
	FROM   repository R
	,      mirror_set M
	WHERE  R.id = :repo
	AND    M.id = R.mset
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

proc ::m::repo::id {url} {
    debug.m/repo {}
    return [m db onecolumn {
	SELECT id
	FROM   repository
	WHERE  url = :url
    }]
}

proc ::m::repo::count {} {
    debug.m/repo {}
    return [m db onecolumn {
	SELECT count (*)
	FROM   repository
    }]
}

proc ::m::repo::add {vcs mset url} {
    debug.m/repo {}

    m db eval {
	INSERT
	INTO   repository
	VALUES ( NULL, :url, :vcs, :mset, 1 )
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
    # - active

    set details [m db eval {
	SELECT 'url'    , R.url
	,      'active' , R.active
	,      'vcs'    , R.vcs
	,      'vcode'  , V.code
	,      'mset'   , R.mset
	,      'name'   , M.name
	,      'store'  , S.id
	FROM   repository             R
	,      mirror_set             M
	,      version_control_system V
	,      store                  S
	WHERE  R.id   = :repo
	AND    M.id   = R.mset
	AND    V.id   = R.vcs
	AND    S.vcs  = R.vcs
	AND    S.mset = R.mset
    }]
    debug.m/repo {=> ($details)}
    return $details
}


proc ::m::repo::search {substring} {
    debug.m/repo {}

    set sub [string tolower $substring]
    set series {}
    m db eval {
	SELECT M.name             AS name
	,      R.url              AS url
	,      R.id               AS rid
	,      V.code             AS vcode
	,      S.size_kb          AS sizekb
	,      R.active           AS active
	,      T.min_seconds      AS mins
	,      T.max_seconds      AS maxs
	,      T.window_seconds   AS lastn
	,      S.size_previous    AS sizep
	,      S.commits_current  AS commits
	,      S.commits_previous AS commitp
	FROM   repository             R
	,      mirror_set             M
	,      version_control_system V
	,      store                  S
	,      store_times            T
	WHERE  M.id   = R.mset
	AND    V.id   = R.vcs
	AND    S.mset = R.mset
	AND    S.vcs  = R.vcs
	AND    S.id   = T.store
	ORDER BY M.name ASC
	,        R.url  ASC
    } {
	if {
	    ([string first $sub [string tolower $name]] < 0) &&
	    ([string first $sub [string tolower $url ]] < 0)
	} continue
	lappend series [dict create \
		name    $name \
		url     $url \
		id      $rid \
		vcode   $vcode \
	        sizekb  $sizekb \
		active  $active \
		sizep   $sizep \
		commits $commits \
		commitp $commitp \
		mins    $mins \
		maxs    $maxs \
		lastn   $lastn]
    }
    return $series
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
    set replist {}
    m db eval {
	SELECT M.name             AS name
	,      R.url              AS url
	,      R.id               AS rid
	,      V.code             AS vcode
	,      S.size_kb          AS sizekb
	,      R.active           AS active
	,      T.min_seconds      AS mins
	,      T.max_seconds      AS maxs
	,      T.window_seconds   AS lastn
	,      S.size_previous    AS sizep
	,      S.commits_current  AS commits
	,      S.commits_previous AS commitp
	FROM   repository             R
	,      mirror_set             M
	,      version_control_system V
	,      store                  S
	,      store_times            T
	WHERE  M.id   = R.mset
	AND    V.id   = R.vcs
	AND    S.mset = R.mset
	AND    S.vcs  = R.vcs
	AND    S.id   = T.store
	-- cursor start clause ...
	AND ((M.name > :mname) OR
	     ((M.name = :mname) AND
	      (R.url >= :uname)))
	ORDER BY M.name ASC
	,        R.url  ASC
	LIMIT :lim
    } {
	lappend replist [dict create \
		name    $name \
		url     $url \
		id      $rid \
		vcode   $vcode \
		sizekb  $sizekb \
		active  $active \
		sizep   $sizep \
		commits $commits \
		commitp $commitp \
		mins    $mins \
		maxs    $maxs \
		lastn   $lastn]
    }

    debug.m/repo {reps = (($replist))}

    set have [llength $replist]
    debug.m/repo {have $have of $n requested}

    if {$have <= $n} {
	# Short read. Reset to top.
	set next {}
	debug.m/repo {short}
    } else {
	# Full read. Data from the last element is next top,
	# and not part of the shown list.
	set next [lindex $replist end]
	set next [list [dict get $next name] [dict get $next url]]
	set replist [lrange $replist 0 end-1]
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

proc ::m::repo::enable {repo {flag 1}} {
    debug.m/repo {}
    return [m db eval {
	UPDATE repository
	SET    active = :flag
	WHERE  id = :repo
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
	SELECT M.name
	,      R.url
	FROM   repository R
	,      mirror_set M
	WHERE  R.mset = M.id
	ORDER BY M.name ASC
	,        R.url  ASC
	LIMIT 1
    }]
}

# # ## ### ##### ######## ############# ######################
package provide m::repo 0
return
