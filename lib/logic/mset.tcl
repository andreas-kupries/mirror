## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package m::mset 0
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
package require m::db
package require m::repo
package require m::rolodex
package require debug
package require debug::caller

# # ## ### ##### ######## ############# ######################

namespace eval ::m {
    namespace export mset
    namespace ensemble create
}
namespace eval ::m::mset {
    namespace export \
	all add remove rename has \
	name used-vcs has-vcs size \
	stores take-pending pending known \
	repos spec id count count-pending
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################

debug level  m/mset
debug prefix m/mset {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::m::mset::spec {} {
    debug.m/mset {}

    set lines {}
    foreach {mset mname} [all] {
	foreach repo [repos $mset] {
	    set ri [m repo get $repo]
	    dict with ri {}
	    # -> url	: repo url
	    #    vcs	: vcs id
	    # -> vcode	: vcs code
	    #    mset	: mirror set id
	    #    name	: mirror set name
	    #    store  : store id, of backing store for
	    lappend lines [list R $vcode $url]
	}
	lappend lines [list M $mname]
    }
    return [join $lines \n]
}

proc ::m::mset::known {} {
    debug.m/mset {}

    # Return map to mirror set ids.
    # Keys:
    # - rolodex ids (+ '@current', '@', '@prev')
    # - repository urls
    # - mirror set names

    set map {}
    set mid {}

    # Repository and mirror set information in one trip.
    m db eval {
	SELECT M.id   AS id
	,      M.name AS name
	,      R.id   AS rid
	,      R.url  AS url
	FROM   repository R
	,      mirror_set M
	WHERE  R.mset = M.id
    } {
	dict set mid $rid $id
	dict set map [string tolower $url]  $id
	dict set map [string tolower $name] $id
    }

    # See also m::repo::known
    # Note, different ids! mset, not repo.
    set c {}
    set p {}
    set id -1
    foreach r [m rolodex get] {
	set p $c ; set c $r ; incr id
	dict set map "@$id" [dict get $mid $r]
    }
    if {$p ne {}} {
	set p [dict get $mid $p]
	dict set map @prev $p
	dict set map @-1   $p
    }
    if {$c ne {}} {
	set c [dict get $mid $c]
	dict set map @current $c
	dict set map @        $c
    }

    return $map
}

proc ::m::mset::all {} {
    debug.m/mset {}
    return [m db eval {
	SELECT id
	,      name
	FROM   mirror_set
	ORDER BY name ASC
    }]
}

proc ::m::mset::id {name} {
    debug.m/mset {}
    return [m db onecolumn {
	SELECT id
	FROM   mirror_set
	WHERE  name = :name
    }]
}

proc ::m::mset::count {} {
    debug.m/mset {}
    return [m db onecolumn {
	SELECT count (*)
	FROM   mirror_set
    }]
}

proc ::m::mset::count-pending {} {
    debug.m/mset {}
    return [m db onecolumn {
	SELECT count (*)
	FROM   mset_pending
    }]
}

proc ::m::mset::add {name} {
    debug.m/mset {}

    m db eval {
	INSERT
	INTO mirror_set
	VALUES ( NULL, :name )
    }

    set mset [m db last_insert_rowid]

    m db eval {
	INSERT
	INTO mset_pending
	VALUES ( :mset )
    }

    return $mset
}

proc ::m::mset::remove {mset} {
    debug.m/mset {}

    # TODO FILL mset/remove -- Verify that the mset has no references
    # anymore, from neither repositories nor stores

    return [m db eval {
	DELETE
	FROM  mirror_set
	WHERE id = :mset
	;
	DELETE
	FROM  mset_pending
	WHERE mset = :mset
    }]
}

proc ::m::mset::rename {mset name} {
    debug.m/mset {}
    m db eval {
	UPDATE mirror_set
	SET    name = :name
	WHERE  id   = :mset
    }
    return
}

proc ::m::mset::has {name} {
    debug.m/mset {}
    return [m db onecolumn {
	SELECT count (*)
	FROM   mirror_set
	WHERE  name = :name
    }]
}

proc ::m::mset::stores {mset} {
    debug.m/mset {}
    return [m db eval {
	SELECT id
	FROM   store
	WHERE  mset = :mset
    }]
}

proc ::m::mset::repos {mset} {
    debug.m/mset {}
    return [m db eval {
	SELECT id
	FROM   repository
	WHERE  mset = :mset
    }]
}

proc ::m::mset::used-vcs {mset} {
    debug.m/mset {}
    return [m db eval {
	SELECT DISTINCT vcs
	FROM   repository
	WHERE  mset = :mset
    }]
}

proc ::m::mset::size {mset} {
    debug.m/mset {}
    return [m db onecolumn {
	SELECT count (*)
	FROM   repository
	WHERE  mset = :mset
    }]
}

proc ::m::mset::has-vcs {mset vcs} {
    debug.m/mset {}
    return [m db onecolumn {
	SELECT count (*)
	FROM   repository
	WHERE  mset = :mset
	AND    vcs  = :vcs
    }]
}

proc ::m::mset::name {mset} {
    debug.m/mset {}
    return [m db onecolumn {
	SELECT name
	FROM   mirror_set
	WHERE  id = :mset
    }]
}

proc ::m::mset::pending {} {
    debug.m/mset {}
    return [m db eval {
	SELECT name
	,      (SELECT count (*)
		FROM  repository R
		WHERE R.mset = P.mset
		AND   R.active) AS arc
	FROM   mset_pending P
	,      mirror_set   M
	WHERE P.mset = M.id
	AND   arc > 0
	ORDER BY P.ROWID
    }]
}

proc ::m::mset::take-pending {take args} {
    debug.m/mset {}

    # Ask for one more than actually request. This will cause a
    # short-read (with refill) not only when the table contains less
    # than take elements, but also when it contains exactly that many.
    # If the read is not short we know that at least one element is
    # left.
    incr take

    set taken [m db eval {
	SELECT P.mset
	FROM   mset_pending P
	WHERE (SELECT count (*)
	       FROM  repository R
	       WHERE R.mset = P.mset
	       AND   R.active) > 0
	LIMIT :take
    }]
    if {[llength $taken] < $take} {
	# Short read. Clear taken (fast), and refill for next
	# invokation.
	m db eval {
	    DELETE
	    FROM   mset_pending
	    ;
	    INSERT
	    INTO   mset_pending
	    SELECT id
	    FROM   mirror_set
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
	    FROM mset_pending
	    WHERE mset in (%%)
	}]
    }

    return $taken
}

# # ## ### ##### ######## ############# ######################

proc ::m::mset::K {x y} { set x }

# # ## ### ##### ######## ############# ######################
package provide m::mset 0
return
