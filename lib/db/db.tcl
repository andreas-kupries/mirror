## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## Mirror database - core access and schema

# @@ Meta Begin
# Package m::db 0
# Meta author	{Andreas Kupries}
# Meta location https://core.tcl.tk/akupries/????
# Meta platform tcl
# Meta summary	   Main database access and schema
# Meta description Main database access and schema
# Meta subject	  {database access} schema main
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
    variable wait 0
}

# Database accessor command - auto open & initialize database on first
# use TODO: Capture lock errors and re-try a few times, with backoff.

proc ::m::db {args} {
    debug.m/db {Setup}
    variable db::wait
    # On first use replace this initializer placeholder with the
    # actual database command.
    rename     ::m::db ::m::db_setup
    sqlite3    ::m::db [db::location get]

    if {$wait > 0} {
	debug.m/db {Wait $wait millis}
	::m::db timeout $wait
    }

    # Initialize it.
    ::db setup ::m::db ::m::db::SETUP

    # Under narrative tracing intercept sql commands.
    debug.m/db {Intercept[rename ::m::db ::m::dbx][proc ::m::db {args} {
	debug.m/db {}
	puts <<<[info level 0]>>>
	uplevel 1 [list ::m::dbx {*}$args]
    }]}

    # Re-execute the call using the proper definition.
    uplevel 1 [list ::m::db {*}$args]
}

proc ::m::db::wait {seconds} {
    debug.m/db {}
    variable wait [expr {$seconds * 1000}]
    return
}

proc ::m::db::reset {} {
    debug.m/db {}
    rename ::m::db {}
    rename ::m::db_setup ::m::db
    return
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
    ##		    of files/content.

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
    ##				repositories

    I+
    C code  TEXT  NOT NULL  UNIQUE ; # Short semi-internal tag
    C name  TEXT  NOT NULL  UNIQUE ; # Human readable name
    T version_control_system

    >+ 'fossil' 'Fossil'
    >+ 'git'	'Git'

    ## State tables
    # - -- --- ----- -------- -------------
    ## Client state - Named values

    C name   TEXT  NOT NULL  PRIMARY KEY
    C value  TEXT  NOT NULL
    T state

    > 'limit'		    '20'	      ;# Show this many repositories per `list`
    > 'store'		    '~/.mirror/store' ;# Directory for the backend stores
    > 'take'		    '5'		      ;# Check this many mirrors sets per `update`
    > 'top'		    ''		      ;# State for `list`, next repository to show.

    # - -- --- ----- -------- -------------
    ## Mirror Set Pending - List of repositories waiting for an update
    ##			    to process them

    C mset  INTEGER  NOT NULL  ^mirror_set  PRIMARY KEY
    T mset_pending

    # - -- --- ----- -------- -------------
    ## Store Times - Per store the times of last update and change
    #
    # Notes on the recorded times:
    #
    # - Invariant: changed <= updated
    #	Because not every update causes a change.

    C store    INTEGER	NOT NULL  ^store PRIMARY KEY
    C updated  INTEGER	NOT NULL
    C changed  INTEGER	NOT NULL
    T store_times

    # - -- --- ----- -------- -------------
    ## Rolodex - Short hand references to recently seen repositories

    I
    C repository INTEGER NOT NULL  ^repository	UNIQUE
    T rolodex

    # - -- --- ----- -------- -------------
    return
}

proc ::m::db::SETUP-201810092200 {} {
    debug.m/db {}
    # Added github VCS manager

    D m::db
    # - -- --- ----- -------- -------------
    T^ version_control_system
    >+ 'github' 'GitHub'

    return
}

proc ::m::db::SETUP-201810111600 {} {
    debug.m/db {}
    # Added column `created` to `store_times`
    #
    # Notes on the recorded times:
    #
    # - Invariant: changed <= updated
    #	Because not every update causes a change.
    #
    # - Invariant: created <= changed
    #	Because a change can happen only after we have store
    #
    # - (created == changed)
    #	-> Never seen any change for this store.
    #
    # Overall
    #		created <= changed <= updated

    D m::db
    # - -- --- ----- -------- -------------
    C store    INTEGER	NOT NULL  ^store PRIMARY KEY
    C created  INTEGER	NOT NULL
    C updated  INTEGER	NOT NULL
    C changed  INTEGER	NOT NULL
    < store_times  store updated updated changed
    #			 ^ use last update as fake creation

    return
}

proc ::m::db::SETUP-201810121600 {} {
    debug.m/db {}
    # Added mail configuration to the general state table

    set h {This is a semi-automated mail by @cmd@, on behalf of @sender@.}

    D m::db
    # - -- --- ----- -------- -------------
    T^ state
    #				-- Debugging
    > 'mail-debug'  '0'		;# Bool. Activates low-level debugging in smtp/mime

    #				-- SMTP configuration
    > 'mail-host'   'localhost' ;# Name of the mail-relay host to talk to
    > 'mail-port'   '25'	;# Port where the mail-relay host accepts SMTP
    > 'mail-user'   'undefined' ;# account accepted by the mail-relay host
    > 'mail-pass'   ''		;# and associated credentials
    > 'mail-tls'    '0'		;# Bool. Activates TLS to secure SMTP transactions

    #				-- Mail content configuration
    > 'mail-sender' 'undefined' ;# Email address to place into From/Sender headers
    > 'mail-header' '$h'	;# Text to place before the generated content
    > 'mail-footer' ''		;# Text to place after the generated content
    #				 # Note: Template processing happens after the content
    #				 # is assembled, i.e. affects header and footer.

    return
}

proc ::m::db::SETUP-201810131603 {} {
    debug.m/db {}
    # Add tables for rejection mail content
    # (submission processing)

    D m::db
    # - -- --- ----- -------- -------------
    I+
    C name	TEXT	NOT NULL UNIQUE
    C automail	INTEGER NOT NULL
    C isdefault INTEGER NOT NULL
    C text	TEXT	NOT NULL
    T reply

    set sm "It is spam"
    set om "It is off-topic here"
    set rm "It was intentionally removed before and we will not add it again"

    >+ 'spam'	  0 1 '$sm' ;# default reason
    >+ 'offtopic' 1 0 '$om'
    >+ 'removed'  1 0 '$rm'

    return
}

proc ::m::db::SETUP-201810141600 {} {
    debug.m/db {}
    # Add tables for external submissions
    # - submissions
    # - rejected submissions (for easy auto-rejection on replication)

    D m::db
    # - -- --- ----- -------- -------------
    I+
    C url	TEXT NOT NULL UNIQUE
    C email	TEXT NOT NULL
    C submitter TEXT
    C sdate	INTEGER NOT NULL
    T submission
    X sdate

    I+
    C url    TEXT NOT NULL UNIQUE
    C reason TEXT NOT NULL
    T rejected

    return
}

proc ::m::db::SETUP-201810311600 {} {
    debug.m/db {}
    # Added column `size_kb` for store size to `store`.

    D m::db
    # - -- --- ----- -------- -------------
    I+
    C vcs     INTEGER  NOT NULL	 ^version_control_system
    C mset    INTEGER  NOT NULL	 ^mirror_set
    C size_kb INTEGER  NOT NULL
    U vcs mset
    < store  id vcs mset '0'

    package require m::store
    m::store::InitialSizes
    return
}

proc ::m::db::SETUP-201811152300 {} {
    debug.m/db {}
    # Added site configuration to the general state table

    D m::db
    # - -- --- ----- -------- -------------
    T^ state
    #				-- Debugging
    > 'site-active'   '0'	       ;# Site status (active or not)
    > 'site-store'    '~/.mirror/site' ;# Location where website is generated
    > 'site-mgr-mail' ''	       ;# Mail address of the site manager
    > 'site-mgr-name' ''	       ;# Name of the site manager
    > 'site-title'    'Mirror'	       ;# Name of the site
    > 'site-url'      ''	       ;# The url the site will be published at

    return
}

proc ::m::db::SETUP-201811162301 {} {
    debug.m/db {}
    # Added more site configuration to the general state table

    D m::db
    # - -- --- ----- -------- -------------
    T^ state
    #				-- Debugging
    > 'site-logo' '' ;# Path or url to the site logo.

    return
}

proc ::m::db::SETUP-201811202300 {} {
    debug.m/db {}
    # Added flag 'active' to repository.
    # Default: yes.

    D m::db
    # - -- --- ----- -------- -------------
    I+
    C url    TEXT     NOT NULL	UNIQUE
    C vcs    INTEGER  NOT NULL	^version_control_system
    C mset   INTEGER  NOT NULL	^mirror_set
    C active INTEGER  NOT NULL
    < repository  id url vcs mset '1'
    X vcs mset

    return
}

proc ::m::db::SETUP-201811212300 {} {
    debug.m/db {}
    # Added `hg` to the set of supported VCS.

    D m::db
    # - -- --- ----- -------- -------------
    T^ version_control_system
    >+ 'hg' 'Mercurial'

    return
}

proc ::m::db::SETUP-201811272200 {} {
    debug.m/db {}
    # Added optional columns `vcode` and `description` to the
    # submissions table. Initialized to empty. Further dropped unique
    # requirement from url, allowing multiple submissions of the same,
    # enabling fixing of description, vcode. Added index instead.

    D m::db
    # - -- --- ----- -------- -------------
    I+
    C url	  TEXT NOT NULL
    C vcode	  TEXT
    C description TEXT
    C email	  TEXT NOT NULL
    C submitter	  TEXT
    C sdate	  INTEGER NOT NULL
    < submission  id url '' '' email submitter sdate
    X sdate
    X url

    return
}

proc ::m::db::SETUP-201811282200 {} {
    debug.m/db {}
    # Added special column `session` to the submissions
    # table. Initialized to a value the other parts (cli, CGI) will
    # not generate.  Made url + session unique, i.e. primary key.  A
    # session is allowed to overwrite its submissions, but not the
    # submissions of other sessions.

    D m::db
    # - -- --- ----- -------- -------------
    I+
    C session	  TEXT NOT NULL
    C url	  TEXT NOT NULL
    C vcode	  TEXT
    C description TEXT
    C email	  TEXT NOT NULL
    C submitter	  TEXT
    C sdate	  INTEGER NOT NULL
    U session url
    < submission  id ':lock:' url vcode description email submitter sdate
    X sdate
    X url

    return
}

proc ::m::db::SETUP-201812042200 {} {
    debug.m/db {}
    # Added sync helper table.
    # Remember all submissions handled locally (accepted or rejected),
    # for deletion from the CGI site database on next sync. Note that
    # we only need the key information, i.e. url + session id.

    D m::db
    # - -- --- ----- -------- -------------
    C session	  TEXT NOT NULL
    C url	  TEXT NOT NULL
    U session url
    T submission_handled

    return
}

proc ::m::db::SETUP-201901112300 {} {
    debug.m/db {}
    # Added column `attend` to `store_times`.
    # Column records presence of issues in the
    # last update for the store.

    D m::db
    # - -- --- ----- -------- -------------
    C store    INTEGER	NOT NULL  ^store PRIMARY KEY
    C created  INTEGER	NOT NULL
    C updated  INTEGER	NOT NULL
    C changed  INTEGER	NOT NULL
    C attend   INTEGER	NOT NULL
    < store_times  store updated updated changed '0'
    # fake "no issues" during creation ...........^

    package require m::store
    m::store::InitialIssues
    return
}

proc ::m::db::SETUP-201901222300 {} {
    debug.m/db {}

    # Extended the tables `store` and `store_times` with columns to
    # track size changes (KB, #revisions) and time statistics for
    # updates.

    D m::db
    # - -- --- ----- -------- -------------
    C store	     INTEGER  NOT NULL	^store PRIMARY KEY
    C created	     INTEGER  NOT NULL
    C updated	     INTEGER  NOT NULL
    C changed	     INTEGER  NOT NULL
    C attend	     INTEGER  NOT NULL
    C min_seconds    INTEGER  NOT NULL ;# overall minimum time spent on update
    C max_seconds    INTEGER  NOT NULL ;# overall maximum time spent on update
    C window_seconds STRING   NOT NULL ;# time spent on last N updates (list of int)
    < store_times  store updated updated changed attend '-1' '0' ''

    # Note: A min_seconds value of -1 represents +Infinity.

    T^ state
    > 'store-window-size' '10' ;# Window size for `store.window_seconds`

    I+
    C vcs	       INTEGER	NOT NULL  ^version_control_system
    C mset	       INTEGER	NOT NULL  ^mirror_set
    C size_kb	       INTEGER	NOT NULL
    C size_previous    INTEGER	NOT NULL
    C commits_current  INTEGER	NOT NULL
    C commits_previous INTEGER	NOT NULL
    U vcs mset
    < store  id vcs mset size_kb size_kb '0' '0'

    package require m::store
    m::store::InitialCommits
    return
}

proc ::m::db::SETUP-201901242300 {} {
    debug.m/db {}

    # New table `store_github_forks`. Adjunct to table `store`, like
    # `store_times`. Difference: Not general, specific to github
    # stores. Tracks the number of forks. Primary source is the local
    # git repository, the information in the table is derived. Used for
    # easier access to statistics (size x forks ~?~ update time).

    D m::db
    # - -- --- ----- -------- -------------
    C store	     INTEGER  NOT NULL	^store PRIMARY KEY
    C nforks	     INTEGER  NOT NULL
    T store_github_forks

    package require m::store
    m::store::InitialForks
    return
}

proc ::m::db::SETUP-201901252300 {} {
    debug.m/db {}
    # Added more state, start of the current cycle.

    D m::db
    # - -- --- ----- -------- -------------
    T^ state

    > 'start-of-current-cycle' '[clock seconds]' ;# As epoch
    #  Fake start for now, self corrects when it comes around.

    return
}

proc ::m::db::SETUP-201901252301 {} {
    debug.m/db {}
    # And (local) email address for reporting

    D m::db
    # - -- --- ----- -------- -------------
    T^ state

    > 'report-mail-destination' ''
    return
}

proc ::m::db::SETUP-201902052300 {} {
    debug.m/db {}
    # Added more state, start of the previous cycle.
    # Compare with current for rough length.

    D m::db
    # - -- --- ----- -------- -------------
    T^ state

    > 'start-of-previous-cycle' '[clock seconds]' ;# As epoch
    #  Fake start for now, self corrects when it comes around
    #  next time.

    return
}

proc ::m::db::SETUP-201902052301 {} {
    debug.m/db {}
    # Added `svn` to the set of supported VCS.

    D m::db
    # - -- --- ----- -------- -------------
    T^ version_control_system
    >+ 'svn' 'Subversion'

    return
}

proc ::m::db::SETUP-201910031116 {} {
    debug.m/db {}
    # Extended mail configuration, width to use for tables.

    D m::db
    # - -- --- ----- -------- -------------
    T^ state
    #				-- Mail content configuration
    > 'mail-width' '200'	;# Width of tables placed into content

    return
}

proc ::m::db::SETUP-201910032120 {} {
    debug.m/db {}

    # Drop table `name` as superfluous. The only user of this
    # information is table `mirror_set`. Fold the data into a
    # modified `mirror_set`. Further drop the auto-increment.

    # Note: The table `name` was intended as the hook for other
    # systems (project indices, etc.) to link into this schema. With
    # this change `mirror_set` itself becomes the place to hook into.

    D m::db
    # - -- --- ----- -------- -------------

    I
    C name  TEXT  NOT NULL  UNIQUE

    <= mirror_set {
	SELECT M.id
	,      N.name
	FROM @@	  M
	,    name N
	WHERE M.name = N.id
    }

    / name

    return
}

proc ::m::db::SETUP-202207020000 {} {
    debug.m/db {}

    D m::db
    # - -- --- ----- -------- -------------

    # Move to schema V3
    # - The main change is the explicit representation and handling of
    #	forks.
    # - A number of small changes renaming and moving various tables
    #	and fields.

    # - -- --- ----- -------- -------------
    # Drop `mset_pending`, and replace with proper `repo_pending`.
    #
    ## Repository Pending - List of repositories waiting for an update
    ##			    to process them

    C repository  INTEGER  NOT NULL  ^repository  PRIMARY KEY
    T repo_pending

    # - -- --- ----- -------- -------------
    ## Rename `mirror_set` to `project` as a more suitable name.

    R "ALTER TABLE mirror_set RENAME TO project"

    # - -- --- ----- -------- -------------
    ## Redo the repositories
    #
    ## - Rename `mset` to `project
    ## - Add store_times.*_seconds
    ## - Add store reference
    ## - Add checked stamp
    ## - Drop
    #
    ## ATTENTION -- This is done before updating the store schema
    ## because the code to find and link the store requires the mset
    ## reference to be dropped.

    I+
    C url	      TEXT     NOT NULL	 UNIQUE
    C project	      INTEGER  NOT NULL	 ^project
    C vcs	      INTEGER  NOT NULL	 ^version_control_system
    C store	      INTEGER  NOT NULL	 ^store
    C fork_origin     INTEGER		 ^repository
    C is_active	      INTEGER  NOT NULL
    C has_issues      INTEGER  NOT NULL
    C checked	      INTEGER  NOT NULL ;# epoch
    C min_duration    INTEGER  NOT NULL ;# overall minimum time spent on update
    C max_duration    INTEGER  NOT NULL ;# overall maximum time spent on update
    C window_duration STRING   NOT NULL ;# time spent on last N updates (list of int)
    < repository id url mset vcs -1    NULL active 0    0   0   0   ''
    #               url proj vcs store fork act    issu chk min max win
    
    # Store linkage and store_times related information needs code.
    foreach {repo mset vcs url} [R {
	SELECT id
	,      project
	,      vcs
	,      url
	FROM   repository
    }] {
	# Locate store for repository
	set store [R [string map [list :mset $mset :vcs $vcs] {
	    SELECT id
	    FROM   store
	    WHERE  mset = :mset
	    AND	   vcs	= :vcs
	}]]

	lassign [R [string map [list :store $store] {
	    SELECT mset, vcs
	    FROM store
	    WHERE id = :store
	}]] msets vcss
	
	#puts stderr "XXX repo = $url/$mset/$vcs => S$store/$msets/$vcss"
	
	# Get time information
	lassign [R [string map [list :store $store] {
	    SELECT min_seconds
	    ,	   max_seconds
	    ,	   window_seconds
	    FROM   store_times
	    WHERE  store = :store
	}]] min max win

	# update repository with store and times
	R [string map [list :id $repo :min $min :max $max :win $win :store $store] {
	    UPDATE repository
	    SET store		= :store
	    ,	min_duration	= :min
	    ,	max_duration	= :max
	    ,	window_duration = ':win'
	    WHERE id = :id
	}]
    }

    # - -- --- ----- -------- -------------
    ## Redo the stores
    ## - Drop project reference, add various store_times fields.

    I+
    C vcs	       INTEGER	NOT NULL  ^version_control_system
    C size_kb	       INTEGER	NOT NULL
    C size_previous    INTEGER	NOT NULL
    C commits_current  INTEGER	NOT NULL
    C commits_previous INTEGER	NOT NULL
    C created	       INTEGER	NOT NULL
    C updated	       INTEGER	NOT NULL
    C changed	       INTEGER	NOT NULL
    <= store {
	SELECT S.id
	,      S.vcs
	,      S.size_kb
	,      S.size_previous
	,      S.commits_current
	,      S.commits_previous
	,      T.created
	,      T.updated
	,      T.changed
	FROM  @@	  S
	,     store_times T
	WHERE T.store = S.id
    }

    # - -- --- ----- -------- -------------
    ## Drop various tables which became superfluous due to the
    ## preceding changes.

    / mset_pending
    / store_github_forks
    / store_times

    return
}

# # ## ### ##### ######## ############# #####################
return
