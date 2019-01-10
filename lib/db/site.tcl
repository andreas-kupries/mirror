## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## Mirror database II - core access and schema for site database

# @@ Meta Begin
# Package m::site 0
# Meta author   {Andreas Kupries}
# Meta location https://core.tcl.tk/akupries/????
# Meta platform tcl
# Meta summary     Site database access and schema
# Meta description Site database access and schema
# Meta subject    {database access} schema site
# Meta require {Tcl 8.5-}
# @@ Meta End

package provide m::site 0

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require m::db::location 0
package require db::setup 0
package require sqlite3
package require debug
package require debug::caller

# # ## ### ##### ######## ############# ######################

debug level  m/db
debug prefix m/db {}

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval ::m {
    namespace export site
    namespace ensemble create
}

namespace eval ::m::site {
    namespace import ::db::setup::*
    variable wait 0
}

# Database accessor command - auto open & initialize database on first
# use TODO: Capture lock errors and re-try a few times, with backoff.

proc ::m::site {args} {
    debug.m/db {Setup}
    variable site::wait
    # On first use replace this initializer placeholder with the
    # actual database command.
    rename     ::m::site ::m::site_setup
    sqlite3    ::m::site [db::location get].site

    if {$wait > 0} {
	debug.m/db {Wait $wait millis}
	::m::site timeout $wait
    }
    
    # Initialize it.
    ::db setup ::m::site ::m::site::SETUP
    
    # Under narrative tracing intercept sql commands.
    debug.m/db {Intercept[rename ::m::site ::m::sitex][proc ::m::site {args} {
	debug.m/db {}
	#puts <<<[info level 0]>>>
	uplevel 1 [list ::m::sitex {*}$args]
    }]}

    # Re-execute the call using the proper definition.
    uplevel 1 [list ::m::site {*}$args]
}

proc ::m::site::wait {seconds} {
    debug.m/db {}
    variable wait [expr {$seconds * 1000}]
    return
}

proc ::m::site::reset {} {
    debug.m/db {}
    rename ::m::site {}
    rename ::m::site_setup ::m::site
    return
}

# # ## ### ##### ######## ############# #####################
## Migrations - database schema

## The site database is what the CGI helper applications have access to.

## As such it contains only tables and data needed by the helpers for
## their operation, and nothing else. This also implies that the schema
## can be simplified.

## I. Search results
##    - mirror set name		Shown, searched
#     - list of remotes		Hidden, searched
##    - vcs code
##    - link to store detail page
##    - name of status icon, if any
##    - store size
##    - last time changed
##    - last time checked
##    - time created
#
## II. Submissions
##    - id
##    - session id
##    - url
##    - vcode
##    - description
##    - email
##    - submitter
##    - when_submitted
#
##     Submission sync
##    - Id X of last submission pulled into main
##      site.id >  X is new
##      site.id <= X is known; can be removed if not in main (anymore).
#
## III. Rejections
##    - rejected url
##    - reason for rejection

proc ::m::site::SETUP-201811302300 {} {
    debug.m/db {}
    # Initial setup. Create the basic site tables.

    D m::site
    # - -- --- ----- -------- -------------
    # Search. Pushed from main.
    I+
    C name     TEXT     NOT NULL
    C vcode    TEXT     NOT NULL
    C page     TEXT     NOT NULL  UNIQUE
    C remotes  TEXT     NOT NULL
    C status   TEXT     NOT NULL -- icon name
    C size_kb  INTEGER  NOT NULL
    C changed  INTEGER  NOT NULL
    C updated  INTEGER  NOT NULL
    C created  INTEGER  NOT NULL
    U name vcode
    T store_index
    X name
    X remotes

    # - -- --- ----- -------- -------------
    # Rejections. Pushed from main.
    I+
    C url    TEXT NOT NULL UNIQUE
    C reason TEXT NOT NULL
    T rejected
    
    # - -- --- ----- -------- -------------
    # Submissions. Push to main, delete from main
    I+
    C session         TEXT NOT NULL
    C url             TEXT NOT NULL UNIQUE
    C vcode           TEXT
    C description     TEXT
    C email           TEXT NOT NULL
    C submitter       TEXT
    C when_submitted  INTEGER NOT NULL
    U session url
    T submission
    X when_submitted
    X url

    # - -- --- ----- -------- -------------
    # Sync state
    C lastid  INTEGER NOT NULL PRIMARY KEY
    T sync

    return
}

proc ::m::site::SETUP-201812032300 {} {
    debug.m/db {}
    # Extend site schema with caches for url validity and description generation

    D m::site
    # - -- --- ----- -------- -------------
    # Map urls to validity and resolution (if valid)
    # Marked with an expiry time.
    C expiry    INTEGER  NOT NULL -- expiry timestamp
    C url       TEXT     NOT NULL UNIQUE
    C ok        INTEGER  NOT NULL
    C resolved  TEXT     NOT NULL
    T cache_url
    X expiry

    # - -- --- ----- -------- -------------
    # Map urls to generated description
    # Marked with an expiry time.
    C expiry    INTEGER  NOT NULL -- expiry timestamp
    C url       TEXT     NOT NULL UNIQUE
    C desc      TEXT     NOT NULL
    T cache_desc
    X expiry

    return
}

proc ::m::site::SETUP-201812040100 {} {
    debug.m/db {}
    # Fix submission table primary key

    D m::site
    # - -- --- ----- -------- -------------
    # url is not unique, only url + session
    I+
    C session         TEXT NOT NULL
    C url             TEXT NOT NULL
    C vcode           TEXT
    C description     TEXT
    C email           TEXT NOT NULL
    C submitter       TEXT
    C when_submitted  INTEGER NOT NULL
    U session url
    < submission  \
	id session url vcode description email submitter when_submitted
    X when_submitted
    X url

    return
}

proc ::m::site::SETUP-201812041400 {} {
    debug.m/db {}
    # Drop table `sync`, not used

    D m::site
    / sync
    
    return
}

proc ::m::site::SETUP-201901092300 {} {
    debug.m/db {}
    # Add table for vcs codes.

    D m::site
    I+
    C code  TEXT  NOT NULL  UNIQUE ; # Short semi-internal tag
    C name  TEXT  NOT NULL  UNIQUE ; # Human readable name
    T vcs

    # No fixed values here. Copy from main table
    # `version_control_system` on sync.
    
    return
}

# # ## ### ##### ######## ############# #####################
return
