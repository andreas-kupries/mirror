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
package require debug
package require debug::caller

# # ## ### ##### ######## ############# ######################

namespace eval ::m {
    namespace export mset
    namespace ensemble create
}
namespace eval ::m::mset {
    namespace export \
	add remove rename has \
	name used-vcs has-vcs size \
	stores pending
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################

debug level  m/mset
debug prefix m/mset {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::m::mset::add {name} {
    debug.m/mset {}

    m db eval {
	INSERT INTO name VALUES ( NULL, :name )
    }

    set nid [m db last_insert_rowid]

    m db eval {
	INSERT INTO mirror_set VALUES ( NULL, :nid )
    }

    set mset [m db last_insert_rowid]
    
    m db eval {
	INSERT INTO mset_pending VALUES ( :mset )
    }

    return $mset
}

proc ::m::mset::remove {mset} {
    debug.m/mset {}

    # TODO FILL mset/remove -- Verify that the mset has no references
    # anymore, from neither repositories nor stores
    
    return [m db eval {
	DELETE
	FROM  name
	WHERE id IN ( SELECT name
		      FROM   mirror_set
		      WHERE  id = :mset )
	;
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
    return [m db eval {
	UPDATE name
	SET name = :name
	WHERE id IN ( SELECT name
		      FROM   mirror_set
		      WHERE  id = :mset )
    }]
}

proc ::m::mset::has {name} {
    debug.m/mset {}
    return [m db onecolumn {
	SELECT count (*)
	FROM   mirror_set M
	,      name       N
	WHERE  M.name = N.id
	AND    N.name = :name
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
	SELECT N.name
	FROM   mirror_set M
	,      name       N
	WHERE  M.id   = :mset
	AND    M.name = N.id
    }]
}

proc ::m::mset::pending {take} {
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
    } else {
	# Full read. Clear taken, the slow way.  Drop the unwanted
	# sentinel element from the end of the result.
	set taken [lreplace [K $taken [unset taken]] end end]
	m db eval [string map [list %% [join $token ,]] {
	    DELETE
	    FROM mset_pending
	    WHERE mset in (%%)
	}]
    }

    return $taken
}

# # ## ### ##### ######## ############# ######################
package provide m::mset 0
return
