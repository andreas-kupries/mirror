## -*- tcl -*-
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
	add remove move rename merge split update has check \
	id vcs-name updates by-name by-size by-vcs move-location \
	get remotes total-size count search issues disabled
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################

debug level  m/store
debug prefix m/store {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::m::store::add {vcs mset name url} {
    debug.m/store {}

    set store [Add $vcs $mset]

    m vcs setup $store $vcs $name $url
    Size $store

    return $store
}

proc ::m::store::remove {store} {
    debug.m/store {}
    set vcs [VCS $store]

    m db eval {
	DELETE
	FROM  store_times
	WHERE store = :store
	;
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

proc ::m::store::split {store msetnew} {
    debug.m/store {}

    set vcs  [VCS $store]
    set new  [Add $vcs $msetnew ]
    set name [MSName $msetnew]
    m vcs split $vcs $store $new $name
    Size $new
    return
}

proc ::m::store::update {store cycle now} {
    debug.m/store {}

    set vcs [VCS $store]

    # Get all repositories for this store (same VCS, same mirror set),
    # then feed everything to the vcs layer.

    set remotes [Remotes $store]
    set counts  [m vcs update $store $vcs $remotes]

    Attend $store
    lassign $counts before after
    if {$after != $before} {
	m db eval {
	    UPDATE store_times
	    SET updated = :cycle
	    ,   changed = :now
	    WHERE store = :store
	}
	Size $store
    } else {
	m db eval {
	    UPDATE store_times
	    SET updated = :cycle
	    WHERE store = :store
	}
    }
    return [linsert $counts end $remotes]
}

proc ::m::store::move {store msetnew} {
    debug.m/store {}
    # copy of `m mset name` - outline? check for dependency circles
    set newname [MSName $msetnew]
    set vcs     [VCS $store]
    m db eval {
	UPDATE store
	SET    mset = :msetnew
	WHERE  id   = :store
    }

    m vcs rename $store $newname
    return
}

proc ::m::store::rename {store newname} {
    debug.m/store {}
    m vcs rename $store $newname
    return
}

proc ::m::store::check {storea storeb} {
    debug.m/store {}
    debug.m/store {}
    return [m vcs check [VCS $storea] $storea $storeb]
}

proc ::m::store::has {vcs mset} {
    debug.m/store {}
    return [m db onecolumn {
	SELECT count (*)
	FROM   store
	WHERE  vcs  = :vcs
	AND    mset = :mset
    }]
}

proc ::m::store::id {vcs mset} {
    debug.m/store {}
    return [m db onecolumn {
	SELECT id
	FROM   store
	WHERE  vcs  = :vcs
	AND    mset = :mset
    }]
}

proc ::m::store::get {store} {
    debug.m/store {}
    m db eval {
	SELECT 'size'    , S.size_kb
	,      'mset'    , S.mset
	,      'vcs'     , S.vcs
	,      'vcsname' , V.name
	,      'updated' , T.updated
	,      'changed' , T.changed
	,      'created' , T.created
	,      'attend'  , T.attend
	,      'remote'  , (SELECT count (*)
		FROM  repository R
		WHERE R.mset = S.mset
		AND   R.vcs  = S.vcs) AS remote
	,      'active'  , (SELECT count (*)
		FROM  repository R
		WHERE R.mset = S.mset
		AND   R.vcs  = S.vcs
		AND   R.active) AS active
	FROM   store                  S
	,      store_times            T
	,      version_control_system V
	WHERE S.id    = :store
	AND   T.store = S.id
	AND   V.id    = S.vcs
    }
}

proc ::m::store::remotes {store} {
    debug.m/store {}
    set vcs [VCS $store]
    lappend r [Remotes            $store] ;# Database
    lappend r [m vcs remotes $vcs $store] ;# Plugin supplied
    return $r
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

proc ::m::store::count {} {
    debug.m/store {}
    return [m db onecolumn {
	SELECT count (*)
	FROM store
    }]
}
proc ::m::store::search {substring} {
    debug.m/store {}

    set sub [string tolower $substring]
    set series {}
    m db eval {
	SELECT S.id      AS store
	,      N.name    AS mname
	,      V.code    AS vcode
	,      T.changed AS changed
	,      T.updated AS updated
	,      T.created AS created
	,      T.attend  AS attend
	,      S.size_kb AS size
	,      (SELECT count (*)
		FROM  repository R
		WHERE R.mset = S.mset
		AND   R.vcs  = S.vcs) AS remote
	,      (SELECT count (*)
		FROM  repository R
		WHERE R.mset = S.mset
		AND   R.vcs  = S.vcs
		AND   R.active) AS active
	FROM store_times            T
	,    store                  S
	,    mirror_set             M
	,    version_control_system V
	,    name                   N
	WHERE T.store   = S.id
	AND   S.mset    = M.id
	AND   S.vcs     = V.id
	AND   M.name    = N.id
	ORDER BY mname ASC, vcode ASC, size ASC
    } {
	if {
	    [string first $sub [string tolower $mname]] < 0
	} continue
	Srow series ;# upvar column variables
    }
    return $series
}

proc ::m::store::issues {} {
    debug.m/store {}

    set series {}
    set last {}
    m db eval {
	SELECT S.id      AS store
	,      N.name    AS mname
	,      V.code    AS vcode
	,      T.changed AS changed
	,      T.updated AS updated
	,      T.created AS created
	,      T.attend  AS attend
	,      S.size_kb AS size
	,      (SELECT count (*)
		FROM  repository R
		WHERE R.mset = S.mset
		AND   R.vcs  = S.vcs) AS remote
	,      (SELECT count (*)
		FROM  repository R
		WHERE R.mset = S.mset
		AND   R.vcs  = S.vcs
		AND   R.active) AS active
	FROM store_times            T
	,    store                  S
	,    mirror_set             M
	,    version_control_system V
	,    name                   N
	WHERE T.store   = S.id
	AND   T.attend  = 1    -- Flag for "has issues"
	AND   active    > 0    -- Flag for "not completely disabled"
	AND   S.mset    = M.id
	AND   S.vcs     = V.id
	AND   M.name    = N.id
	ORDER BY mname ASC, vcode ASC, size ASC
    } {
	Srow series ;# upvar column variables
    }
    return $series
}

proc ::m::store::disabled {} {
    debug.m/store {}

    set series {}
    set last {}
    m db eval {
	SELECT S.id      AS store
	,      N.name    AS mname
	,      V.code    AS vcode
	,      T.changed AS changed
	,      T.updated AS updated
	,      T.created AS created
	,      T.attend  AS attend
	,      S.size_kb AS size
	,      1         AS remote
	,      0         AS active
	,      R.id      AS rid
	,      R.url     AS url
	FROM store_times            T
	,    store                  S
	,    mirror_set             M
	,    version_control_system V
	,    name                   N
	,    repository             R
	WHERE T.store   = S.id
	AND   R.active  = 0    -- Flag for disabled
	AND   S.mset    = M.id
	AND   S.vcs     = V.id
	AND   M.name    = N.id
	AND   R.mset    = S.mset
	AND   R.vcs     = S.vcs
	ORDER BY mname ASC, vcode ASC, size ASC
    } {
	Srow series ;# upvar column variables
    }
    return $series
}

proc ::m::store::by-name {} {
    debug.m/store {}

    set series {}
    set last {}
    m db eval {
	SELECT S.id      AS store
	,      N.name    AS mname
	,      V.code    AS vcode
	,      T.changed AS changed
	,      T.updated AS updated
	,      T.created AS created
	,      T.attend  AS attend
	,      S.size_kb AS size
	,      (SELECT count (*)
		FROM  repository R
		WHERE R.mset = S.mset
		AND   R.vcs  = S.vcs) AS remote
	,      (SELECT count (*)
		FROM  repository R
		WHERE R.mset = S.mset
		AND   R.vcs  = S.vcs
		AND   R.active) AS active
	FROM store_times            T
	,    store                  S
	,    mirror_set             M
	,    version_control_system V
	,    name                   N
	WHERE T.store   = S.id
	AND   S.mset    = M.id
	AND   S.vcs     = V.id
	AND   M.name    = N.id
	ORDER BY mname ASC, vcode ASC, size ASC
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

proc ::m::store::by-vcs {} {
    debug.m/store {}

    set series {}
    m db eval {
	SELECT S.id      AS store
	,      N.name    AS mname
	,      V.code    AS vcode
	,      T.changed AS changed
	,      T.updated AS updated
	,      T.created AS created
	,      T.attend  AS attend
	,      S.size_kb AS size
	,      (SELECT count (*)
		FROM  repository R
		WHERE R.mset = S.mset
		AND   R.vcs  = S.vcs) AS remote
	,      (SELECT count (*)
		FROM  repository R
		WHERE R.mset = S.mset
		AND   R.vcs  = S.vcs
		AND   R.active) AS active
	FROM store_times            T
	,    store                  S
	,    mirror_set             M
	,    version_control_system V
	,    name                   N
	WHERE T.store   = S.id
	AND   S.mset    = M.id
	AND   S.vcs     = V.id
	AND   M.name    = N.id
	ORDER BY vcode ASC, mname ASC, size ASC
    } {
	Srow series
    }
    return $series
}

proc ::m::store::by-size {} {
    debug.m/store {}

    set series {}
    m db eval {
	SELECT S.id      AS store
	,      N.name    AS mname
	,      V.code    AS vcode
	,      T.changed AS changed
	,      T.updated AS updated
	,      T.created AS created
	,      T.attend  AS attend
	,      S.size_kb AS size
	,      (SELECT count (*)
		FROM  repository R
		WHERE R.mset = S.mset
		AND   R.vcs  = S.vcs) AS remote
	,      (SELECT count (*)
		FROM  repository R
		WHERE R.mset = S.mset
		AND   R.vcs  = S.vcs
		AND   R.active) AS active
	FROM store_times            T
	,    store                  S
	,    mirror_set             M
	,    version_control_system V
	,    name                   N
	WHERE T.store   = S.id
	AND   S.mset    = M.id
	AND   S.vcs     = V.id
	AND   M.name    = N.id
	ORDER BY size DESC, mname ASC, vcode ASC
    } {
	Srow series
    }
    return $series
}

proc ::m::store::updates {} {
    debug.m/store {}

    # From the db.tcl notes on store_times
    #
    # 1. created <= changed <= updated
    # 2. (created == changed) -> never changed.

    set series {}

    # Block 1: Changed stores, changed order descending
    # Insert separators when `updated` changes.
    set last {}
    m db eval {
	SELECT S.id      AS store
	,      N.name    AS mname
	,      V.code    AS vcode
	,      T.changed AS changed
	,      T.updated AS updated
	,      T.created AS created
	,      T.attend  AS attend
	,      S.size_kb AS size
	,      (SELECT count (*)
		FROM  repository R
		WHERE R.mset = S.mset
		AND   R.vcs  = S.vcs) AS remote
	,      (SELECT count (*)
		FROM  repository R
		WHERE R.mset = S.mset
		AND   R.vcs  = S.vcs
		AND   R.active) AS active
	FROM store_times            T
	,    store                  S
	,    mirror_set             M
	,    version_control_system V
	,    name                   N
	WHERE T.store   = S.id
	AND   S.mset    = M.id
	AND   S.vcs     = V.id
	AND   M.name    = N.id
	AND   T.created != T.changed
	ORDER BY T.changed DESC
    } {
	if {($last ne {}) && ($last != $updated)} {
	    Sep series
	}
	Srow series
	set last $updated
    }

    set first [llength $series]

    # Block 2: All unchanged stores, creation order descending,
    # i.e. last created top/first.
    m db eval {
	SELECT S.id      AS store
	,      N.name    AS mname
	,      V.code    AS vcode
	,      T.changed AS changed
	,      T.updated AS updated
	,      T.created AS created
	,      T.attend  AS attend
	,      S.size_kb AS size
	,      (SELECT count (*)
		FROM  repository R
		WHERE R.mset = S.mset
		AND   R.vcs  = S.vcs) AS remote
	,      (SELECT count (*)
		FROM  repository R
		WHERE R.mset = S.mset
		AND   R.vcs  = S.vcs
		AND   R.active) AS active
	FROM store_times            T
	,    store                  S
	,    mirror_set             M
	,    version_control_system V
	,    name                   N
	WHERE T.store   = S.id
	AND   S.mset    = M.id
	AND   S.vcs     = V.id
	AND   M.name    = N.id
	AND   T.created = T.changed
	ORDER BY T.created DESC
    } {
	if {$first} { Sep series }
	set changed {}
	set updated {}
	Srow series
	set first 0
    }

    return $series
}

proc ::m::store::move-location {newpath} {
    debug.m/store {}
    m vcs move $newpath
    return
}

# # ## ### ##### ######## ############# ######################

proc ::m::store::Srow {sv} {
    debug.m/store {}
    upvar 1 $sv series store store mname mname vcode vcode \
	changed changed updated updated created created \
	size size active active remote remote attend attend \
	rid rid url url

    debug.m/store {s=$store, m=$mname, v=$vcode, ch=$changed, up=$updated, cr=$created, sz=$size, r=$remote/$active, trouble=$attend}
    
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
		attend  $attend]
    if {[info exists rid]} { dict set row rid $rid }
    if {[info exists url]} { dict set row url $url }
    lappend series $row
    return
}

proc ::m::store::Sep {sv} {
    debug.m/store {}
    upvar 1 $sv series
    lappend series {
	store   . mname   . vcode . changed .
	updated . created . size  . active  .
	remote  . attend .  rid   . url     .
    }
    return
}

proc ::m::store::Remotes {store} {
    debug.m/store {}
    return [m db eval {
	SELECT R.url
	FROM   repository R
	,      store      S
	WHERE S.id   = :store
	AND   R.vcs  = S.vcs
	AND   R.mset = S.mset
    }]
}

proc ::m::store::Size {store} {
    debug.m/store {}

    set kb [m vcs size $store]
    m db eval {
	UPDATE store
	SET    size_kb = :kb
	WHERE  id      = :store
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

proc ::m::store::Add {vcs mset} {
    debug.m/store {}
    m db eval {
	INSERT
	INTO   store
	VALUES ( NULL, :vcs, :mset, 0 )
    }

    set store [m db last_insert_rowid]
    set now   [clock seconds]

    m db eval {
	INSERT
	INTO   store_times
	VALUES ( :store -- ^store
	,	 :now   -- created
	,	 :now   -- updated
	,	 :now   -- changed
	,	 0      -- attend
	)
    }
    return $store
}

proc ::m::store::VCS {store} {
    debug.m/store {}
    return [m db onecolumn {
	SELECT vcs
	FROM   store
	WHERE  id = :store
    }]
}

proc ::m::store::MSName {mset} {
    debug.m/store {}
    return [m db onecolumn {
	SELECT N.name
	FROM   mirror_set M
	,      name       N
	WHERE  M.id   = :mset
	AND    M.name = N.id
    }]
}

proc ::m::store::InitialSizes {} {
    debug.m/store {}
    m db eval {
	SELECT id
	FROM   store
    } {
	Size $id
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

# # ## ### ##### ######## ############# ######################
package provide m::store 0
return
