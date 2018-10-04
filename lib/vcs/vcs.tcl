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
package require fileutil
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
	id supported list detect code name \
	url-norm name-from-url rename
    namespace ensemble create
}

# # ## ### ##### ######## ############# #####################

proc ::m::vcs::setup {vcode name url store} {
    debug.m/vcs {}
    # name - mset name
    # url  - repo url
    # store id -> Using for path.

    set path [Path $store]

    # Ensure clean new environment
    file delete -force -- $path
    file mkdir            $path

    fileutil::writeFile $path/name $name
    fileutil::writeFile $path/url  $url
    fileutil::writeFile $path/vcs  $vcode
    
    m::vcs::${vcode} setup $path $url
    return
}

proc ::m::vcs::rename {store name} {
    debug.m/vcs {}

    set path [Path $store]
    fileutil::writeFile $path/name $name
    return
}

proc ::m::vcs::cleanup {vcode store} {
    debug.m/vcs {}
    set path [Path $store]
    
    # Release vcs specific special resources ...
    m::vcs::${vcode} cleanup $path

    # ... and the store directory
    file delete -force -- $path
    return 
}

proc ::m::vcs::check {vcode primary secondary} {
    debug.m/vcs {}
    set p [Path $primary]
    set s [Path $secondary]
    
    return [m::vcs::${vcode} check $p $s]
}

proc ::m::vcs::merge {vcode primary secondary} {
    debug.m/vcs {}
    set p [Path $primary]
    set s [Path $secondary]
    
    m::vcs::${vcode} merge $p $s
    cleanup $vcode $secondary
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

proc ::m::vcs::url-norm {vcode url} {
    # Normalize the incoming url
    # I.e. for a number of known sites, force the use of the https
    # they support. Further strip known irrelevant trailers.

    lappend map http://github.com    https://github.com
    lappend map http://chiselapp.com https://chiselapp.com
    lappend map http://core.tcl.tk   https://core.tcl.tk

    if {$vcode eq "fossil"} {
	regsub -- {/index$}    $url {} url
	regsub -- {/timeline$} $url {} url
    }
    
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

proc ::m::vcs::Path {dir} {
    return [file normalize [file join [m state store] $dir]]
}

# # ## ### ##### ######## ############# #####################
return
