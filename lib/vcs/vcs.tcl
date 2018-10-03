## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## Version Control Systems - Core

# @@ Meta Begin
# Package m::vcs 0 
# Meta author   {Andreas Kupries}
# Meta location https://core.tcl.tk/akupries/????
# Meta platform tcl
# Meta summary     Version control core
# Meta description Version control core
# Meta subject    {version control - core}
# Meta require {Tcl 8.5-}
# @@ Meta End

package provide m::vcs 0

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require m::vcs::fossil
package require m::vcs::git
package require m::db
package require debug
package require debug::caller

# # ## ### ##### ######## ############# ######################

debug level  m/vcs
debug prefix m/vcs {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval ::m {
    namespace export vcs
    namespace ensemble create
}

namespace eval ::m::vcs {
    namespace export \
	setup cleanup update check split merge \
	id supported list detect code name url-norm name-from-url
    namespace ensemble create
}

# # ## ### ##### ######## ############# #####################

proc ::m::vcs::setup {vcode name url} {
    lassign [ToPath $vcode $name] path dir

    # Ensure clean new environment
    file delete -force -- $path
    file mkdir            $path
    
    m::vcs::${vcode} setup $path $url
    return $dir
}

proc ::m::vcs::cleanup {vcode dir} {
    set path [Path $dir]
    
    # Release vcs specific special resources ...
    m::vcs::${vcode} cleanup $path

    # ... and the store directory
    file delete -force -- $path
    return 
}

# # ## ### ##### ######## ############# #####################

proc ::m::vcs::detect {url} {
    debug.m/vcs {}
    if {[string match *git* $url]} {
	return git
    }
    return fossil
}

proc ::m::vcs::url-norm {url} {
    # Normalize the incoming url
    # I.e. for a number of known sites, force the use of the https
    # they support.

    lappend map http://github.com    https://github.com
    lappend map http://chiselapp.com https://chiselapp.com
    lappend map http://core.tcl.tk   https://core.tcl.tk

    return [string map $map $url]
}

proc ::m::vcs::name-from-url {vcode url} {
    debug.m/vcs {}
    # strip schema, host, user, pass ...
    # strip trailing bogus things ... (fossil specific)

    set gh [string match *github* $url]
    set gl [string match *gitlab* $url]
    
    regsub -- {https://}    $url {} url
    regsub -- {http://}     $url {} url
    regsub -- {git@github:} $url {} url

    switch -exact -- $vcode {
	fossil {
	    regsub -- {/index$}  $url {} url
	    regsub -- {/timeline$}  $url {} url
	    return [lindex [file split $url] end]
	}
	git {
	    if {$gh} {
		return [join [lrange [file split $url] end-1 end] /]@gh
	    } elseif {$gl} {
		return [join [lrange [file split $url] end-1 end] /]@gl
	    } else {
		return [lindex [file split $url] end]
	    }
	}
    }
}

# # ## ### ##### ######## ############# #####################

proc ::m::vcs::code {id} {
    debug.m/vcs {}
    return [m db onecolumn {
	SELECT code
	FROM   version_control_system
	WHERE  id = :id
    }]
}

proc ::m::vcs::name {id} {
    debug.m/vcs {}
    return [m db onecolumn {
	SELECT name
	FROM   version_control_system
	WHERE  id = :id
    }]
}

proc ::m::vcs::list {} {
    debug.m/vcs {}
    return [m db eval {
	SELECT code
	,      name
	FROM   version_control_system
	ORDER BY name ASC
    }]
}

proc ::m::vcs::supported {} {
    debug.m/vcs {}
    lappend r [m db eval {
	SELECT code
	FROM   version_control_system
    }]
    lappend r [m db eval {
	SELECT name
	FROM   version_control_system
    }]
    return [lsort -dict $r]
}

proc ::m::vcs::id {x} {
    debug.m/vcs {}
    set id [m db onecolumn {
	SELECT id
	FROM   version_control_system
	WHERE  code = :x
    }]

    if {$id eq {}} {
	set id [m db onecolumn {
	    SELECT id
	    FROM   version_control_system
	    WHERE  name = :x
	}]
    }

    if {$id eq {}} {
	return -code error "Invalid vcs code or name"
    }

    return $id
}

# # ## ### ##### ######## ############# #####################

proc ::m::vcs::ToPath {vcode name} {
    set dir [file join $vcode [string map {: %3a / %2f} $name]]
    return [::list [Path $dir] $dir]
}

proc ::m::vcs::Path {dir} {
    return [file normalize [file join [m state store] $dir]]
}

# # ## ### ##### ######## ############# #####################
return
