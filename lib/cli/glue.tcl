## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package m::glue 0
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
package require cmdr::color
package require cmdr::table
package require debug
package require debug::caller
#package require linenoise
#package require textutil::adjust
#package require try

# # ## ### ##### ######## ############# ######################

namespace eval ::m {
    namespace export glue
    namespace ensemble create
}
namespace eval ::m::glue {
    namespace export cmd_*
    namespace ensemble create

    namespace import ::cmdr::color

    namespace import ::cmdr::table::general ; rename general table
}

# # ## ### ##### ######## ############# ######################

debug level  m/glue
debug prefix m/glue {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::m::glue::cmd_store {config} {
    debug.m/glue {}
    package require m::state

    if {[$config @path set?]} {
	m state store [file normalize [$config @path]]
    }
    puts "Stores at [color note [m state store]]"
    return
}

proc ::m::glue::cmd_take {config} {
    debug.m/glue {}
    package require m::state

    if {[$config @take set?]} {
	m state take [$config @take]
    }
    puts "Taking [color note [m state take]] per update"
    return
}

proc ::m::glue::cmd_vcs {config} {
    debug.m/glue {}
    package require m::vcs

    puts [color note {Supported VCS}]
    [table t {Code Name} {
	foreach {code name} [m vcs list] {
	    $t add $code $name
	}
    }] show
    return
}

proc ::m::glue::cmd_add {config} {
    debug.m/glue {}
    package require m::state
    package require m::vcs
    
    m db transaction {
	set url [$config @url]
	# TODO: Move detection into a generator for @vcs
	if {[$config @vcs set?]} {
	    set vcs [$config @vcs]
	} else {
	    set vcs [m validate vcs \
			 validate _ [m vcs detect $url]]
	}
	set vcode [m vcs code $vcs]
	set url   [m vcs url-norm $url]
    
	if {[$config @name set?]} {
	    set name [$config @name]
	} else {
	    set name [m vcs name-from-url $vcode $url]
	}

	puts "Attempting to add"
	puts "  Repository [color note $url]"
	puts "  Named      [color note $name]"
	puts "  Managed by [color note [m vcs name $vcs]]"
    
	if {[HasRepository $url]} {
	    m::cmdr::error "Repository already present" \
		HAVE_ALREADY REPOSITORY
	}
	if {[HasMirrorSet $name]} {
	    m::cmdr::error "Name already present" \
		HAVE_ALREADY NAME
	}
	set mset [AddMirrorSet $name]
	AddPending $mset
	PushCurrent [AddRepository $vcs $mset $url]

	puts [color note {Setting up the store ...}]
	
	AddTimes \
	    [AddStore $vcs $mset \
		 [m vcs setup $vcode $name $url]]

	puts [color note Done]
    }

    puts [color good OK]
    return
}

proc ::m::glue::cmd_remove {config} {
    debug.m/glue {}
    puts [info level 0]		;# XXX TODO FILL-IN remove
    return
}

proc ::m::glue::cmd_rename {config} {
    debug.m/glue {}
    puts [info level 0]		;# XXX TODO FILL-IN rename
    return
}

proc ::m::glue::cmd_merge {config} {
    debug.m/glue {}
    puts [info level 0]		;# XXX TODO FILL-IN merge
    return
}

proc ::m::glue::cmd_split {config} {
    debug.m/glue {}
    puts [info level 0]		;# XXX TODO FILL-IN split
    return
}

proc ::m::glue::cmd_current {config} {
    debug.m/glue {}
    puts [info level 0]		;# XXX TODO FILL-IN current
    return
}

proc ::m::glue::cmd_update {config} {
    debug.m/glue {}
    puts [info level 0]		;# XXX TODO FILL-IN update
    return
}

proc ::m::glue::cmd_list {config} {
    debug.m/glue {}
    puts [info level 0]		;# XXX TODO FILL-IN list
    return
}

proc ::m::glue::cmd_reset {config} {
    debug.m/glue {}
    puts [info level 0]		;# XXX TODO FILL-IN reset
    return
}

proc ::m::glue::cmd_rewind {config} {
    debug.m/glue {}
    puts [info level 0]		;# XXX TODO FILL-IN rewind
    return
}

proc ::m::glue::cmd_limit {config} {
    debug.m/glue {}
    package require m::state

    if {[$config @limit set?]} {
	m state limit [$config @limit]
    }
    puts [m state limit]
    return
}

proc ::m::glue::cmd_submissions {config} {
    debug.m/glue {}
    puts [info level 0]		;# XXX TODO FILL-IN submissions
    return
}

proc ::m::glue::cmd_accept {config} {
    debug.m/glue {}
    puts [info level 0]		;# XXX TODO FILL-IN accept
    return
}

proc ::m::glue::cmd_reject {config} {
    debug.m/glue {}
    puts [info level 0]		;# XXX TODO FILL-IN reject
    return
}

# # ## ### ##### ######## ############# ######################

proc ::m::glue::PushCurrent {id} {
    debug.m/glue {}
    m state previous-repository [m state current-repository]
    m state current-repository $id
}

proc ::m::glue::AddStore {vcs mset path} {
    debug.m/glue {}
    m db eval {
	INSERT
	INTO   store
	VALUES ( NULL, :path, :vcs, :mset )
    }
    return [m db last_insert_rowid]
}

proc ::m::glue::AddTimes {store} {
    debug.m/glue {}
    set now [clock seconds]
    m db eval {
	INSERT
	INTO   store_times
	VALUES ( NULL, :store, :now, :now )
    }
    return [m db last_insert_rowid]
}

proc ::m::glue::AddPending {mset} {
    debug.m/glue {}
    m db eval {
	INSERT
	INTO   mset_pending
	VALUES ( :mset )
    }
    return
}

proc ::m::glue::AddRepository {vcs mset url} {
    debug.m/glue {}
    m db eval {
	INSERT
	INTO   repository
	VALUES ( NULL, :url, :vcs, :mset )
    }
    return [m db last_insert_rowid]
}

proc ::m::glue::HasRepository {url} {
    debug.m/glue {}
    m db eval {
	SELECT count (*)
	FROM   repository
	WHERE  url = :url
    }
}

proc ::m::glue::AddMirrorSet {name} {
    debug.m/glue {}
    m db eval {
	INSERT INTO name VALUES ( NULL, :name )
    }
    set nid [m db last_insert_rowid]
    m db eval {
	INSERT INTO mirror_set VALUES ( NULL, :nid )
    }
    return [m db last_insert_rowid]
}

proc ::m::glue::HasMirrorSet {name} {
    debug.m/glue {}
    m db eval {
	SELECT count (*)
	FROM   mirror_set M
	,      name       N
	WHERE  M.name = N.id
	AND    N.name = :name
    }
}

# # ## ### ##### ######## ############# ######################
package provide m::glue 0
return
