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
	set vcode [m vcs code     $vcs]
	set url   [m vcs url-norm $vcode $url]
    
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

	m vcs setup $vcode $name $url \
	    [m store add $vcs $mset]

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
	#    vcode	vcs code
	#    mset	mirror set id
	#    name	mirror set name

	m repo remove $repo

	# Remove store for the repo's vcs if no repositories for that
	# vcs remain in the mirror set.
	if {![m mset has-vcs $mset $vcs]} {
	    puts "- Removing $vcode store ..."

	    set store [m store id $vcs $mset]
	    m vcs cleanup $vcode $store
	    m store remove $store
	}

	# Remove mirror set if no repositories remain at all.
	if {![m mset size $mset]} {
	    puts "- Removing mirror set [color note $name] ..."
	    m mset remove $mset
	}

	# Update current and previous
	if {$repo == [m current next]} {
	    #                  (x repo)
	    m current swap ; # (repo x)
	    m current pop  ; # (x   '')
	}
	if {$repo == [m current top]} {
	    #                 (repo ?)
	    m current pop ; # (?   '')
	}
    }
    
    ShowCurrent
    puts [color good OK]
    return
}

proc ::m::glue::cmd_rename {config} {
    debug.m/glue {}
    package require m::current
    package require m::mset
    package require m::repo
    package require m::store
    package require m::vcs

    set repo   [$config @repository]
    set target [$config @name]
    debug.m/glue {repo  : $repo}
    debug.m/glue {target: $target}
    
    m db transaction {
	set rinfo [m repo get $repo]
	debug.m/glue {rinfo : $rinfo}

	dict with rinfo {}
	# -> url	repo url
	#    vcs	vcs id
	#    vcode      vcs code
	#    mset	mirror set id
	#    name	mirror set name - old name
	
	puts "Renaming [color note $name] ..."
	if {[m mset has $target]} {
	    m::cmdr::error "Target [color note $target] already present" \
		HAVE_ALREADY NAME
	}

	m mset rename $mset $target

	foreach store [m store list-for-mset $mset] {
	    m vcs rename $store $target
	}

	m current push $repo
    }

    ShowCurrent
    puts [color good OK]
    return
}

proc ::m::glue::cmd_merge {config} {
    debug.m/glue {}
    package require m::current
    package require m::mset
    package require m::repo
    package require m::store
    package require m::vcs

    m db transaction {
	set repos [MergeFill [$config @repositories]]
	debug.m/glue {repos = ($repos)}
	
	set msets [MergeSets $repos]
	debug.m/glue {msets = ($msets)}
	
	if {[llength $msets] < 2} {
	    m::cmdr::error \
		"All repositories are already in the same mirror set." \
		NOP
	}

	set secondaries [lassign $msets primary]
	
	puts "Target:  [color note [m mset name $primary]]"

	foreach secondary $secondaries {
	    puts "Merging: [color note [m mset name $secondary]]"
	    Merge $primary $secondary
	}

	m current set \
	    [lindex $repos 0] \
	    [lindex $repos end]
    }

    ShowCurrent
    puts [color good OK]
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

proc ::m::glue::MergeSets {repos} {
    debug.m/glue {}

    # List of repos into list of mirror sets. Keep order, integrated
    # dropping of duplicates.
    
    set has {}
    set result {}
    foreach r $repos {
	set mset [dict get [m repo get $r] mset]
	debug.m/glue {(r $r) -> (m $mset)}
	
	if {[dict exist $has $mset]} continue
	dict set has $mset .
	lappend result $mset
    }
    return $result
}

proc ::m::glue::MergeFill {repos} {
    debug.m/glue {}
    set n [llength $repos]

    if {!$n} {
	# No repositories. Use current and previous for merge
	# target and source
	return [m current get]
    }
    if {$n == 1} {
	# A single repository is the merge origin. Use current as
	# merge target.
	return [linsert $repos 0 [m current top]]
    }
    return $repos
}

proc ::m::glue::Merge {primary secondary} {
    debug.m/glue {}
    # - Iterate the vcs in the source
    #   - vcs not in destination: keep store, relink store to target.
    #   - vcs present: drop source store
    # - Relink all repositories into target

    set vcss [m mset list-vcs $secondary]

    # Check that all the secondary repositories fit into the primary.
    foreach vcs $vcss {
	if {![m store has $vcs $primary]} continue
	# Get the two stores, and check for compatibility

	set p [m store id $vcs $primary]
	set s [m store id $vcs $secondary]

	if {[m vcs check [m vcs code $vcs] $p $s]} continue

	m::cmdr::error \
	    "[m vcs name $vcs] mismatch" \
	    MISMATCH
    }

    # Move or merge the stores
    foreach vcs $vcss {
	if {![m store has $vcs $primary]} {
	    m store move $vcs $primary $secondary
	} else {
	    m vcs merge [m vcs code $vcs] $primary $secondary
	    m store remove $secondary
	}
    }

    # Move the repositories, drop the merged set.
    
    m repo move $vcs $primary $secondary
    m mset remove             $secondary
    return
}

proc ::m::glue::ShowCurrent {} {
    debug.m/glue {}
    Show {Current } [m current top]
    Show {Previous} [m current next]
    return
}

proc ::m::glue::Show {label repo} {
    debug.m/glue {}
    if {$repo eq {}} return
    puts "${label}: [color note [m repo name $repo]]"
    return
}

# # ## ### ##### ######## ############# ######################
package provide m::glue 0
return
