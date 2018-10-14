## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## Mirror database - core access and schema

# @@ Meta Begin
# Package m::db 0
# Meta author   {Andreas Kupries}
# Meta location https://core.tcl.tk/akupries/????
# Meta platform tcl
# Meta summary     Database access and schema
# Meta description Database access and schema
# Meta subject    {database access} schema
# Meta require {Tcl 8.5-}
# @@ Meta End

package provide m::db 0

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
    namespace export db
    namespace ensemble create
}

namespace eval ::m::db {
    namespace import ::db::setup::*
}

# Database accessor command - auto open & initialize database on first
# use TODO: Capture lock errors and re-try a few times, with backoff.

proc ::m::db {args} {
    debug.m/db {Setup}
    # On first use replace this initializer placeholder with the
    # actual database command.
    rename     ::m::db {}
    sqlite3    ::m::db [db::location get]

    # Initialize it.
    ::db setup ::m::db ::m::db::SETUP

    # Under narrative tracing intercept sql commands.
    debug.m/db {Intercept[rename ::m::db ::m::dbx][proc ::m::db {args} {
	debug.m/db {}
	#puts <<<[info level 0]>>>
	uplevel 1 [list ::m::dbx {*}$args]
    }]}
    
    # Re-execute the call using the proper definition.
    uplevel 1 [list ::m::db {*}$args]
}

# # ## ### ##### ######## ############# #####################
## Migrations - database schema 

proc ::m::db::SETUP-201810051600 {} {
    debug.m/db {}
    # Initial setup. Create the basic tables.
    
    D m::db
    ## Content tables
    # - -- --- ----- -------- -------------
    ## Mirror Set Names - Future Hook into a Tcl Package Pedia
    
    I+
    C name  TEXT  NOT NULL  UNIQUE
    T name

    # - -- --- ----- -------- -------------
    ## Mirror Set - Group of repositories holding the same logical set
    ##              of files/content.
    
    I+
    C name  INTEGER  NOT NULL ^name UNIQUE
    T mirror_set

    # - -- --- ----- -------- -------------
    ## Repository - A set of versioned files to back up
    
    I+
    C url   TEXT     NOT NULL  UNIQUE
    C vcs   INTEGER  NOT NULL  ^version_control_system
    C mset  INTEGER  NOT NULL  ^mirror_set
    T repository
    X vcs mset

    # - -- --- ----- -------- -------------
    ## Store - Internal equivalent of a repository. Holder of backups
    ## Note: External path is implied in the row id.
    
    I+
    C vcs   INTEGER  NOT NULL  ^version_control_system
    C mset  INTEGER  NOT NULL  ^mirror_set
    U vcs mset
    T store

    # - -- --- ----- -------- -------------
    ## Version Control System - Applications able to manage
    ##                          repositories
    
    I+
    C code  TEXT  NOT NULL  UNIQUE ; # Short semi-internal tag
    C name  TEXT  NOT NULL  UNIQUE ; # Human readable name
    T version_control_system

    >+ 'fossil' 'Fossil'
    >+ 'git'    'Git'

    ## State tables
    # - -- --- ----- -------- -------------
    ## Client state - Named values
    
    C name   TEXT  NOT NULL  PRIMARY KEY
    C value  TEXT  NOT NULL
    T state

    > 'limit'               '20'              ;# Show this many repositories per `list`
    > 'store'               '~/.mirror/store' ;# Directory for the backend stores
    > 'take'                '5'               ;# Check this many mirrors sets per `update`
    > 'top'                 ''                ;# State for `list`, next repository to show.

    # - -- --- ----- -------- -------------
    ## Mirror Set Pending - List of repositories waiting for an update
    ##                      to process them
    
    C mset  INTEGER  NOT NULL  ^mirror_set  PRIMARY KEY
    T mset_pending
    
    # - -- --- ----- -------- -------------
    ## Store Times - Per store the times of last update and change
    #
    # Notes on the recorded times:
    #
    # - Invariant: changed <= updated
    #   Because not every update causes a change.
    
    C store    INTEGER  NOT NULL  ^store PRIMARY KEY
    C updated  INTEGER  NOT NULL
    C changed  INTEGER  NOT NULL
    T store_times
    
    # - -- --- ----- -------- -------------
    ## Rolodex - Short hand references to recently seen repositories

    I
    C repository INTEGER NOT NULL  ^repository  UNIQUE
    T rolodex

    # - -- --- ----- -------- -------------
    return
}

proc ::m::db::SETUP-201810092200 {} {
    # Added github VCS manager

    D m::db
    T^ version_control_system
    >+ 'github' 'GitHub'

    return
}

proc ::m::db::SETUP-201810111600 {} {
    # Added column `created` to `store_times`
    #
    # Notes on the recorded times:
    #
    # - Invariant: changed <= updated
    #   Because not every update causes a change.
    #
    # - Invariant: created <= changed
    #   Because a change can happen only after we have store
    #
    # - (created == changed)
    #   -> Never seen any change for this store.
    #
    # Overall
    #		created <= changed <= updated
    
    D m::db
    C store    INTEGER  NOT NULL  ^store PRIMARY KEY
    C created  INTEGER  NOT NULL
    C updated  INTEGER  NOT NULL
    C changed  INTEGER  NOT NULL
    < store_times  store updated updated changed
    #                    ^ use last update as fake creation
    return
}

proc ::m::db::SETUP-201810121600 {} {
    # Added mail configuration to the general state table
    
    set h {This is a semi-automated mail by @cmd@, on behalf of @sender@.}
    
    D m::db
    T^ state

    #                           -- Debugging
    > 'mail-debug'  '0'         ;# Bool. Activates low-level debugging in smtp/mime

    #                           -- SMTP configuration
    > 'mail-host'   'localhost' ;# Name of the mail-relay host to talk to
    > 'mail-port'   '25'        ;# Port where the mail-relay host accepts SMTP
    > 'mail-user'   'undefined' ;# account accepted by the mail-relay host
    > 'mail-pass'   ''          ;# and associated credentials
    > 'mail-tls'    '0'         ;# Bool. Activates TLS to secure SMTP transactions

    #                           -- Mail content configuration
    > 'mail-sender' 'undefined' ;# Email address to place into From/Sender headers
    > 'mail-header' '$h'        ;# Text to place before the generated content
    > 'mail-footer' ''          ;# Text to place after the generated content
    #                            # Note: Template processing happens after the content
    #                            # is assembled, i.e. affects header and footer.
    
    return
}

proc ::m::db::SETUP-201810131603 {} {
    # Add tables for rejection mail content
    # (submission processing)

    D m::db
    I+
    C name      TEXT    NOT NULL UNIQUE
    C automail  INTEGER NOT NULL
    C isdefault INTEGER NOT NULL
    C text      TEXT    NOT NULL
    T reply

    set sm "It is spam"
    set om "It is off-topic here"
    set rm "It was intentionally removed before and we will not add it again"
    
    >+ 'spam'     0 1 '$sm' ;# default reason
    >+ 'offtopic' 1 0 '$om'
    >+ 'removed'  1 0 '$rm'
}

# # ## ### ##### ######## ############# #####################
return
