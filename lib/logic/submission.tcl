## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package m::submission 0
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
    namespace export submission
    namespace ensemble create
}
namespace eval ::m::submission {
    namespace export \
	list add has dup accept reject get known rejected

    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################

debug level  m/submission
debug prefix m/submission {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::m::submission::known {} {
    debug.m/submission {}

    set map {}
    m db eval {
	SELECT id
	,      url
	,      email
	,      description
	FROM   submission
    } {
	dict set map %$id                          $id
	dict set map [string tolower $url]         $id
	dict set map [string tolower $email]       $id
	dict set map [string tolower $description] $id
    }

    return $map
}

proc ::m::submission::list {} {
    debug.m/submission {}

    return [m db eval {
	SELECT id
	,      sdate
	,      url
	,      vcode
	,      description
	,      email
	,      submitter
	FROM   submission
	ORDER BY sdate DESC, id DESC
    }]
}

proc ::m::submission::rejected {} {
    debug.m/submission {}

    return [m db eval {
	SELECT url
	,      reason
	FROM   rejected
	ORDER BY url ASC
    }]
}

proc ::m::submission::add {url vcode desc email submitter} {
    debug.m/submission {}
    
    set now [clock seconds]
    m db eval {
	INSERT INTO submission
	VALUES ( NULL, :url, :vcode, :desc, :email, :submitter, :now )
    }

    return [m db last_insert_rowid]
}

proc ::m::submission::has {url} {
    debug.m/submission {}

    return [m db onecolumn {
	SELECT count (*)
	FROM  submission
	WHERE url = :url
    }]    
}

proc ::m::submission::dup {url} {
    debug.m/submission {}
    m db eval {
	SELECT reason
	FROM   rejected
	WHERE  url = :url
    }
    return
}

proc ::m::submission::accept {submission} {
    debug.m/submission {}
    m db onecolumn {
	DELETE
	FROM submission
	WHERE id = :submission
    }
    return
}

proc ::m::submission::reject {submission reason} {
    debug.m/submission {}
    set url [m db onecolum {
	SELECT url
	FROM  submission
	WHERE id = :submission
    }]
    m db eval {
	INSERT INTO rejected
	VALUES ( NULL, :url, :reason )
	;
	DELETE
	FROM  submission
	WHERE id = :submission
    }
    return
}

proc ::m::submission::get {submission} {
    debug.m/submission {}
    set r [m db eval {
	SELECT 'url'        , url
	,      'vcode'      , vcode
	,      'desc'       , description
	,      'email'      , email
	,      'submitter'  , submitter
	,      'when'       , sdate
	FROM   submission
	WHERE  id = :submission
    }]
    debug.m/submission { --> (($r)) }
    return $r
}

# # ## ### ##### ######## ############# ######################
package provide m::submission 0
return
