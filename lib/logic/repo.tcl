# -*- mode: tcl; fill-column: 90 -*-
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
	add remove enable move/project move/1 has get name url \
	store known get-n for forks project search id count \
	claim count-pending add-pending drop-pending pending \
	take-pending declaim times fork-locations store! track \
	statistics list-for issues disabled hidden updates just \
	forks! private count-for count-private vcs! \
	phantom-ok phantom-fail phantom-blocked phantom-blocklist
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################

debug level  m/repo
debug prefix m/repo {[debug caller] | }

# # ## ### ##### ######## ############# ######################
## Management of phantoms bouncing between creation and completion failure.

proc ::m::repo::phantom-ok {url} {
    debug.m/repo {}
    m db eval {
	DELETE
	FROM phantom_tracking
	WHERE url = :url
    }
    return
}

proc ::m::repo::phantom-fail {url} {
    debug.m/repo {}
    if {[m db exists {
	SELECT id
	FROM phantom_tracking
	WHERE url = :url
    }]} {
	m db eval {
	    UPDATE phantom_tracking
	    SET    bounces = bounces + 1
	    WHERE  url = :url
	}
    } else {
	m db eval {
	    INSERT
	    INTO phantom_tracking
	    VALUES (NULL, :url, 1)
	}
    }
    return
}

proc ::m::repo::phantom-blocked {url} {
    debug.m/repo {}
    set threshold [m state phantom-block-threshold]
    return [m db exists {
	SELECT id
	FROM phantom_tracking
	WHERE url      = :url
	AND   bounces >= :threshold
    }]
}

proc ::m::repo::phantom-blocklist {} {
    debug.m/repo {}
    set threshold [m state phantom-block-threshold]
    return [m db eval {
	SELECT url
	,      bounces
	FROM phantom_tracking
	ORDER BY url
    }]
}

# # ## ### ##### ######## ############# ######################

proc ::m::repo::statistics {{nophantoms 0}} {
    debug.m/repo {}

    dict set stats vcs {}

    if {$nophantoms} {
	set sql {
	    SELECT count(R.id) AS counts
	    ,      V.name      AS vcs
	    FROM repository             R
	    ,    version_control_system V
	    WHERE  R.vcs = V.id
	    AND    store IS NOT NULL
	    AND    store != ''
	    GROUP BY V.id
	}
    } else {
	set sql {
	    SELECT count(R.id) AS counts
	    ,      V.name      AS vcs
	    FROM repository             R
	    ,    version_control_system V
	    WHERE  R.vcs = V.id
	    GROUP BY V.id
	}
    }
    m db eval $sql {
	dict set stats vcs $vcs $counts
    }

    dict set stats phantom [m db onecolumn {
	SELECT count (*)
	FROM repository
	WHERE store IS NULL
	OR    store = ''
    }]

    dict set stats blocked [m db onecolumn {
	SELECT count (*)
	FROM repository
	WHERE (   store IS NULL
	       OR store = '')
	AND is_private
	AND NOT is_active
    }]

    dict set stats private [count-private]

    return $stats
}

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
	dict set map r/${id}/              $id
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

proc ::m::repo::url {repo} {
    debug.m/repo {}
    return [m db onecolumn {
	SELECT url
	FROM   repository
	WHERE  id = :repo
    }]
}

proc ::m::repo::pname {repo} {
    debug.m/repo {}
    return [m db onecolumn {
	SELECT P.name
	FROM   repository R
	,      project    P
	WHERE  R.id      = :repo
	AND    R.project = P.id
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

proc ::m::repo::count-private {} {
    debug.m/repo {}
    return [m db onecolumn {
	SELECT count (*)
	FROM   repository
	WHERE  is_private
    }]
}

proc ::m::repo::forks! {repo nforks} {
    debug.m/repo {}
    m db eval {
	UPDATE repository
	SET    fork_number = :nforks
	WHERE  id          = :repo
    }
    return
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
	,      last_duration   = :duration
	,      checked         = :now
	,      has_issues      = :issues
	WHERE  id              = :repo
    }
    return
}

proc ::m::repo::add {vcs url project store duration nforks {origin {}}} {
    debug.m/repo {}

    set now  [clock seconds]
    set durl [string tolower $url]

    lappend map @@origin [expr {($origin ne {}) ? ":origin" : "NULL"}]
    lappend map @@store  [expr {($store  ne {}) ? ":store" : "''"}]

    set sql [string map $map {
	INSERT
	INTO   repository
	VALUES ( NULL		-- id
	       , :url		-- url
	       , :durl		-- durl - pattern search support
	       , :project	-- project
	       , :vcs		-- vcs
	       , @@store	-- store
	       , @@origin	-- fork_origin
	       , :nforks        -- fork_number
	       , 0              -- is_tracking_forks
	       , 1		-- is_active
	       , 0              -- is_private
	       , 0		-- has_issues
	       , :now		-- checked
	       , :duration	-- min_duration
	       , :duration	-- max_duration
	       , :duration	-- window_duration
	       , :duration      -- last_duration
	       )
    }]

    m db eval $sql

    set repo [m db last_insert_rowid]

    add-pending $repo

    return $repo
}

proc ::m::repo::for {project} {
    debug.m/repo {}
    return [m db eval {
	SELECT id
	FROM   repository
	WHERE  project = :project
    }]
}

proc ::m::repo::forks {repo} {
    debug.m/repo {}
    return [m db eval {
	SELECT id
	FROM   repository
	WHERE  fork_origin = :repo
	AND    store IS NOT NULL
	AND    store != ''
    }]
}

proc ::m::repo::fork-locations {repo} {
    debug.m/repo {}
    return [m db eval {
	SELECT url
	FROM   repository
	WHERE  fork_origin = :repo
	AND    store IS NOT NULL
	AND    store != ''
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
    debug.m/repo {}
    return [m db onecolumn {
	SELECT store
	FROM   repository
	WHERE  id = :repo
    }]
}

proc ::m::repo::get {repo} {
    debug.m/repo {}

    # Given a repository (by id) follow all the links in the database to retrieve
    # everything related to it
    # - repository (url)
    # - project    (id, and name)
    # - vcs        (id, and code)
    # - store      (id)
    # - active

    set details [m db eval {
	SELECT 'url'      , R.url
	,      'active'   , R.is_active
	,      'private'  , R.is_private
	,      'issues'   , R.has_issues
	,      'tracking' , R.is_tracking_forks
	,      'vcs'      , R.vcs
	,      'vcode'    , V.code
	,      'trackable', V.fork_tracking
	,      'project'  , R.project
	,      'name'     , P.name
	,      'store'    , S.id
	,      'min_sec'  , min_duration
	,      'max_sec'  , max_duration
	,      'win_sec'  , window_duration
	,      'checked'  , checked
	,      'origin'   , fork_origin
	FROM      repository             R
	,         project                P
	,         version_control_system V
	LEFT JOIN store                  S ON R.store = S.id
	WHERE  R.id = :repo
	AND    P.id = R.project
	AND    V.id = R.vcs
    }]
    debug.m/repo {=> ($details)}
    return $details
}

proc ::m::repo::remove {repo} {
    debug.m/repo {}
    return [m db eval {
	DELETE
	FROM  repository
	WHERE id = :repo
	; -- - - -- --- ----- drop out of pending
	DELETE
	FROM  repo_pending
	WHERE repository = :repo
	; -- - - -- --- ----- clear origin links in forks
	UPDATE repository
	SET    fork_origin = NULL
	WHERE  fork_origin = :repo
    }]
}

proc ::m::repo::store! {repo newstore} {
    debug.m/repo {}
    m db eval {
	UPDATE repository
	SET    store = :newstore
	WHERE  id    = :repo
    }
    return
}

proc ::m::repo::vcs! {repo newvcs} {
    # DANGER command - See cmd_hack_vcs
    debug.m/repo {}
    m db eval {
	UPDATE repository
	SET    vcs = :newvcs
	WHERE  id  = :repo
    }
    return
}

proc ::m::repo::enable {repo {flag 1}} {
    debug.m/repo {}
    m db eval {
	UPDATE repository
	SET    is_active = :flag
	WHERE  id        = :repo
    }
    return
}

proc ::m::repo::private {repo {flag 1}} {
    debug.m/repo {}
    m db eval {
	UPDATE repository
	SET    is_private = :flag
	WHERE  id         = :repo
    }
    return
}

proc ::m::repo::track {repo {flag 1}} {
    debug.m/repo {}
    m db eval {
	UPDATE repository
	SET    is_tracking_forks = :flag
	WHERE  id                = :repo
    }
    return
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

    dict set c order      rid
    dict set c use        active
    dict set c subset     [m db eval { SELECT repository FROM repo_pending }]
    list-for c

    return [dict get $c series]
}

proc ::m::repo::take-pending {take args} {
    debug.m/repo {}

    # Ask for one more than actually requested by the configuration. This will cause a
    # short-read (with refill) not only when the table contains less than `take` elements,
    # but also when it contains exactly that many.  If the read is not short we know that
    # at least one element is left.
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
	    # Invoke callback to report that the overall cycle just came around and
	    # started anew.
	    try {
		uplevel 1 $args
	    } on error {e o} {
		# TODO -- Report (internal) error, but do not crash.
	    }
	}
    } else {
	# Full read. Clear taken, the slow way.  Drop the unwanted sentinel element from
	# the end of the result.
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
## Repository indices for various conditions

proc ::m::repo::issues {{nophantoms 0}} {	;# site, project statistics
    debug.m/repo {}

    if {$nophantoms} { dict set c phantom no }
    dict set c troubled yes
    dict set c use      active
    dict set c order    name
    list-for c

    # array set __ $c ; parray __

    return [dict get $c series]
}

proc ::m::repo::disabled {{nophantoms 0}} {	;# site, project statistics
    debug.m/repo {}

    if {$nophantoms} { dict set c phantom no }
    dict set c use   disabled
    dict set c order name
    list-for c

    return [dict get $c series]
}

proc ::m::repo::updates {{nophantoms 0}} { ;# site, glue, project -- ZZZ check users
    debug.m/repo {}

    if {$nophantoms} { dict set c phantom no }
    dict set c order updates
    list-for c

    return [dict get $c series]
}

# # ## ### ##### ######## ############# ######################

proc ::m::repo::count-for {config} {
    # Suboptimal counting - get entire list, without start/limit restrictions, and compute
    # its length. Might be quicker to let the SQL count. More complex too, regarding the
    # SQL generation.

    dict unset config start
    dict unset config limit

    list-for config

    return [llength [dict get $config series]]
}

proc ::m::repo::list-for {cv} {
    upvar 1 $cv config

    # dict :: 'order'        - name/'', vcs, size, updates, rid
    #      :: 'use'          - any/'', active, disabled
    #      :: 'visibility'   - any/'', public, private
    #      :: 'phantom'      - no/'', yes
    #      :: 'troubled'     - no/'', yes
    #      :: 'subset'       - list(id...)
    #      :: 'match'        - '', substring
    #      :: 'vcs'          - any/'', string (vcode)
    #      :: 'start'        - '', number
    #      :: 'limit'        - '', number
    #
    dict with config {}
    set clauses {}

    set has_start [expr {[info exists start] && ($start ne {}) && ($start > 0)}]
    set has_limit [expr {[info exists limit] && ($limit ne {}) && ($limit > 0)}]

    if {$has_start && !$has_limit} {
	set has_limit 1 ; set limit -1 ;# force limit as 'no limit' to satisfy sql syntax.
    }

    SubsetConstraint
    VCSConstraint
    UseConstraint
    ForkConstraint
    VisibilityConstraint
    TroubleConstraint
    StoreConstraint
    PatternMatchConstraint

    set skip no
    switch -exact -- $order {
	name    { append clauses \n "ORDER BY P.dname           @up, R.durl  @up, V.code  @up, S.size_kb @up" }
	url     { append clauses \n "ORDER BY R.durl            @up, P.dname @up, V.code  @up, S.size_kb @up" }
	vcs     { append clauses \n "ORDER BY V.code            @up, P.dname @up, R.durl  @up, S.size_kb @up" }
	size    { append clauses \n "ORDER BY S.size_kb         @up, P.dname @up, R.durl  @up, V.code    @up" }
	time    {
	    # sorting by setup/update time, suppress all without such -- uncompleted phantoms
	    append clauses \n "AND R.last_duration IS NOT NULL AND R.last_duration != ''"
	    append clauses \n "ORDER BY R.last_duration   @up, P.dname @up, R.durl  @up, V.code    @up"
	}
	commits {
	    # sorting by commits, suppress all without such -- uncompleted phantoms
	    append clauses \n "AND S.commits_current IS NOT NULL AND S.commits_current != ''"
	    append clauses \n "ORDER BY S.commits_current @up, P.dname @up, R.durl  @up, V.code    @up"
	}
	rid     { append clauses \n "ORDER BY R.id      ASC" }
	nforks  {
	    # sorting by forks, suppress all without fork data -- uncompleted phantoms, untrackable
	    append clauses \n "AND R.fork_number IS NOT NULL AND R.fork_number != ''"
	    append clauses \n "ORDER BY R.fork_number @up, P.dname   @up, R.durl  @up, V.code  @up, S.size_kb @up"
	}
	updates {
	    # Special! 3 queries. Note that each block applies all the other clauses as well!

	    # From the db.tcl notes on store times
	    #
	    # 1. created <= changed <= updated
	    # 2. (created == changed) -> never changed.
	    #
	    # Block 1: Changed stores, changed order descending
	    # Caller: Insert separators when `updated` changes.
	    #
	    # Block 2: All unchanged stores, create order descending, i.e. last created first
	    # Caller: Insert sep if 1 not empty
	    #
	    # Block 3: Repositories with no store, ordered by name.
	    # Caller: Insert sep if 1+2 not empty

	    set changed   "$clauses AND S.created != S.changed ORDER BY S.changed DESC"
	    set unchanged "$clauses AND S.created =  S.changed ORDER BY S.changed DESC"
	    set phantoms  "$clauses AND (R.store = '' OR R.store IS NULL) ORDER BY pname ASC, url ASC"

	    # ATTENTION: start and limit processing is done manually for this.
	    ##
	    # For simplicity the entire list is retrieved, and then cut down to the
	    # desired range. This should be ok even for a few thousand repositories.
	    # If not revisit the topic, i.e. incremental/partial retrieval.

	    set     x    [REPOS $changed]
	    lappend x {*}[REPOS $unchanged]
	    lappend x {*}[REPOS $phantoms]

	    if {$has_start} { set x [lrange $x $start   end] }
	    if {$has_limit} { set x [lrange $x 0 ${limit}-1] }

	    dict set config series $x
	    set skip yes
	}
	default {
	    error "Bad ordering ($order)"
	}
    }

    if {![info exists odirection]} { set odirection up }
    switch -exact -- $odirection {
	up      { set clauses [string map {@up ASC  @down DESC} $clauses] }
	down    { set clauses [string map {@up DESC @down ASC}  $clauses] }
	default {
	    error "Bad order direction ($odirection)"
	}
    }

    if {!$skip} {
	# Apply offset and limit to be handled in SQL, ...
	if {$has_limit} { append clauses \n "LIMIT $limit" }
	if {$has_start} { append clauses  " OFFSET $start" }

	# ... and retrieve the data
	dict set config series [REPOS $clauses]
    }

    # Compute a new start offset based on incoming start, limit, and length of result.
    if {$has_limit && ($limit >= 0)} {
	# Actual limit present
	if {[llength [dict get $config series]] < $limit} {
	    # Short read (less than limit), reached end, reset to top
	    dict set config start {}
	} else {
	    # Full read, increment start offset to jump chunk on next run
	    if {!$has_start} { set start 0 }
	    incr start $limit
	    dict set config start $start
	}
    } else {
	# No (actual) limit, full read, reset to top
	dict set config start {}
    }

    return
}

proc ::m::repo::SubsetConstraint {} {
    upvar 1 subset subset
    if {![info exists subset]} return
    if {![llength    $subset]} return

    upvar 1 clauses clauses
    append  clauses \n "AND R.id IN ([join $subset ,])"
    return
}

proc ::m::repo::VCSConstraint {} {
    upvar 1 vcs vcs
    if {![info exists vcs]} return
    if {$vcs in {{} any}} return

    upvar 1 clauses clauses
    append  clauses \n "AND V.id = $vcs"
    return
}

proc ::m::repo::UseConstraint {} {
    upvar 1 use use
    if {![info exists use]} return
    if {$use in {{} any}} return

    upvar 1 clauses clauses
    switch -exact -- $use {
	active   { append  clauses \n "AND R.is_active" }
	disabled { append  clauses \n "AND NOT R.is_active" }
	default  { error "Bad use constraint ($use)" }
    }
    return
}

proc ::m::repo::ForkConstraint {} {
    upvar 1 fork fork
    if {![info exists fork]} return
    if {$fork in {{} any}} return

    upvar 1 clauses clauses
    switch -exact -- $fork {
	primary { append  clauses \n "AND (R.fork_origin IS NULL     OR  R.fork_origin = '')" }
	fork    { append  clauses \n "AND  R.fork_origin IS NOT NULL AND R.fork_origin != ''" }
	default { error "Bad fork constraint ($fork)" }
    }
    return
}

proc ::m::repo::VisibilityConstraint {} {
    upvar 1 visibility visibility
    if {![info exists visibility]} return
    if {$visibility in {{} any}} return

    upvar 1 clauses clauses
    switch -exact -- $visibility {
	public  { append  clauses \n "AND NOT R.is_private" }
	private { append  clauses \n "AND R.is_private" }
	default  { error "Bad visibility constraint ($visibility)" }
    }
    return
}

proc ::m::repo::TroubleConstraint {} {
    upvar 1 troubled troubled
    if {![info exists troubled]} return
    if {$troubled eq {}} return

    upvar 1 clauses clauses
    switch -exact -- [expr {!!$troubled}] {
	0 { append  clauses \n "AND NOT R.has_issues" }
	1 { append  clauses \n "AND R.has_issues" }
	default  { error "Bad trouble constraint ($troubled)" }
    }
    return
}

proc ::m::repo::StoreConstraint {} {
    upvar 1 phantom phantom
    if {![info exists phantom]} return
    if {$phantom eq {}} return

    upvar 1 clauses clauses
    switch -exact -- [expr {!!$phantom}] {
	0 { append clauses \n "AND S.id IS NOT NULL" }
	1 { append clauses \n "AND S.id IS NULL" }
    }
    return
}

proc ::m::repo::PatternMatchConstraint {} {
    upvar 1 match match
    if {![info exists match]} return
    if {![llength $match]} return

    upvar 1 clauses clauses

    foreach m $match {
	set m [string tolower $m]
	# Disable all glob-special characters in the pattern. We want a proper substring
	# search, not globbing.
	set m [string map [list * \\* ? \\? \[ \\\[ \{ \\\{ \\ \\\\] $m]
	append clauses \n "AND (GLOB('*${m}*', P.dname) OR GLOB('*${m}*', R.durl))"
    }
    return
}

proc ::m::repo::REPOS {{clauses {}}} {
    debug.m/repo {}

    lappend map @clauses@ $clauses
    set sql [string map $map {
	SELECT R.url               AS url
	,      R.id                AS rid
	,      R.checked           AS checked
	,      R.fork_number       AS nforks
	,      R.fork_origin       AS origin
	,      R.has_issues        AS has_issues
	,      R.is_active         AS is_active
	,      R.is_private        AS is_private
	,      R.is_tracking_forks AS is_tracking
	,      R.min_duration      AS mins
	,      R.max_duration      AS maxs
	,      R.window_duration   AS lastn
	,      R.last_duration     AS last
	,      V.code              AS vcode
	,      V.name              AS vname
	,      V.fork_tracking     AS is_trackable
	,      P.name              AS pname
	,      S.id                AS store
	,      S.changed           AS changed
	,      S.updated           AS updated
	,      S.created           AS created
	,      S.size_kb           AS size
	,      S.commits_current   AS commits
	,      S.size_previous     AS sizep
	,      S.commits_previous  AS commitsp
	FROM      repository             R
	,         project                P
	,         version_control_system V
	LEFT JOIN store                  S ON R.store = S.id
	WHERE     R.project = P.id
	AND       R.vcs     = V.id
	@clauses@
    }]

    debug.m/repo { ($sql) }

    set series {}
    m db eval $sql {
	dict set row url          $url
	dict set row rid     	  $rid
	dict set row checked 	  $checked
	dict set row nforks  	  $nforks
	dict set row origin  	  $origin
	dict set row has_issues	  $has_issues
	dict set row is_active	  $is_active
	dict set row is_private	  $is_private
	dict set row is_tracking  $is_tracking
	dict set row mins   	  $mins
	dict set row maxs   	  $maxs
	dict set row lastn   	  $lastn
	dict set row last   	  $last
	dict set row vcode   	  $vcode
	dict set row vname   	  $vname
	dict set row is_trackable $is_trackable
	dict set row pname   	  [Norm $pname]
	dict set row store   	  $store
	dict set row changed 	  $changed
	dict set row updated 	  $updated
	dict set row created 	  $created
	dict set row size    	  $size
	dict set row commits 	  $commits
	dict set row sizep   	  $sizep
	dict set row commitsp	  $commitsp

	lappend series $row
	unset row
    }

    # series :: list (row)
    # row    :: dict (...)
    # [repo]  url rid checked nforks origin mins maxs lastn
    #         has_issues is_active is_private is_tracking
    # [vcs]   vcode vname is_trackable
    # [proj]  pname
    # [store] store changed updated created size commits sizep commitp

    return $series
}

# # ## ### ##### ######## ############# ######################

proc ::m::repo::Norm {x} {
    debug.m/repo {}
    # Remove leading/trailing whitespace
    set x [string trim $x]
    # Force into a single line, and do tab/space replacement
    # Remove characters used by markdown table syntax
    set x [string map [list \r\n { } \r { } \n { } \t { } | { }] $x]
    # Compress internal runs of white space.
    regsub -all { +} $x { } x
    return $x
}

proc ::m::repo::K {x y} { set x }

# # ## ### ##### ######## ############# ######################
package provide m::repo 0
return
