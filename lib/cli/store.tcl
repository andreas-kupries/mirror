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

# # ## ### ##### ######## ############# ######################

package require Tcl 8.5
package require debug
package require debug::caller

# # ## ### ##### ######## ############# ######################

namespace eval ::m {
    namespace export store
    namespace ensemble create
}
namespace eval ::m::store {
    namespace export add has id path remove
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################

debug level  m/store
debug prefix m/store {[debug caller] | }

# # ## ### ##### ######## ############# ######################

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

proc ::m::store::path {store} {
    debug.m/store {}
    return [m db onecolumn {
	SELECT path
	FROM   store
	WHERE  id = :store
    }]
}

proc ::m::store::add {vcs mset path} {
    debug.m/store {}
    m db eval {
	INSERT
	INTO   store
	VALUES ( NULL, :path, :vcs, :mset )
    }

    set store [m db last_insert_rowid]
    set now   [clock seconds]

    m db eval {
	INSERT
	INTO   store_times
	VALUES ( :store, :now, :now )
    }

    return $store
}

proc ::m::store::remove {store} {
    debug.m/store {}
    m db eval {
	DELETE
	FROM  store_times
	WHERE store = :store
	;
	DELETE
	FROM  store
	WHERE id = :store
    }
    return   
}

# # ## ### ##### ######## ############# ######################
package provide m::store 0
return
