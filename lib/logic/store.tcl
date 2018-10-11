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
	id vcs-name
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

    set vcs [VCS $store]
    m vcs split $vcs $store \
	[Add $vcs $msetnew ] \
	[MSName $msetnew]
    return
}

proc ::m::store::update {store now} {
    debug.m/store {}

    set vcs [VCS $store]

    # Get all repositories for this store (same VCS, same mirror set),
    # then feed everything to the vcs layer.

    set remotes [m db eval {
	SELECT R.url
	FROM repository R
	,    store      S
	WHERE S.id   = :store
	AND   R.vcs  = S.vcs
	AND   R.mset = S.mset
    }]
    
    set counts [m vcs update $store $vcs $remotes]
    lassign $counts before after

    if {$after != $before} {
	m db eval {
	    UPDATE store_times
	    SET updated = :now
	    ,   changed = :now
	    WHERE store = :store
	}
    } else {
	m db eval {
	    UPDATE store_times
	    SET updated = :now
	    WHERE store = :store
	}
    }
    return $counts
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

# # ## ### ##### ######## ############# ######################

proc ::m::store::Add {vcs mset} {
    debug.m/store {}
    m db eval {
	INSERT
	INTO   store
	VALUES ( NULL, :vcs, :mset )
    }

    set store [m db last_insert_rowid]
    set now   [clock seconds]

    m db eval {
	INSERT
	INTO   store_times
	VALUES ( :store, :now, :now, :now )
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

# # ## ### ##### ######## ############# ######################
package provide m::store 0
return
