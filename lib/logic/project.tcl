## -*- tcl -*-
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
package require m::db
package require m::repo
package require m::rolodex
package require debug
package require debug::caller

# # ## ### ##### ######## ############# ######################

namespace eval ::m {
    namespace export project
    namespace ensemble create
}
namespace eval ::m::project {
    namespace export \
	all add remove rename has \
	name used-vcs has-vcs size \
	stores known spec id count
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################

debug level  m/project
debug prefix m/project {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::m::project::spec {} {
    debug.m/project {}

    set lines {}
    foreach {project pname} [all] {
	foreach repo [m repo for $project] {
	    set ri [m repo get $repo]
	    dict with ri {}
	    # -> url	: repo url
	    #    vcs	: vcs id
	    # -> vcode	: vcs code
	    #    project: project id
	    #    name	: project name
	    #    store  : id of backing store for repo
	    lappend lines [list R $vcode $url]
	}
	lappend lines [list P $pname]
    }
    return [join $lines \n]
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

proc ::m::project::all {} {
    debug.m/project {}
    return [m db eval {
	SELECT id
	,      name
	FROM   project
	ORDER BY name ASC
    }]
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

    m db eval {
	INSERT
	INTO project
	VALUES ( NULL, :name )
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

proc ::m::project::stores {project} {
    debug.m/project {}
    return [m db eval {
	SELECT S.id
	FROM   store      S
	,      repository R
	WHERE  S.id = R.store
	AND    R.project = :project
    }]
}

proc ::m::project::used-vcs {project} {
    debug.m/project {}
    return [m db eval {
	SELECT DISTINCT vcs
	FROM   repository
	WHERE  project = :project
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

proc ::m::project::has-vcs {project vcs} {
    debug.m/project {}
    return [m db onecolumn {
	SELECT count (*)
	FROM   repository
	WHERE  project = :project
	AND    vcs     = :vcs
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

# # ## ### ##### ######## ############# ######################

proc ::m::project::K {x y} { set x }

# # ## ### ##### ######## ############# ######################
package provide m::project 0
return
