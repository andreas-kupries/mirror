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
	name list-vcs has-vcs size
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

proc ::m::mset::list-vcs {mset} {
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

# # ## ### ##### ######## ############# ######################
package provide m::mset 0
return
