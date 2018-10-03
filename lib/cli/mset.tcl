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
    namespace export add has remove
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################

debug level  m/mset
debug prefix m/mset {[debug caller] | }

# # ## ### ##### ######## ############# ######################

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

# # ## ### ##### ######## ############# ######################
package provide m::mset 0
return
