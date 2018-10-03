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
    namespace import ::cmdr::table::dict    ; rename dict    table/d
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
    package require m::current
    package require m::mset
    package require m::repo
    package require m::store
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
    
	if {[m repo has $url]} {
	    m::cmdr::error "Repository already present" \
		HAVE_ALREADY REPOSITORY
	}
	if {[m mset has $name]} {
	    m::cmdr::error "Name already present" \
		HAVE_ALREADY NAME
	}
	set mset [m mset add $name]

	m current push \
	    [m repo add $vcs $mset $url]

	puts [color note {Setting up the store ...}]

	m store add $vcs $mset [m vcs setup $vcode $name $url]

	puts [color note Done]
    }

    ShowCurrent
    puts [color good OK]
    return
}

proc ::m::glue::cmd_remove {config} {
    debug.m/glue {}
    package require m::current
    package require m::mset
    package require m::repo
    package require m::store
    package require m::vcs
    
    set repo [$config @repository]

    m db transaction {
	puts "Removing [color note [m repo name $repo]] ..."

	set rinfo [m repo get $repo]
	dict with rinfo {}
	# -> url	repo url
	#    vcs	vcs id
	#    mset	mirror set id
	#    name	mirror set name

	m repo remove $repo

	# Remove store if no repositories for the vcs remain in the
	# mirror set.
	if {![m repo size/vcs $vcs $mset]} {
	    puts "- Removing store ..."

	    set store [m store id $vcs $mset]
	    m vcs cleanup \
		[m vcs code $vcs] \
		[m store path $store]
	    m store remove $store
	}

	# Remove mirror set if no repositories remain at all.
	if {![m repo size $mset]} {
	    puts "- Removing mirror set [color note $name] ..."
	    m mset remove $mset
	}

	# Update current and previous
	if {$repo == [m current next]} {
	    m current swap
	    m current pop
	    m current swap
	}
	if {$repo == [m current top]} {
	    m current pop
	}
    }
    
    ShowCurrent
    puts [color good OK]
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
    package require m::repo
    package require m::current

    ShowCurrent
    puts [color good OK]
    return
}

proc ::m::glue::cmd_swap_current {config} {
    debug.m/glue {}
    package require m::repo
    package require m::current

    m current swap
    ShowCurrent
    puts [color good OK]
    return
}

proc ::m::glue::cmd_set_current {config} {
    debug.m/glue {}
    package require m::repo
    package require m::current

    m current push [$config @repository]
    ShowCurrent
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
    puts "List display limited to [color note [m state limit]]"
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

proc ::m::glue::cmd_test_vt_repository {config} {
    debug.m/glue {}
    package require m::repo
    
    set map [m repo known]
    [table/d t {
	foreach k [lsort -dict [dict keys $map]] {
	    set v [dict get $map $k]
	    $t add $k $v
	}
    }] show
    return
}

proc ::m::glue::cmd_debug_levels {config} {
    debug.m/glue {}
    puts [info level 0]		;# XXX TODO FILL-IN reject
    return
}

# # ## ### ##### ######## ############# ######################

proc ::m::glue::ShowCurrent {} {
    debug.m/glue {}
    puts "Current:  [color note [m repo name [m current top]]]"
    puts "Previous: [color note [m repo name [m current next]]]"
    return
}

# # ## ### ##### ######## ############# ######################
package provide m::glue 0
return
