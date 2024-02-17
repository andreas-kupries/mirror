## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package m::rolodex 0
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
##

# The rolodex is mainly maintained in memory. It is loaded on demand
# just before the first operation on it, and committed by the cli
# command at the end of a transaction, if changed. The commit
# operation is also where truncation happens. This simplifies the
# in-memory operations, as they do not have to care about size.

# The tags identifying a repository in the rolodex are assigned
# implicitly, as the index in the rolodex

# The in-memory structure is a Tcl list, with the TOP of the rolodex
# at the end (push == lappend)

# # ## ### ##### ######## ############# ######################

package require Tcl 8.5
package require m::state
package require debug
package require debug::caller

# # ## ### ##### ######## ############# ######################

namespace eval ::m {
    namespace export  rolodex
    namespace ensemble create
}
namespace eval ::m::rolodex {
    namespace export  top next size push drop swap get \
	commit truncate id
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################

debug level  m/rolodex
debug prefix m/rolodex {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::m::rolodex::top {} {
    debug.m/rolodex {}
    Load ; variable current
    set res [lindex $current end]
    debug.m/rolodex { => ($res) }
    return $res
}

proc ::m::rolodex::next {} {
    debug.m/rolodex {}
    Load ; variable current
    set res [lindex $current end-1]
    debug.m/rolodex { => ($res) }
    return $res
}


proc ::m::rolodex::size {} {
    debug.m/rolodex {}
    Load ; variable current
    set limit [m state limit]
    if {!$limit} { set limit 25 }
    return [expr {min($limit,[llength $current])}]
}

proc ::m::rolodex::push {repo} {
    debug.m/rolodex {}
    Load ; variable current ; Unmap
    Drop $repo
    lappend current $repo
    debug.m/rolodex {rolodex = ($current)}
    return
}

proc ::m::rolodex::drop {repo} {
    debug.m/rolodex {}
    Load ; variable current ; Unmap
    Drop $repo
    return
}

proc ::m::rolodex::swap {} {
    debug.m/rolodex {}
    Load ; variable current ; Unmap
    push [lindex $current end-1]
    return
}

proc ::m::rolodex::get {} {
    debug.m/rolodex {}
    Load ; variable current
    return $current
}

proc ::m::rolodex::truncate {} {
    debug.m/rolodex {}
    Load
    Save
    Unmap
    return
}

proc ::m::rolodex::id {repo} {
    debug.m/rolodex {}
    Load ; variable current ; variable map
    if {[llength $current] && ![dict size $map]} {
	Save
	set id -1
	foreach r $current {
	    incr id
	    dict set map $r $id
	}
    }
    if {![dict size $map]} return
    if {[dict exists $map $repo]} {
	return [dict get $map $repo]
    }
    return
}


proc ::m::rolodex::commit {} { Save }

# # ## ### ##### ######## ############# ######################
## In-memory state

namespace eval ::m::rolodex {
    variable loaded  0
    variable extern  {}
    variable current {}
    variable map     {}
}

# # ## ### ##### ######## ############# ######################
## Helpers

proc ::m::rolodex::Unmap {} {
    variable map {}
}

proc ::m::rolodex::Drop {repo} {
    debug.m/rolodex {}
    variable current
    set pos [lsearch -exact $current $repo]
    if {$pos >= 0} {
	set current [lreplace [K $current [unset current]] $pos $pos]
    }
    debug.m/rolodex {rolodex = ($current)}
    return
}

proc ::m::rolodex::K {x y} { set x }

proc ::m::rolodex::Load {} {
    variable loaded
    if {$loaded} {
	debug.m/rolodex { Skip }
	return
    }
    debug.m/rolodex { Pull }
    variable extern
    variable current

    set extern [m db eval {
	SELECT repository
	FROM   rolodex
	ORDER BY id ASC
    }]
    set current $extern
    set loaded 1
    return
}

proc ::m::rolodex::Save {} {
    debug.m/rolodex {}

    # Skip write-back if rolodex was not used at all
    variable loaded
    if {!$loaded} {
	debug.m/rolodex { Skip (Not Loaded) }
	return
    }

    # Skip write-back if no actual changes were made.
    # Note! Compare post truncation to limit.

    variable extern
    variable current

    set limit [m state limit]
    if {!$limit} { set limit 25 }
    if {[llength $current] > $limit} {
	# limit => end-(limit-1)
	# Ex: 2 => end-1
	incr limit -1
	set current [lrange $current end-$limit end]
	debug.m/rolodex {rolodex = ($current)}
    }

    if {$extern eq $current} {
	debug.m/rolodex { Skip (No Change) }
	return
    }

    append sql "DELETE FROM rolodex"

    if {[llength $current]} {
    	append sql ";\nINSERT INTO rolodex\n"
	# Save new state
	set id -1
	set prefix "VALUES "
	foreach r $current {
	    incr id
	    append sql "$prefix ($id, $r)\n"
	    set prefix ",      "
	}
    }

    debug.m/rolodex {-- [join [split $sql \n] "\n-- "]}
    m db eval $sql

    set extern $current
    debug.m/rolodex { Done }
    return
}


# # ## ### ##### ######## ############# ######################
package provide m::rolodex 0
return
