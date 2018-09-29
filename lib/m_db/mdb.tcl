
package require Tcl 8.5
package require m::db::location 0
package require db::setup 0
package require sqlite3

package provide m::db 0

namespace eval m {
    namespace export db
    namespace ensemble create
}
namespace eval m::db {
    namespace import ::db::setup::*
}

# Database accessor command - auto open & initialize database on first
# use TODO: Capture lock errors and re-try a few times, with backoff.
proc ::m::db {args} {
    # First use, replace this initializer placeholder with the actual
    # database command and initialize it.
    rename     ::m::db {}
    sqlite3    ::m::db [db::location get]
    ::db setup ::m::db ::m::db::SETUP
    # Re-execute using the new definition
    uplevel 1 [list ::m::db {*}$args]
}

# # ## ### ##### ######## ############# #####################
## Migrations 

proc ::m::db::SETUP-201809281600 {} {
    D m db
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

    # - -- --- ----- -------- -------------
    ## Store - Internal equivalent of a repository. Holder of backups
    
    I+
    C path  TEXT     NOT NULL  UNIQUE
    C vcs   INTEGER  NOT NULL  ^version_control_system
    C mset  INTEGER  NOT NULL  ^mirror_set
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

    > 'current-repository'  ''
    > 'previous-repository' ''
    > 'take'                ''
    > 'store'               '~/.mirror/store'
    > 'limit'               '20'
    > 'top'                 ''
    > 'rolodex-origin'      ''

    # - -- --- ----- -------- -------------
    ## Mirror Set Pending - List of repositories waiting for an update
    ##                      to process them
    
    I+
    C mset  INTEGER  NOT NULL  ^mirror_set
    T mset_pending
    
    # - -- --- ----- -------- -------------
    ## Store Times - Per store the times of last update and change
    
    I+
    C store    INTEGER  NOT NULL  ^store
    C updated  INTEGER  NOT NULL
    C changed  INTEGER  NOT NULL
    T store_times

    # - -- --- ----- -------- -------------
    ## Rolodex - Short hand references to recently seen repositories

    I+
    C repository INTEGER NOT NULL  ^repository  UNIQUE
    C tag        TEXT    NOT NULL               UNIQUE
    T rolodex

    # - -- --- ----- -------- -------------
    return
}

# # ## ### ##### ######## ############# #####################
return
