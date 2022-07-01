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
package require m::format
package require debug
package require debug::caller

# # ## ### ##### ######## ############# ######################

namespace eval ::m {
    namespace export repo
    namespace ensemble create
}
namespace eval ::m::repo {
    namespace export \
	add remove enable move/project move/1 has get name \
	store known get-n for forks project search id count \
	claim count-pending add-pending drop-pending pending \
	take-pending declaim times fork-locations
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

    # See also m::project::known
    # Note, different ids! repository, not project
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
    # TODO MAYBE - in-memory cache of mapping repo -> name
    return [m db onecolumn {
	SELECT R.url || ' (: ' || P.name || ')'
	FROM   repository R
	,      project    P
	WHERE  R.id = :repo
	AND    P.id = R.project
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

proc ::m::repo::times {repo duration now issues} {
    debug.m/repo {}
    # Read current state

    m db eval {
	SELECT min_duration    AS mins
	,      max_duration    AS maxs
	,      window_duration AS window
	FROM   repository
	WHERE  id = :repo
    } {}

    debug.m/repo {lastr = ($window)}

    # See also ::m::glue::StatsTime, ::m::web::site::Store

    set window [m format win $window]
    
    debug.m/repo {mins  = $mins}
    debug.m/repo {maxs  = $maxs}
    debug.m/repo {lastn = ($window)}

    # Modify based on the incoming duration.
    
    if {($mins eq {}) || ($mins < 0) || ($duration < $mins)} { set mins $duration }
    if {                                 $duration > $maxs}  { set maxs $duration }

    lappend window $duration
    set window [m format win-trim $window [m state store-window-size]]
    debug.m/repo {last' = ($window)}

    set window ,[join $window ,],
    debug.m/repo {last. = ($window)}

    # And write the results back
    
    m db eval {
	UPDATE repository
	SET    min_duration    = :mins
	,      max_duration    = :maxs
	,      window_duration = :window
	,      checked         = :now
	,      has_issues      = :issues
	WHERE  id              = :repo
    }
    return
}

proc ::m::repo::add {vcs project store url duration {origin {}}} {
    debug.m/repo {}

    set now [clock seconds]
    
    if {$origin ne {}} {
        m db eval {
	    INSERT
	    INTO   repository
	    VALUES ( NULL	-- id
		   , :url	-- url
		   , :project	-- project
		   , :vcs	-- vcs
		   , :store	-- store
		   , :origin	-- fork_origin
		   , 1		-- is_active
		   , 0		-- has_issues
		   , :now	-- checked
		   , :duration	-- min_duration
		   , :duration	-- max_duration
		   , :duration	-- window_duration
		   )
	}
    } else {
        m db eval {
	    INSERT
	    INTO   repository
	    VALUES ( NULL	-- id
		   , :url	-- url
		   , :project	-- project
		   , :vcs	-- vcs
		   , :store	-- store
		   , NULL	-- fork_origin
		   , 1		-- is_active
		   , 0		-- has_issues
		   , :now	-- checked
		   , :duration	-- min_duration
		   , :duration	-- max_duration
		   , :duration	-- window_duration
		   )
	}
    }

    return [m db last_insert_rowid]
}

proc ::m::repo::for {project} {
    debug.m/project {}
    return [m db eval {
	SELECT id
	FROM   repository
	WHERE  project = :project
    }]
}

proc ::m::repo::forks {repo} {
    debug.m/project {}
    return [m db eval {
	SELECT id
	FROM   repository
	WHERE  fork_origin = :repo
    }]
}

proc ::m::repo::fork-locations {repo} {
    debug.m/project {}
    return [m db eval {
	SELECT url
	FROM   repository
	WHERE  fork_origin = :repo
    }]
}

proc ::m::repo::project {repo} {
    debug.m/repo {}
    set project [m db onecolumn {
	SELECT project
	FROM   repository
	WHERE  id = :repo
    }]
    debug.m/repo {=> ($project)}
    return $project
}

proc ::m::repo::store {repo} {
    debug.m/project {}
    return [m db eval {
	SELECT store
	FROM   repository
	WHERE  id = :repo
    }]
}

proc ::m::repo::get {repo} {
    debug.m/repo {}

    # Given a repository (by id) follow all the links in the database
    # to retrieve everything related to it
    # - repository (url)
    # - project    (id, and name)
    # - vcs        (id, and code)
    # - store      (id)
    # - active
    
    set details [m db eval {
	SELECT 'url'    , R.url
	,      'active' , R.is_active
	,      'issues' , R.has_issues
	,      'vcs'    , R.vcs
	,      'vcode'  , V.code
	,      'project', R.project
	,      'name'   , P.name
	,      'store'  , S.id
	,      'min_sec', min_duration
	,      'max_sec', max_duration
	,      'win_sec', window_duration
	,      'checked', checked
	,      'origin' , fork_origin
	FROM   repository             R
	,      project                P
	,      version_control_system V
	,      store                  S
	WHERE  R.id = :repo
	AND    P.id = R.project
	AND    V.id = R.vcs
	AND    S.id = R.store
    }]
    debug.m/repo {=> ($details)}
    return $details
}


proc ::m::repo::search {substring} {
    debug.m/repo {}

    set sub [string tolower $substring]
    set series {}
    m db eval {
	SELECT P.name             AS name
	,      R.fork_origin      AS origin
	,      R.url              AS url
	,      R.id               AS rid
	,      V.code             AS vcode
	,      S.size_kb          AS sizekb
	,      R.is_active        AS active
	,      R.min_duration     AS mins
	,      R.max_duration     AS maxs
	,      R.window_duration  AS lastn
	,      S.size_previous    AS sizep
	,      S.commits_current  AS commits
	,      S.commits_previous AS commitp
	FROM   repository             R
	,      project                P
	,      version_control_system V
	,      store                  S
	WHERE  P.id   = R.project
	AND    V.id   = R.vcs
	AND    S.id   = R.store
	ORDER BY P.name ASC
	,        R.url  ASC
    } {
	if {
	    ([string first $sub [string tolower $name]] < 0) &&
	    ([string first $sub [string tolower $url ]] < 0)
	} continue
	lappend series [dict create \
		primary [expr {$origin eq {}}] \
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
	SELECT P.name             AS name
	,      R.fork_origin      AS origin
	,      R.url              AS url
	,      R.id               AS rid
	,      V.code             AS vcode
	,      S.size_kb          AS sizekb
	,      R.is_active        AS active
	,      R.min_duration     AS mins
	,      R.max_duration     AS maxs
	,      R.window_duration  AS lastn
	,      S.size_previous    AS sizep
	,      S.commits_current  AS commits
	,      S.commits_previous AS commitp
	FROM   repository             R
	,      project                P
	,      version_control_system V
	,      store                  S
	WHERE  P.id   = R.project
	AND    V.id   = R.vcs
	AND    S.id   = R.store
	-- cursor start clause ...
	AND ((P.name > :mname) OR
	     ((P.name = :mname) AND
	      (R.url >= :uname)))
	ORDER BY P.name ASC
	,        R.url  ASC
	LIMIT :lim
    } {
	lappend replist [dict create \
		primary [expr {$origin eq {}}] \
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
	; -- - - -- --- ----- clear origin links in forks
	UPDATE repository
	SET    fork_origin = NULL
	WHERE  fork_origin = :repo
    }]
}

proc ::m::repo::enable {repo {flag 1}} {
    debug.m/repo {}
    return [m db eval {
	UPDATE repository
	SET    is_active = :flag
	WHERE  id        = :repo
    }]
}

proc ::m::repo::declaim {repo} {
    debug.m/repo {}
    m db eval {
	UPDATE repository
	SET    fork_origin = NULL
	WHERE  id          = :repo
    }
    return
}

proc ::m::repo::claim {origin fork} {
    debug.m/repo {}
    m db eval {
	UPDATE repository
	SET    fork_origin = :origin
	WHERE  id          = :fork
    }
    return
}

proc ::m::repo::move/project {projectold projectnew} {
    debug.m/repo {}
    m db eval {
	UPDATE repository
	SET    project = :projectnew
	WHERE  project = :projectold
    }
    return
}

proc ::m::repo::move/1 {repo projectnew} {
    debug.m/repo {}
    m db eval {
	UPDATE repository
	SET    project = :projectnew
	WHERE  id      = :repo
    }
    return
}

# # ## ### ##### ######## ############# ######################
## Management of pending repositories

proc ::m::repo::count-pending {} {
    debug.m/repo {}
    return [m db onecolumn {
	SELECT count (*)
	FROM   repo_pending
    }]
}

proc ::m::repo::add-pending {repo} {
    debug.m/repo {}
    m db eval {
	INSERT
	INTO repo_pending
	VALUES ( :repo )
    }
    return
}

proc ::m::repo::drop-pending {repo} {
    debug.m/repo {}
    return [m db eval {
	DELETE
	FROM  repo_pending
	WHERE repository = :repo
    }]
    return
}

proc ::m::repo::pending {} {
    debug.m/repo {}
    return [m db eval {
	SELECT P.name        AS name
	,      R.url         AS url
	,      R.fork_origin AS origin
	,      (SELECT count (*)
		FROM repository X
		WHERE fork_origin = R.id) AS nforks
	FROM repository R
	,    project    P
	WHERE R.project = P.id
	AND   R.is_active
	ORDER BY R.ROWID
    }]
}

proc ::m::repo::take-pending {take args} {
    debug.m/repo {}

    # Ask for one more than actually requested by the
    # configuration. This will cause a short-read (with refill) not
    # only when the table contains less than `take` elements, but also
    # when it contains exactly that many.  If the read is not short we
    # know that at least one element is left.
    incr take

    set taken [m db eval {
	SELECT P.repository
	FROM   repo_pending P
	,      repository   R
	WHERE  R.id = P.repository
	AND    R.is_active
	LIMIT :take
    }]
    if {[llength $taken] < $take} {
	# Short read. Clear taken (fast), and refill for next
	# invokation.
	m db eval {
	    DELETE
	    FROM   repo_pending
	    ;
	    INSERT
	    INTO   repo_pending
	    SELECT id
	    FROM   repository
	}

	if {[llength $args]} {
	    # Invoke callback to report that the overall cycle just
	    # came around and started anew.
	    try {
		uplevel 1 $args
	    } on error {e o} {
		# TODO -- Report (internal) error, but do not crash.
	    }
	}
    } else {
	# Full read. Clear taken, the slow way.  Drop the unwanted
	# sentinel element from the end of the result.
	set taken [lreplace [K $taken [unset taken]] end end]
	m db eval [string map [list %% [join $taken ,]] {
	    DELETE
	    FROM repo_pending
	    WHERE repository in (%%)
	}]
    }

    return $taken
}

# # ## ### ##### ######## ############# ######################

proc ::m::repo::FIRST {} {
    debug.m/repo {}
    # First known repository.
    # Ordered by project name, then url

    return [m db eval {
	SELECT P.name
	,      R.url
	FROM   repository R
	,      project    P
	WHERE  R.project = P.id
	ORDER BY P.name ASC
	,        R.url  ASC
	LIMIT 1
    }]
}

# # ## ### ##### ######## ############# ######################

proc ::m::repo::K {x y} { set x }

# # ## ### ##### ######## ############# ######################
package provide m::repo 0
return
