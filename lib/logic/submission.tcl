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
	all add has has^ dup accept reject get known rejected drop rejected-url rejected-known

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
	dict set map %c                            $id
    }

    return $map
}

proc ::m::submission::all {} {
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

proc ::m::submission::rejected-known {} {
    debug.m/submission {}

    set map {}
    m db eval {
	SELECT id
	,      url
	FROM   rejected
    } {
	dict set map [string tolower $url] $id
    }
    return $map
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

proc ::m::submission::add {url session vcode desc email submitter} {
    debug.m/submission {}
    
    set now [clock seconds]

    if {[has^ $url $session]} {
	# Submission exists, for this session => Update/Replace
	m db eval {
	    UPDATE submission
	    SET vcode       = :vcode
	    ,   description = :desc
	    ,   email       = :email
	    ,   submitter   = :submitter
	    ,   sdate       = :now
	    WHERE url     = :url
	    AND   session = :session
	}
    } else {
	# New submission, first for the session => Insert/Add
	m db eval {
	    INSERT
	    INTO submission
	    VALUES ( NULL, :session, :url, :vcode, :desc, :email, :submitter, :now )
	}
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

proc ::m::submission::has^ {url session} {
    debug.m/submission {}

    return [m db onecolumn {
	SELECT count (*)
	FROM  submission
	WHERE url     = :url
	AND   session = :session
    }]    
}

proc ::m::submission::dup {url} {
    debug.m/submission {}
    return [m db onecolumn {
	SELECT reason
	FROM   rejected
	WHERE  url = :url
    }]
}
proc ::m::submission::rejected-url {id} {
    debug.m/submission {}

    return [m db eval {
	SELECT url
	FROM   rejected
	WHERE id = :id
    }]
}

proc ::m::submission::drop {rejection} {
    debug.m/submission {}
    
    m db eval {
	DELETE
	FROM rejected
	WHERE id = :rejection
    }
    
    return
}

proc ::m::submission::accept {submission} {
    debug.m/submission {}
    set url [m db onecolumn {
	SELECT url
	FROM  submission
	WHERE id = :submission
    }]
    m db eval {
	-- Phase I. Copy key information of the processed submission
	--          and duplicates into the sync helper table
	INSERT
	INTO   submission_handled
	SELECT session
	,      url
	FROM   submission
	WHERE  url = :url
	;
	--
	-- Phase II. Remove processed submission from the main table
	--
	DELETE
	FROM submission
	WHERE url = :url
    }
    return
}

proc ::m::submission::reject {submission reason} {
    debug.m/submission {}
    set url [m db onecolumn {
	SELECT url
	FROM  submission
	WHERE id = :submission
    }]
    m db eval {
	-- Phase I. Copy key information of processed submission
	--          and duplicates into the sync helper table
	INSERT
	INTO   submission_handled
	SELECT session
	,      url
	FROM   submission
	WHERE  url = :url
	;
	--
	-- Phase II. Add rejection information to the associated table
	--
	INSERT OR REPLACE
	INTO rejected
	VALUES ( NULL, :url, :reason )
	;
	--
	-- Phase III. Remove processed submission from the main table,
	--            as well as duplicates (same url).
	--
	DELETE
	FROM  submission
	WHERE url = :url
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
