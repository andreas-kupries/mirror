# -*- mode: tcl; fill-column: 90 -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package m::project 0
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
package require m::db
package require m::repo
package require m::rolodex
package require m::store

# # ## ### ##### ######## ############# ######################

namespace eval ::m {
    namespace export project
    namespace ensemble create
}
namespace eval ::m::project {
    namespace export \
	add remove rename has name size id a-repo count-for \
	statistics get-all list-for known spec count
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################

debug level  m/project
debug prefix m/project {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::m::project::statistics {{nophantoms 0}} {
    debug.m/project {}

    m db transaction {
	set cc [m state start-of-current-cycle]
	set pc [m state start-of-previous-cycle]

	set ncc 0
	set npc 0
	foreach row [m repo updates $nophantoms] {
	    dict with row {}
	    # store pname vcode changed updated created size active remote
	    # sizep commits commitp mins maxs lastn
	    if {$created eq "."} continue ;# ignore separations
	    if {$changed >= $cc} { incr ncc ; continue }
	    if {$changed >= $pc} { incr npc ; continue }
	}

	dict set stats ncc $ncc
	dict set stats npc $npc

	dict set stats np [m project count]

	# TODO: move down into the repo and store statistics

	dict set stats nr [m repo count]
	dict set stats nw [m repo count-pending]
	#
	dict set stats ns [m store count]
	dict set stats nl [llength [m store lost]]
	dict set stats sz [m store total-size]

	dict set stats cc $cc
	dict set stats pc $pc

	dict set stats ni [llength [m repo issues   $nophantoms]] ;# excludes disabled
	dict set stats nd [llength [m repo disabled $nophantoms]]

	dict set stats st [m store statistics]
	dict set stats rt [m repo  statistics $nophantoms]

	if {$nophantoms} {
	    dict incr stats nr -[dict get $stats rt phantom]
	}
    }

    return $stats
}

proc ::m::project::spec {} {
    debug.m/project {}

    # A repository belongs to a single project.
    # A repository uses a single store.
    #
    # Conversely
    #
    # A project contains one or more repositories.
    # A store is used by one or more repositories.
    #
    # Nothing in the above claims that the repositories of a store are always contained in
    # the same project.
    #
    # Desired for the export spec:
    #  - Human readability
    #  - Human editability
    #  - Compact
    #  - Easy machine parsing
    #
    # The main issue with the first three is how to represent the shared stores. Projects
    # and repositories can be represented hierarchically, flattened. The stores can cut
    # across that.
    #
    # To make decisions easier for the emitter, collect all information first, in a way
    # which makes it easy to see if we even have cross cuts.
    #
    # And then there is of course compatibility with old specs.

    # Design:
    # - Command based, as before.
    #
    # - Short-form commands
    #
    #   - `P name`	Specify project. Contains preceding repositories.
    #	- `R vcs url`	Specify repository by location and manager.
    #	- `E vcs url`	As `R`, share store with previous repository.
    #   - `B url`	Set a base repository for sharing.
    #   - `M vcs url`	Not generated. Still recognized. Behaves as `R`.
    #
    # - Long-form command names - Generated
    #
    #   - project
    #   - repository
    #   - extend-previous
    #   - disable
    #   - private
    #   - tracking-forks
    #   - base
    #
    # - Import accepts both short and long forms. Case-insensitive.  Any unique prefix is
    #   recognized. The non-unique `p` prefix maps to `project` as per the desired
    #   short-form commands.
    #
    # - `B` is only generated when a shared store cuts across projects.
    #
    # - Everything else uses `E`, which uses an implicit base from the preceding `R`. In
    #   other words, the sequence
    #
    #     R ... foo
    #     E ... bar
    #
    #   is internally effectively handled as
    #
    #     R ... foo
    #     B     foo
    #     E ... foo
    #
    # - Command order.
    #
    #   - `repository`, `extend-previous` are prefix relative to `project`.
    #     A `project` command closes the preceding run of `reository` and
    #     `extend-previous` commands.
    #
    #   - `base` commands have to be placed immediately before the `extend-previous`
    #     commands they apply to.
    #
    #   - `disabled`, `private`, and `tracking-forks` are attribute commands which have to
    #     follow immediately after the `repository`/`extend-previous` command they apply
    #     to.
    #
    # The exporter uses indentation to hint at these relationship. This indentation has no
    # syntactic nor semantic meaning. The importer ignores it. Only the command order
    # matters to it.

    set p {} ;# dict (name -> id)
    set v {} ;# dict (url -> vcs)		vcs per repo, all repos!
    set g {} ;# dict (pname -> store -> url -> .)
    set b {} ;# dict (store -> url)		store base
    set s {} ;# dict (url -> (active, private, tracking))
    
    # Collect projects
    foreach {project pname} [m db eval {
	SELECT id
	,      name
	FROM   project
	ORDER BY name ASC
    }] {
	debug.m/project {P $project $pname}

	dict set p $pname $project
    }

    # Collect per-project repositories and stores
    dict for {pname project} $p {
	foreach repo [m repo for $project] {
	    set ri [m repo get $repo]
	    dict with ri {}
	    # - url, vcode, store, active, private, tracking
	    # ignore phantoms!
	    if {$store eq {}} continue
	    dict set v $url   $vcode
	    dict set b $store {} ;# initially no base
	    dict set g $pname $store $url .
	    dict set s $url   [list $active $private $tracking]
	}
    }

    # Spec emitter

    #puts ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    #array set _p $p ; parray _p ; unset _p
    #array set _v $v ; parray _v ; unset _v
    #array set _g $g ; parray _g ; unset _g
    #array set _b $b ; parray _b ; unset _b
    #array set _s $s ; parray _s ; unset _s

    set lines {}
    foreach pname [lsort -dict [dict keys $p]] {
	set groups [dict get $g $pname]
	# dict (store -> url -> .)

	foreach store [lsort -dict [dict keys $groups]] {
	    #puts /$store
	    set urls [lsort -dict [dict keys [dict get $groups $store]]]
	    set base [dict get $b $store]
	    if {$base ne {}} {
		EMIT base $base
		set cmd extend-previous
	    } else {
		set cmd repository
	    }
	    foreach u $urls {
		EMIT $cmd [dict get $v $u] $u
		set cmd extend-previous
		
		lassign [dict get $s $u] a p t
		if {!$a} { EMIT disabled }
		if {$p}  { EMIT private }
		if {$t}  { EMIT tracking-forks }
	    }
	    # Save store base for possible cross cut
	    dict set b $store $u
	}
	EMIT project $pname
    }

    #puts ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    return [join $lines \n]
}

# see also - ops/client/Encode, vcs/Decode, glue/Decode
proc ::m::project::Encode {words} {
    lmap w $words { string map [list % %% \n %n] $w }
}

proc ::m::project::EMIT {args} {
    upvar 1 lines lines

    set cmd [dict get {
	base		{    base            }
	disabled	{        disabled}
	extend-previous	{    extend-previous }
	private         {        private}
	project         {project        }
	repository	{    repository      }
	tracking-forks	{        tracking-forks}
    } [lindex $args 0]]

    lappend lines "$cmd[join [lmap w [Encode [lrange $args 1 end]] { list $w }] { }]"
    return
}

proc ::m::project::known {} {
    debug.m/project {}

    # Return map to project ids.
    # Keys:
    # - rolodex ids (+ '@current', '@', '@prev')
    # - repository urls
    # - project names

    set map {}
    set mid {}

    # Repository and project information in one trip.
    m db eval {
	SELECT P.id   AS id
	,      P.name AS name
	,      R.id   AS rid
	,      R.url  AS url
	FROM   repository R
	,      project    P
	WHERE  R.project = P.id
    } {
	dict set mid $rid $id
	dict set map [string tolower $url]  $id
	dict set map [string tolower $name] $id
    }

    # See also m::repo::known
    # Note, different ids! project, not repo.
    set c {}
    set p {}
    set id -1
    foreach r [m rolodex get] {
	set p $c ; set c $r ; incr id
	dict set map "@$id" [dict get $mid $r]
    }
    if {$p ne {}} {
	set p [dict get $mid $p]
	dict set map @prev $p
	dict set map @-1   $p
    }
    if {$c ne {}} {
	set c [dict get $mid $c]
	dict set map @current $c
	dict set map @        $c
    }

    return $map
}

proc ::m::project::id {name} {
    debug.m/project {}
    return [m db onecolumn {
	SELECT id
	FROM   project
	WHERE  name = :name
    }]
}

proc ::m::project::count {} {
    debug.m/project {}
    return [m db onecolumn {
	SELECT count (*)
	FROM   project
    }]
}

proc ::m::project::add {name} {
    debug.m/project {}

    set dname [string tolower $name]
    m db eval {
	INSERT
	INTO project
	VALUES ( NULL, :name, :dname )
    }

    return [m db last_insert_rowid]
}

proc ::m::project::remove {project} {
    debug.m/project {}

    # TODO FILL project/remove -- Verify that the project has no references
    # anymore, from neither repositories nor stores

    return [m db eval {
	DELETE
	FROM  project
	WHERE id = :project
    }]
}

proc ::m::project::rename {project name} {
    debug.m/project {}
    m db eval {
	UPDATE project
	SET    name = :name
	WHERE  id   = :project
    }
    return
}

proc ::m::project::has {name} {
    debug.m/project {}
    return [m db onecolumn {
	SELECT count (*)
	FROM   project
	WHERE  name = :name
    }]
}

proc ::m::project::size {project} {
    debug.m/project {}
    return [m db onecolumn {
	SELECT count (*)
	FROM   repository
	WHERE  project = :project
    }]
}

proc ::m::project::name {project} {
    debug.m/project {}
    return [m db onecolumn {
	SELECT name
	FROM   project
	WHERE  id = :project
    }]
}

proc ::m::project::get-all {} {
    debug.m/project {}

    dict set c order name
    list-for c
    return [dict get $c series]
}

proc ::m::project::a-repo {project} {
    debug.m/project {}
    return [m db onecolumn {
	SELECT R.id
	FROM   repository R
	WHERE  R.project = :project
	LIMIT 1
    }]
}

# # ## ### ##### ######## ############# ######################

proc ::m::project::count-for {config} {
    # Suboptimal counting - get entire list, without start/limit restrictions, and compute
    # its length. Might be quicker to let the SQL count. More complex too, regarding the
    # SQL generation.

    dict unset config start
    dict unset config limit

    list-for config
    return [llength [dict get $config series]]
}

proc ::m::project::list-for {cv} {
    upvar 1 $cv config

    # dict :: 'order'        - name, nrepos, nstores            /3 .
    #      :: 'match'        - '', substring                    /2 .
    #      :: 'start'        - '', number                       /2 .
    #      :: 'limit'        - '', number                       /2 .
    #                                                          =/24
    dict with config {}
    set clauses {}
    set op "WHERE"

    set has_start [expr {[info exists start] && ($start ne {}) && ($start > 0)}]
    set has_limit [expr {[info exists limit] && ($limit ne {}) && ($limit > 0)}]

    if {$has_start && !$has_limit} {
	set has_limit 1 ; set limit -1 ;# force limit as 'no limit' to satisfy sql syntax.
    }

    if {[info exists match]} {
	set match [string tolower $match]
	# Disable all glob-special characters in the pattern. We want a proper substring
	# search, not globbing.
	set match [string map [list * \\* ? \\? \[ \\\[ \{ \\\{ \\ \\\\] $match]
	append clauses \n "$op GLOB('*${match}*', P.dname)"
	set op AND
    }

    switch -exact -- $order {
	name    { append clauses \n "ORDER BY name    ASC, nstores ASC, nrepos  ASC" }
	nrepos  { append clauses \n "ORDER BY nrepos  ASC, name    ASC, nstores ASC" }
	nstores { append clauses \n "ORDER BY nstores ASC, name    ASC, nrepos  ASC" }
    }

    # Apply offset and limit to be handled in SQL, ...
    if {$has_limit} { append clauses \n "LIMIT $limit" }
    if {$has_start} { append clauses  " OFFSET $start" }

    # ... and retrieve the data
    dict set config series [PROJECTS $clauses]

    # Compute a new start offset based on incoming start, limit, and length of result.
    if {$has_limit && ($limit >= 0)} {
	# Actual limit present
	if {[llength [dict get $config series]] < $limit} {
	    # Short read (less than limit), reached end, reset to top
	    dict set config start {}
	} else {
	    # Full read, increment start offset to jump chunk on next run
	    if {!$has_start} { set start 0 }
	    incr start $limit
	    dict set config start $start
	}
    } else {
	# No (actual) limit, full read, reset to top
	dict set config start {}
    }

    return
}

proc ::m::project::PROJECTS {{clauses {}}} {
    debug.m/project {}

    lappend map @clauses@ $clauses
    set series {}
    m db eval [string map $map {
	SELECT P.id   AS id
	,      P.name AS name
	,      (SELECT count (*)
		FROM   repository A
		WHERE  A.project = P.id
		AND    A.store IS NOT NULL
		AND    A.store != '') AS nrepos
	,      (SELECT count (*) FROM (SELECT DISTINCT B.store
				       FROM   repository B
				       WHERE  B.project = P.id
				       AND    B.store IS NOT NULL
				       AND    B.store != '')) AS nstores
	FROM project P
	@clauses@
    }] {
	dict set row id      $id
	dict set row name    $name
	dict set row nrepos  $nrepos
	dict set row nstores $nstores

	lappend series $row
	unset row
    }

    # series :: list (row)
    # row    :: dict (id, name, nrepos, nstores)

    return $series
}

# # ## ### ##### ######## ############# ######################

proc ::m::project::K {x y} { set x }

# # ## ### ##### ######## ############# ######################
package provide m::project 0
return
