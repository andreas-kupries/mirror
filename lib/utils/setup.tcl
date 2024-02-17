## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## Database utilities - Setup, migration processing, schema management

# @@ Meta Begin
# Package db::setup 0
# Meta author   {Andreas Kupries}
# Meta location https://core.tcl.tk/akupries/????
# Meta platform tcl
# Meta summary     Database setup, migration management
# Meta description Database setup, migration management
# Meta subject {database setup} {migration processing} {schema management}
# Meta require {Tcl 8.5-}
# @@ Meta End

package provide db::setup 0
package require debug
package require debug::caller

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require db::track 0

# # ## ### ##### ######## ############# ######################

debug level  db/setup
debug prefix db/setup {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval db::setup {
    namespace import ::db::track::it ; rename it track
    namespace export D C U T T^ I I+ > >+ X < <= /
}

namespace eval db {
    namespace export setup
    namespace ensemble create
}

proc ::db::setup {db migrationbase} {
    debug.db/setup {}
    # Call only when the DB command is already defined as a database
    # command proper.
    #
    # Runs all the migrations known. Note, the first migration is the
    # initial schema, i.e. migrating from the empty database to
    # something containing tables.
    #
    # The version numbers are timestamps in yyyyMMddHHmm format.
    # Allows for schema changes every minute. Storable as integers.
    # Sortable. Migrations are run in ascending order.	Migrations
    # already applied are skipped.

    set migrations [lsort -dict [info commands ::${migrationbase}-*]]
    set maxv	   [lindex [split [lindex $migrations end] -] end]

    $db transaction {
	set currv [setup::InitializeAndGetVersion $db]
	setup::track At $currv
	if {$maxv < $currv} {
	    return -code error -errorcode {MIRROR DB SCHEMA AHEAD} \
		"Current schema $currv ahead of code schema $maxv"
	}

	foreach m $migrations {
	    set v [lindex [split $m -] end]
	    # Skip all migrations already applied to the schema
	    if {$v <= $currv} continue
	    setup::track To $v
	    $m
	    setup::SetVersion $db $v
	    setup::track Ok $v
	}
	setup::track Done
    }
    return
}

proc db::setup::D {args} {
    debug.db/setup {}
    variable thedbcmd $args
    return
}

proc db::setup::I {} {
    debug.db/setup {}
    C id INTEGER NOT NULL PRIMARY KEY
    return
}

proc db::setup::I+ {} {
    debug.db/setup {}
    C id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT
    return
}

proc db::setup::C {name type args} {
    debug.db/setup {}
    variable thecols
    lappend def $name $type
    foreach w $args {
	if {[string match ^* $w]} {
	    lappend def REFERENCES [string range $w 1 end] (id)
	} else {
	    lappend def $w
	}
    }
    lappend thecols [join $def]
    return
}

proc db::setup::U {args} {
    variable thecols
    lappend thecols "UNIQUE ( [join $args {, }] )"
    return
}

proc db::setup::T {table} {
    debug.db/setup {}
    variable thecols
    variable thetable $table
    append def "CREATE TABLE $table\n( "
    append def [join [Flat [PadR 1 [PadR 0 $thecols]]] "\n, "]
    append def "\n);"
    set thecols {}
    R $def
    return
}

proc db::setup::/ {table} {
    debug.db/setup {}
    R "DROP TABLE $table"
    return
}

proc db::setup::T^ {table} {
    debug.db/setup {}
    variable thetable $table
    return
}

proc db::setup::X {args} {
    debug.db/setup {}
    variable theindex
    variable thetable
    R "CREATE INDEX ${thetable}_[incr theindex]\nON $thetable ( [join $args {, }] )"
    return
}

proc db::setup::< {table args} {
    debug.db/setup {}
    T new_${table}
    lappend sql "INSERT INTO new_${table} SELECT [join $args ,] FROM $table"
    lappend sql "DROP TABLE $table"
    lappend sql "ALTER TABLE new_${table} RENAME TO $table"
    R [join $sql ";\n"]
    variable thetable $table
    return
}

proc db::setup::<= {table select} {
    debug.db/setup {}
    T new_${table}

    # constraint: do no lose rows. count, then count again.
    set old [lindex [R "SELECT count (*) FROM $table"] 0]

    lappend map @@ $table
    set select [string map $map $select]
    lappend sql "INSERT INTO new_${table} $select"
    lappend sql "DROP TABLE $table"
    lappend sql "ALTER TABLE new_${table} RENAME TO $table"
    R [join $sql ";\n"]

    set new [lindex [R "SELECT count (*) FROM $table"] 0]

    if {$old != $new} {
	return -code error -errorcode {MIRROR DB SCHEMA CHANGE FAIL} \
	    "Migration of $table failed, row number mismatch: $new after != $old before."
    }

    variable thetable $table
    return
}

proc db::setup::> {args} {
    debug.db/setup {}
    variable thetable
    R "INSERT INTO $thetable VALUES ( [join $args ,] );"
}

proc db::setup::>+ {args} {
    debug.db/setup {}
    variable thetable
    R "INSERT INTO $thetable VALUES ( NULL, [join $args ,] );"
}

proc db::setup::R {sql} {
    debug.db/setup {}
    variable thedbcmd
    return [uplevel 2 [list {*}$thedbcmd eval $sql]]
}

proc db::setup::PadR {i columns} {
    debug.db/setup {}
    set max -1
    foreach c $columns {
	set max [expr {max ($max, [string length [lindex $c $i]])}]
    }
    set fmt %-${max}s
    set tmp {}
    foreach c $columns {
	lappend tmp [lreplace $c $i $i [format $fmt [lindex $c $i]]]
    }
    return $tmp
}

proc db::setup::Flat {columns} {
    debug.db/setup {}
    set tmp {}
    foreach c $columns { lappend tmp [join $c] }
    return $tmp
}

proc db::setup::SetVersion {db v} {
    debug.db/setup {}
    $db eval {
	UPDATE schema
	SET    version = :v
	WHERE  key     = 'version'
    }
    return
}

proc db::setup::InitializeAndGetVersion {db} {
    debug.db/setup {}
    return [$db eval [string map [list \t {}] {
	CREATE TABLE IF NOT EXISTS schema
	( key     TEXT    NOT NULL PRIMARY KEY
	, version INTEGER NOT NULL
	)
	;
	INSERT OR IGNORE
	INTO   schema
	VALUES ('version', 0)
	;
	SELECT version
	FROM schema
	WHERE key = 'version'
    }]]
}

namespace eval db::setup {
    variable thecols  {}
    variable thetable {}
    variable theindex 0
    variable thedbcmd bogus-db-command
}

# # ## ### ##### ######## ############# #####################
return
