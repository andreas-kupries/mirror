## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package m::reply 0
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
package require debug
package require debug::caller

# # ## ### ##### ######## ############# ######################

namespace eval ::m {
    namespace export reply
    namespace ensemble create
}
namespace eval ::m::reply {
    namespace export \
	list add remove change has known get \
	default default? default!

    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################

debug level  m/reply
debug prefix m/reply {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::m::reply::known {} {
    debug.m/reply {}

    # Return map to reply ids.
    # Keys:
    # - reply names

    set map {}

    m db eval {
	SELECT id
	,      name
	FROM   reply
    } {
	dict set map [string tolower $name] $id
    }

    return $map
}

proc ::m::reply::list {} {
    debug.m/reply {}

    return [m db eval {
	SELECT name
	,      isdefault
	,      automail
	,      text
	FROM   reply
	ORDER BY name ASC
    }]
}

proc ::m::reply::add {name automail text} {
    debug.m/reply {}

    m db eval {
	INSERT INTO reply
	VALUES ( NULL, :name, :automail, 0, :text )
    }

    return [m db last_insert_rowid]
}

proc ::m::reply::remove {reply} {
    debug.m/reply {}

    return [m db eval {
	DELETE
	FROM  reply
	WHERE id = :reply
    }]    
}

proc ::m::reply::change {reply text} {
    debug.m/reply {}
    m db eval {
	UPDATE reply
	SET    text = :text
	WHERE  id = :reply
    }
    return
}

proc ::m::reply::default {} {
    debug.m/reply {}
    return [m db onecolumn {
	SELECT id
	FROM   reply
	WHERE  isdefault = 1
    }]
}

proc ::m::reply::default! {reply} {
    debug.m/reply {}
    m db eval {
	UPDATE reply
	SET    isdefault = 0
	;
	UPDATE reply
	SET    isdefault = 1
	WHERE  id = :reply
    }
    return
}

proc ::m::reply::default? {reply} {
    debug.m/reply {}
    return [m db onecolumn {
	SELECT isdefault
	FROM   reply
	WHERE  id = :reply
    }]
}

proc ::m::reply::get {reply} {
    debug.m/reply {}
    return [m db eval {
	SELECT 'text', text
	,      'mail', automail
	FROM   reply
	WHERE  id = :reply
    }]
}

proc ::m::reply::has {name} {
    debug.m/reply {}
    return [m db onecolumn {
	SELECT count (*)
	FROM   reply
	WHERE  name = :name
    }]
}

# # ## ### ##### ######## ############# ######################
package provide m::reply 0
return
