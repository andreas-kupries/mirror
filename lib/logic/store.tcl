## -*- mode: tcl ; fill-column: 90 -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package m::store 0
# Meta author      {Andreas Kupries}
# Meta category    ?
# Meta description ?
# Meta location    https://core.tcl-lang.org/akupries/m
# Meta platform    tcl
# Meta require     ?
# Meta subject     ?
# Meta summary     ?
# @@ Meta End

# by-size, updates, by-name, by-vcs - representation
# :: list (dict ...)
# :: dict (store, mname, vcode, changed, updated, created, size, active -> value)

# # ## ### ##### ######## ############# ######################

package require Tcl 8.5
package require m::db
package require m::state
package require m::vcs
package require debug
package require debug::caller

# # ## ### ##### ######## ############# ######################

namespace eval ::m {
    namespace export store
    namespace ensemble create
}
namespace eval ::m::store {
    namespace export \
	all add remove move rename merge cleave update has check path \
	id vcs-name updates by-name by-size by-vcs move-location \
	get getx repos remotes total-size count search issues disabled \
	has-issues lost clear-lost statistics
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################

debug level  m/store
debug prefix m/store {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::m::store::all {} {
    debug.m/store {}
    return [m db eval {
	SELECT id
	FROM   store
    }]
}

proc ::m::store::statistics {} {
    debug.m/store {}

    lassign {Inf -1 0 0} smin smax n tsz
    lassign {Inf -1 0 0} cmin cmax n tcm

    m db eval {
	SELECT size_kb         AS sz
	,      commits_current AS cm
	FROM store
    } {
	set smin [expr {min($smin,$sz)}]
	set smax [expr {max($smax,$sz)}]
	lappend sizes $sz
	incr tsz $sz
	set cmin [expr {min($cmin,$cm)}]
	set cmax [expr {max($cmax,$cm)}]
	lappend commits $cm
	incr tcm $cm
	incr n
    }

    if {$n == 0} {
	set smean   n/a
	set cmean   n/a
	set smedian n/a
	set cmedian n/a
    } else {
	set smean   [expr {$tsz/$n}]	;# naive mean - all integers
	set cmean   [expr {$tcm/$n}]
	set smedian [lindex [lsort -integer -increasing $sizes]   [expr {[llength $sizes  ]/2}]]
	set cmedian [lindex [lsort -integer -increasing $commits] [expr {[llength $commits]/2}]]
    }

    dict set stats sz_min    $smin
    dict set stats sz_max    $smax
    dict set stats sz_mean   $smean
    dict set stats sz_median $smedian
    dict set stats cm_min    $cmin
    dict set stats cm_max    $cmax
    dict set stats cm_mean   $cmean
    dict set stats cm_median $cmedian
    dict set stats vcs       {}

    m db eval {
	SELECT count(S.id) AS counts
	,      V.name      AS vcs
	FROM store                  S
	,    version_control_system V
	WHERE  S.vcs = V.id
	GROUP BY V.id
    } {
	dict set stats vcs $vcs $counts
    }

    return $stats
}

proc ::m::store::add {vcs url} {
    debug.m/store {}

    set store [Add $vcs]
    set state [m vcs setup $store $vcs $url]
    dict with state {}
    # ok, commits, size, forks, duration

    debug.m/store {setup = ($state)}

    if {$ok} {
	Size    $store $size
	Commits $store $commits
    } else {
	# Remove debris of the partially initialized store
	m vcs cleanup $store $vcs
	set store {}
    }

    return [list $ok $store $duration $commits $size $forks]
}

proc ::m::store::remove {store} {
    debug.m/store {}
    set vcs [VCS $store]

    m db eval {
	DELETE
	FROM  store
	WHERE id = :store
    }

    m vcs cleanup $store $vcs
    return
}

proc ::m::store::merge {target origin} {
    debug.m/store {}

    m vcs merge [VCS $target] $target $origin
    remove $origin
    return
}

proc ::m::store::cleave {store pname} {
    debug.m/store {}

    set vcs  [VCS $store]
    set new  [Add $vcs]

    m vcs cleave $vcs $store $new $pname

    # Copy size information
    Size $new [m db onecolumn {
	SELECT size_kb FROM store WHERE id = :store
    }]
    return $new
}

proc ::m::store::has-issues {store} {
    return [expr {[lindex [m vcs caps $store] 1] ne {}}]
}

proc ::m::store::update {primary url store cycle now before} {
    debug.m/store {}
    clear-lost

    set vcs   [VCS $store]
    set state [m vcs update $store $vcs $url $primary]
    dict with state {}
    # ok, commits, size, forks, duration
    if {!$primary} { set forks {} }

    debug.m/store {update = ($state)}

    if {$ok} {
	Size    $store $size
	Commits $store $commits
	Times   $store $cycle $now [expr {$commits != $before}]
    }

    return [list $ok $duration $commits $size $forks]
}

proc ::m::store::check {storea storeb} {
    debug.m/store {}
    debug.m/store {}
    return [m vcs check [VCS $storea] $storea $storeb]
}

proc ::m::store::has {store} {
    debug.m/store {}
    return [m db onecolumn {
	SELECT count (*)
	FROM   store
	WHERE  id = :store
    }]
}

proc ::m::store::path {store} {
    debug.m/store {}
    return [m vcs path $store]
}

proc ::m::store::getx {repos} {	;# XXX REWORK move to repo package
    debug.m/store {}

    lappend map @@ [join $repos ,]
    set series {}
    m db eval [string map $map {
	SELECT S.id          AS store
	,      P.name        AS mname
	,      V.code        AS vcode
	,      S.changed     AS changed
	,      S.updated     AS updated
	,      S.created     AS created
	,      R.has_issues  AS attend
	,      S.size_kb     AS size
	,      1             AS remote
	,      R.is_active   AS active
	,      R.fork_origin AS origin
	,      R.url         AS url
	,      R.id          AS rid
	FROM      repository             R
	,         project                P
	,         version_control_system V
	LEFT JOIN store                  S ON R.store = S.id
	WHERE R.project = P.id
	AND   R.vcs     = V.id
	AND   R.id      IN (@@)
	ORDER BY mname ASC
	,        vcode ASC
	,        size  ASC
    }] {
	Srow series ;# upvar column variables
    }
    return $series
}

proc ::m::store::get {store} {
    debug.m/store {}
    set details [m db eval {
	SELECT 'size'    , S.size_kb
	,      'vcs'     , S.vcs
	,      'sizep'   , S.size_previous
	,      'commits' , S.commits_current
	,      'commitp' , S.commits_previous
	,      'vcsname' , V.name
	,      'updated' , S.updated
	,      'changed' , S.changed
	,      'created' , S.created
	,      'attend'  , (SELECT sum          (R.has_issues)      FROM repository R WHERE R.store = S.id)
	,      'min_sec' , (SELECT min          (R.min_duration)    FROM repository R WHERE R.store = S.id)
	,      'max_sec' , (SELECT max          (R.max_duration)    FROM repository R WHERE R.store = S.id)
	,      'win_sec' , (SELECT group_concat (R.window_duration) FROM repository R WHERE R.store = S.id)
	,      'remote'  , (SELECT count        (*)                 FROM repository R WHERE R.store = S.id)
	,      'active'  , (SELECT sum          (is_active)         FROM repository R WHERE R.store = S.id)
	FROM   store                  S
	,      version_control_system V
	WHERE S.id    = :store
	AND   S.vcs   = V.id
    }]
    debug.m/store {=> ($details)}
    return $details
}

proc ::m::store::remotes {store} {
    debug.m/store {}
    return [Remotes $store]
}

proc ::m::store::repos {store} {
    debug.m/store {}
    return [m db eval {
	SELECT R.id
	FROM   repository R
	,      store      S
	WHERE S.id    = :store
	AND   R.store = S.id
    }]
}

proc ::m::store::vcs-name {store} {
    debug.m/store {}
    return [m db onecolumn {
	SELECT V.name
	FROM   store                  S
	,      version_control_system V
	WHERE  S.id  = :store
	AND    S.vcs = V.id
    }]
}

proc ::m::store::total-size {} {
    debug.m/store {}
    set sum [m db onecolumn {
	SELECT SUM (size_kb)
	FROM store
    }]
    if {$sum eq {}} { set sum 0 }
    return $sum
}

proc ::m::store::clear-lost {} {
    debug.m/store {}
    foreach s [lost] { remove $s }
    return
}

proc ::m::store::lost {} {
    debug.m/store {}
    return [m db eval {
	SELECT id FROM store
	EXCEPT
	SELECT DISTINCT store FROM repository
    }]
}

proc ::m::store::count {} {
    debug.m/store {}
    return [m db onecolumn {
	SELECT count (*)
	FROM store
    }]
}

proc ::m::store::search {substring} {	;# XXX REWORK move to repo package
    debug.m/store {}

    # List stores ...

    set sub [string tolower $substring]
    set series {}
    m db eval {
	SELECT S.id          AS store
	,      P.name        AS mname
	,      V.code        AS vcode
	,      S.changed     AS changed
	,      S.updated     AS updated
	,      S.created     AS created
	,      R.has_issues  AS attend
	,      S.size_kb     AS size
	,      1             AS remote
	,      R.is_active   AS active
	,      R.fork_origin AS origin
	,      R.url         AS url
	,      R.id          AS rid
	FROM      repository             R
	,         project                P
	,         version_control_system V
	LEFT JOIN store                  S ON R.store = S.id
	WHERE  P.id = R.project
	AND    V.id = R.vcs
	ORDER BY mname ASC
	,        vcode ASC
	,        size  ASC
    } {
	if {
	    [string first $sub [string tolower $mname]] < 0
	} continue
	Srow series ;# upvar column variables
    }
    return $series
}

proc ::m::store::issues {} {	;# XXX REWORK move to repo package
    debug.m/store {}

    # List repositories ...

    set series {}
    set last {}
    m db eval {
	SELECT S.id          AS store
	,      P.name        AS mname
	,      V.code        AS vcode
	,      S.changed     AS changed
	,      S.updated     AS updated
	,      S.created     AS created
	,      R.has_issues  AS attend
	,      S.size_kb     AS size
	,      1             AS remote
	,      R.is_active   AS active
	,      R.fork_origin AS origin
	,      R.url         AS url
	,      R.id          AS rid
	FROM      repository             R
	,         project                P
	,         version_control_system V
	LEFT JOIN store                  S ON R.store = S.id
	WHERE R.has_issues  = 1    -- Flag for "has issues"
	AND   R.is_active   > 0    -- Flag for "not completely disabled"
	AND   R.project = P.id
	AND   R.vcs     = V.id
	ORDER BY mname ASC
	,        vcode ASC
	,        size  ASC
    } {
	Srow+origin series ;# upvar column variables
    }
    return $series
}

proc ::m::store::disabled {} {	;# XXX REWORK move to repo package
    debug.m/store {}

    # List repositories ...

    set series {}
    set last {}
    m db eval {
	SELECT S.id          AS store
	,      P.name        AS mname
	,      V.code        AS vcode
	,      S.changed     AS changed
	,      S.updated     AS updated
	,      S.created     AS created
	,      R.has_issues  AS attend
	,      S.size_kb     AS size
	,      1             AS remote
	,      0             AS active
	,      R.id          AS rid
	,      R.url         AS url
	,      R.fork_origin AS origin
	FROM      repository             R
	,         project                P
	,         version_control_system V
	LEFT JOIN store                  S ON R.store = S.id
	WHERE R.is_active = 0    -- Flag for disabled
	AND   R.project   = P.id
	AND   R.vcs       = V.id
	ORDER BY mname ASC
	,        vcode ASC
	,        size  ASC
    } {
	Srow+rid+url series ;# upvar column variables
    }
    return $series
}

proc ::m::store::by-name {} {	;# XXX REWORK move to repo package
    debug.m/store {}

    # List stores ...

    set series {}
    set last {}
    m db eval {
	SELECT S.id          AS store
	,      P.name        AS mname
	,      V.code        AS vcode
	,      S.changed     AS changed
	,      S.updated     AS updated
	,      S.created     AS created
	,      R.has_issues  AS attend
	,      S.size_kb     AS size
	,      1             AS remote
	,      R.is_active   AS active
	,      R.fork_origin AS origin
	,      R.url         AS url
	FROM      repository             R
	,         project                P
	,         version_control_system V
	LEFT JOIN store                  S ON R.store = S.id
	WHERE R.project = P.id
	AND   R.vcs     = V.id
	ORDER BY mname ASC
	,        vcode ASC
	,        size  ASC
    } {
	if {($last ne {}) && ($last ne $mname)} {
	    Sep series
	}
	set saved $mname
	set mname [expr {($last eq $mname) ? "" : "$mname"}]
	Srow series ;# upvar column variables
	set last $saved
    }
    return $series
}

proc ::m::store::by-vcs {} {	;# XXX REWORK move to repo package
    debug.m/store {}

    # List repositories ...

    set series {}
    m db eval {
	SELECT S.id         AS store
	,      P.name       AS mname
	,      V.code       AS vcode
	,      S.changed    AS changed
	,      S.updated    AS updated
	,      S.created    AS created
	,      R.has_issues AS attend
	,      S.size_kb    AS size
	,      1            AS remote
	,      R.is_active  AS active
	,      R.fork_origin AS origin
	,      R.url         AS url
	FROM      repository             R
	,         project                P
	,         version_control_system V
	LEFT JOIN store                  S ON R.store = S.id
	WHERE R.project = P.id
	AND   R.vcs     = V.id
	ORDER BY vcode ASC
	,        mname ASC
	,        size  ASC
    } {
	Srow series
    }
    return $series
}

proc ::m::store::by-size {} {	;# XXX REWORK move to repo package
    debug.m/store {}

    # List repositories ...

    set series {}
    m db eval {
	SELECT S.id          AS store
	,      P.name        AS mname
	,      V.code        AS vcode
	,      S.changed     AS changed
	,      S.updated     AS updated
	,      S.created     AS created
	,      R.has_issues  AS attend
	,      S.size_kb     AS size
	,      1             AS remote
	,      R.is_active   AS active
	,      R.fork_origin AS origin
	,      R.url         AS url
	FROM      repository             R
	,         project                P
	,         version_control_system V
	LEFT JOIN store                  S ON R.store = S.id
	WHERE R.project = P.id
	AND   R.vcs     = V.id
	ORDER BY size  DESC
	,        mname ASC
	,        vcode ASC
    } {
	Srow series
    }
    return $series
}

proc ::m::store::updates {} {	;# XXX REWORK move to repo package
    debug.m/store {}

    # List repositories ...

    # From the db.tcl notes on store times
    #
    # 1. created <= changed <= updated
    # 2. (created == changed) -> never changed.

    set series {}

    # Block 1: Changed stores, changed order descending
    # Insert separators when `updated` changes.
    set last {}
    m db eval {
	SELECT S.id               AS store
	,      P.name             AS mname
	,      V.code             AS vcode
	,      S.changed          AS changed
	,      S.updated          AS updated
	,      S.created          AS created
	,      R.has_issues       AS attend
	,      S.size_kb          AS size
	,      1                  AS remote
	,      R.is_active        AS active
	,      R.min_duration     AS mins
	,      R.max_duration     AS maxs
	,      R.window_duration  AS lastn
	,      S.size_previous    AS sizep
	,      S.commits_current  AS commits
	,      S.commits_previous AS commitp
	,      R.fork_origin      AS origin
	,      R.url              AS url
	FROM      repository             R
	,         project                P
	,         version_control_system V
	LEFT JOIN store                  S ON R.store = S.id
	WHERE R.project  = P.id
	AND   R.vcs      = V.id
	AND   S.created != S.changed
	ORDER BY S.changed DESC
    } {
	if {($last ne {}) && ($last != $updated)} {
	    Sep series
	}
	Srow+delta series
	set last $updated
    }

    debug.m/store {f/[llength $series]}
    set first [llength $series]

    # Block 2: All unchanged stores, creation order descending,
    # i.e. last created top/first.
    m db eval {
	SELECT S.id               AS store
	,      P.name             AS mname
	,      V.code             AS vcode
	,      S.changed          AS changed
	,      S.updated          AS updated
	,      S.created          AS created
	,      R.has_issues       AS attend
	,      S.size_kb          AS size
	,      1                  AS remote
	,      R.is_active        AS active
	,      R.min_duration     AS mins
	,      R.max_duration     AS maxs
	,      R.window_duration  AS lastn
	,      S.size_previous    AS sizep
	,      S.commits_current  AS commits
	,      S.commits_previous AS commitp
	,      R.fork_origin      AS origin
	,      R.url              AS url
	FROM      repository             R
	,         project                P
	,         version_control_system V
	LEFT JOIN store                  S ON R.store = S.id
	WHERE R.project  = P.id
	AND   R.vcs      = V.id
	AND   S.created = S.changed
	ORDER BY S.created DESC
    } {
	if {$first} { Sep series }
	set changed {}
	set updated {}
	Srow+delta series
	set first 0
    }

    debug.m/store {f/[llength $series]}
    set first [llength $series]

    # Block 3: Repositories with no store, ordered by name.
    m db eval {
	SELECT ''                 AS store
	,      P.name             AS mname
	,      V.code             AS vcode
	,      ''                 AS changed
	,      ''                 AS updated
	,      ''                 AS created
	,      R.has_issues       AS attend
	,      ''                 AS size
	,      1                  AS remote
	,      R.is_active        AS active
	,      R.min_duration     AS mins
	,      R.max_duration     AS maxs
	,      R.window_duration  AS lastn
	,      ''                 AS sizep
	,      ''                 AS commits
	,      ''                 AS commitp
	,      R.fork_origin      AS origin
	,      R.url              AS url
	FROM      repository             R
	,         project                P
	,         version_control_system V
	WHERE R.project  = P.id
	AND   R.vcs      = V.id
	AND   (R.store = '' OR R.store IS NULL)
	ORDER BY mname DESC
    } {
	if {$first} { Sep series }
	set changed {}
	set updated {}
	Srow+delta series
	set first 0
    }

    debug.m/store {r/[llength $series]}
    return $series
}

proc ::m::store::move-location {newpath} {
    debug.m/store {}
    m vcs move $newpath
    return
}

# # ## ### ##### ######## ############# ######################

proc ::m::store::Norm {x} {
    debug.m/store {}
    # Remove leading/trailing whitespace
    set x [string trim $x]
    # Force into a single line, and do tab/space replacement
    # Remove characters used by markdown table syntax
    set x [string map [list \r\n { } \r { } \n { } \t { } | { }] $x]
    # Compress internal runs of white space.
    regsub -all { +} $x { } x
    return $x
}

proc ::m::store::Srow {sv} {	;# XXX REWORK move to repo package
    debug.m/store {}
    upvar 1 \
	$sv series store store mname mname vcode vcode \
	changed changed updated updated created created \
        size size active active remote remote attend attend \
        origin origin url url

    debug.m/store {s=$store, m=$mname, v=$vcode, ch=$changed, up=$updated, cr=$created, sz=$size, r=$remote/$active, trouble=$attend, oring=4origin, url=$url}

    set mname [Norm $mname]
    set row [dict create \
		url     $url \
		origin  $origin \
		store   $store \
		mname   $mname \
		vcode   $vcode \
		changed $changed \
		updated $updated \
		created $created \
		size    $size \
		remote  $remote \
		active  $active \
		attend  $attend \
		]
    lappend series $row
    return
}

proc ::m::store::Srow+origin {sv} {	;# XXX REWORK move to repo package
    debug.m/store {}
    upvar 1 \
	$sv series store store mname mname vcode vcode \
	changed changed updated updated created created \
	size size active active remote remote attend attend \
	origin origin url url rid rid

    debug.m/store {s=$store, m=$mname, v=$vcode, ch=$changed, up=$updated, cr=$created, sz=$size, r=$remote/$active, trouble=$attend, origin=$origin, url=$url, rid=$rid}

    set mname [Norm $mname]
    set row [dict create \
		rid     $rid \
		url     $url \
		store   $store \
		mname   $mname \
		vcode   $vcode \
		changed $changed \
		updated $updated \
		created $created \
		size    $size \
		remote  $remote \
		active  $active \
		attend  $attend \
		origin  $origin
		]
    lappend series $row
    return
}

proc ::m::store::Srow+delta {sv} {	;# XXX REWORK move to repo package
    debug.m/store {}
    upvar 1 \
	$sv series store store mname mname vcode vcode \
	changed changed updated updated created created \
	size size active active remote remote attend attend \
	sizep sizep commits commits commitp commitp mins mins \
	maxs maxs lastn lastn origin origin url url

    debug.m/store {s=$store, m=$mname, v=$vcode, ch=$changed, up=$updated, cr=$created, sz=$size, r=$remote/$active, trouble=$attend}

    set mname [Norm $mname]
    set row [dict create \
		url     $url \
	        origin  $origin \
		store   $store \
		mname   $mname \
		vcode   $vcode \
		changed $changed \
		updated $updated \
		created $created \
		size    $size \
		sizep   $sizep \
		remote  $remote \
		active  $active \
		attend  $attend \
		mins    $mins \
		maxs    $maxs \
		lastn   $lastn \
		commits $commits \
		commitp $commitp \
		]
    lappend series $row
    return
}

proc ::m::store::Srow+rid+url {sv} {	;# XXX REWORK move to repo package
    debug.m/store {}
    upvar 1 \
	$sv series store store mname mname vcode vcode \
	changed changed updated updated created created \
	size size active active remote remote attend attend \
	rid rid url url origin origin

    debug.m/store {s=$store, m=$mname, v=$vcode, ch=$changed, up=$updated, cr=$created, sz=$size, r=$remote/$active, trouble=$attend, rid=$rid, url=$url, origin=$origin}

    set mname [Norm $mname]
    set row [dict create \
		store   $store \
		mname   $mname \
		vcode   $vcode \
		changed $changed \
		updated $updated \
		created $created \
		size    $size \
		remote  $remote \
		active  $active \
		attend  $attend \
		rid     $rid \
		url     $url	\
		origin  $origin ]
    lappend series $row
    return
}

proc ::m::store::Sep {sv} {	;# XXX REWORK move to repo package
    debug.m/store {}
    upvar 1 $sv series
    lappend series {
	store   . mname   . vcode . changed .
	updated . created . size  . active  .
	remote  . attend  . rid   . url     .
	mins    . maxs    . lastn . sizep   .
	commits . commitp .
    }
    return
}

proc ::m::store::Remotes {store {onlyactive 0}} {
    debug.m/store {}
    if {$onlyactive} {
	return [m db eval {
	    SELECT R.url
	    FROM   repository R
	    ,      store      S
	    WHERE S.id    = :store
	    AND   R.store = S.id
	    AND   R.is_active
	}]
    }

    return [m db eval {
	SELECT R.url
	FROM   repository R
	,      store      S
	WHERE S.id    = :store
	AND   R.store = S.id
    }]
}

proc ::m::store::Times {store cycle now haschanged} {
    if {$haschanged} {
	m db eval {
	    UPDATE store
	    SET    updated = :cycle
	    ,      changed = :now
	    WHERE  id = :store
	}
	return
    }

    m db eval {
	UPDATE store
	SET    updated = :cycle
	WHERE  id = :store
	}
    return
}

proc ::m::store::Size {store new} {
    debug.m/store {}

    set current [m db onecolumn {
	SELECT size_kb
	FROM   store
	WHERE  id = :store
    }]

    if {$new == $current} return

    m db eval {
	UPDATE store
	SET    size_previous = size_kb -- Parallel assignment
	,      size_kb       = :new    -- Shift values.
	WHERE  id            = :store
    }

    return
}

proc ::m::store::Commits {store new} {
    debug.m/store {}

    set current [m db onecolumn {
	SELECT commits_current
	FROM   store
	WHERE  id = :store
    }]

    if {$new == $current} return

    m db eval {
	UPDATE store
	SET    commits_previous = commits_current -- Parallel assignment
	,      commits_current  = :new            -- Shift values.
	WHERE  id               = :store
    }
    return
}

proc ::m::store::Add {vcs} {
    debug.m/store {}
    set now [clock seconds]

    m db eval {
	INSERT
	INTO   store
	VALUES ( NULL  -- id
	,	 :vcs  -- vcs
	,	 0     -- size_kb
	,	 0     -- size_previous
	,	 0     -- commits_current
	,	 0     -- commits_previous
	,	 :now  -- created
	,	 :now  -- updated
	,	 :now  -- changed
	)
    }

    return [m db last_insert_rowid]
}

proc ::m::store::VCS {store} {
    debug.m/store {}
    return [m db onecolumn {
	SELECT vcs
	FROM   store
	WHERE  id = :store
    }]
}

proc ::m::store::MSName {project} {
    debug.m/store {}
    return [m db onecolumn {
	SELECT name
	FROM   project
	WHERE  id = :project
    }]
}

##
# # ## ### ##### ######## ############# ######################
## ATTENTION
## These commands are part of the database migration step.
## Their use of old tables and columns is intentional!
## At the point they are called by the migration these are
## the current tables and columns

proc ::m::store::InitialCommits {} {
    debug.m/store {}
    m db eval {
	SELECT id
	FROM   store
    } {
	InitialCommit $id
    }
    return
}

proc ::m::store::InitialCommit {store} {
    debug.m/store {}

    set vcs  [VCS $store]
    set revs [m vcs revs $store $vcs]
    m db eval {
	UPDATE store
	SET    commits_current  = :revs
	,      commits_previous = :revs
	WHERE  id               = :store
    }
    return
}

proc ::m::store::InitialSizes {} {
    debug.m/store {}
    m db eval {
	SELECT id
	FROM   store
    } {
	InitialSize $id
    }
    return
}

proc ::m::store::InitialSize {store} {
    debug.m/store {}

    set new     [m vcs size $store]
    set current [m db onecolumn {
	SELECT size_kb
	FROM   store
	WHERE  id = :store
    }]

    if {$new == $current} return

    m db eval {
	UPDATE store
	SET    size_previous = size_kb -- Parallel assignment
	,      size_kb       = :new    -- Shift values.
	WHERE  id            = :store
    }
    return
}

proc ::m::store::InitialIssues {} {
    debug.m/store {}
    m db eval {
	SELECT id
	FROM   store
    } {
	Attend $id
    }
    return
}

proc ::m::store::Attend {store} {
    debug.m/store {}

    set attend [expr {[lindex [m vcs caps $store] 1] ne {}}]
    m db eval {
	UPDATE store_times
	SET    attend = :attend
	WHERE  store  = :store
    }
    return
}

proc ::m::store::InitialForks {} {
    debug.m/store {}
    m db eval {
	SELECT S.id AS store
	FROM   store                  S
	,      version_control_system V
	WHERE  S.vcs  = V.id
	AND    V.code = 'github'
    } {
	ForksFor $store
    }
    return
}

proc ::m::store::ForksFor {store} {
    debug.m/store {}
    # assert: vcs == github
    set forks [llength [lindex [m vcs github remotes [m vcs path $store]] 1]]
    m db eval {
	INSERT
	INTO store_github_forks
	VALUES ( :store
	       , :forks )
    }
    return
}

# # ## ### ##### ######## ############# ######################
package provide m::store 0
return
