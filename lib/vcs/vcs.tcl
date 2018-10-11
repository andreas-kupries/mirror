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

# TODO: vcs/plugin extension - extract size
# TODO: vcs/plugin extension - extract description

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require cmdr::color
package require m::db
package require m::state
package require m::exec
package require m::vcs::fossil
package require m::vcs::git
package require m::vcs::github
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
	rename id supported list code name \
	detect url-norm name-from-url issues
    namespace ensemble create

    namespace import ::cmdr::color
}

# # ## ### ##### ######## ############# #####################

proc ::m::vcs::setup {store vcs name url} {
    debug.m/vcs {}
    # store id -> Using for path.
    # vcs   id -> Decode to plugin name
    # name     -  mset name
    # url      -  repo url
    set path  [Path $store]
    set vcode [code $vcs]

    # Ensure clean new environment
    file delete -force -- $path
    file mkdir            $path

    fileutil::writeFile $path/%name $name  ;# Mirror set
    fileutil::writeFile $path/%vcs  $vcode ;# Manager

    # Create vcs-specific special resources, if any
    $vcode setup $path $url
    return
}

proc ::m::vcs::update {store vcs urls} {
    debug.m/vcs {}
    # store id -> Using for path.
    # vcs   id -> Decode to plugin name
    # urls     -  repo urls to use as sources
    set path  [Path $store]
    set vcode [code $vcs]

    return [$vcode update $path $urls]
}

proc ::m::vcs::rename {store name} {
    debug.m/vcs {}
    # store id -> Using for path.
    # name     -  new mset name
    set path [Path $store]
    fileutil::writeFile $path/%name $name
    return
}

proc ::m::vcs::cleanup {store vcs} {
    debug.m/vcs {}
    # store id -> Using for path.
    # vcs   id -> Decode to plugin name
    set path [Path $store]
    set vcode [code $vcs]

    # TODO MAYBE: check vcode against contents of $path/%vcs.
    
    # Release vcs-specific special resources, if any
    $vcode cleanup $path

    # ... and the store directory
    file delete -force -- $path
    return 
}

proc ::m::vcs::check {vcs storea storeb} {
    debug.m/vcs {}
    set patha [Path $storea]
    set pathb [Path $storeb]
    set vcode [code $vcs]

    # Check if the two stores are mergable
    return [$vcode check $patha $pathb]
}

proc ::m::vcs::merge {vcs target origin} {
    debug.m/vcs {}
    set ptarget [Path $target]
    set porigin [Path $origin]
    set vcode   [code $vcs]

    # Merge vcs specific special resources, if any ...
    $vcode merge $ptarget $porigin

    # Destroy the merged store
    cleanup $origin $vcs
    return
}

proc ::m::vcs::split {vcs origin dst dstname} {
    debug.m/vcs {}
    set pdst    [Path $dst]
    set porigin [Path $origin]
    set vcode   [code $vcs]
    
    # Ensure clean copy
    file delete -force -- $pdst
    file copy   -force -- $porigin $pdst

    # Inlined rename of origin's new copy
    fileutil::writeFile $pdst/%name $dstname
    
    # Split/create vcs specific special resources, if any ...
    $vcode split $porigin $pdst
    return
}

# # ## ### ##### ######## ############# #####################

proc ::m::vcs::issues {vcode} {
    debug.m/vcs {}
    return [$vcode issues]
}

proc ::m::vcs::detect {url} {
    debug.m/vcs {}

    # Note: Ordering is important.
    # Capture specific things first (github)
    # Least specific (fossil) is last.

    github detect $url
    git    detect $url
    fossil detect $url

    return -code error "Unable to determine vcs for $url"
}

proc ::m::vcs::url-norm {vcode url} {
    # Normalize the incoming url
    # I.e. for a number of known sites, force the use of the https
    # they support. Further strip known irrelevant trailers.

    lappend map git@github.com:      https://github.com/
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

    lappend map "https://"        {}
    lappend map "http://"         {}
    lappend map "git@github.com:" {}

    set url [string map $map $url]
    
    switch -glob -- $vcode {
	fossil {
	    regsub -- {/index$}    $url {} url
	    regsub -- {/timeline$} $url {} url
	    return [lindex [file split $url] end]
	}
	git* {
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
