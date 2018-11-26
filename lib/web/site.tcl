## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## Site generation

# @@ Meta Begin
# Package m::web::site 0 
# Meta author   {Andreas Kupries}
# Meta location https://core.tcl.tk/akupries/????
# Meta platform tcl
# Meta summary     Static assets of the web site
# Meta description Static assets of the web site
# Meta subject     {web site} {site assets}
# Meta require {Tcl 8.5-}
# @@ Meta End

package provide m::web::site 0

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require debug
package require debug::caller
package require m::asset
package require m::exec
package require m::futil
package require m::state
package require m::mset
package require m::vcs
package require m::store

# # ## ### ##### ######## ############# ######################

debug level  m/web/site
debug prefix m/web/site {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval ::m {
    namespace export web
    namespace ensemble create
}

namespace eval ::m::web {
    namespace export site
    namespace ensemble create
}

namespace eval ::m::web::site {
    namespace export build
    namespace ensemble create
}

# # ## ### ##### ######## ############# #####################

proc ::m::web::site::build {{mode verbose}} {
    debug.m/web/site {}
    Site $mode Generating {
	Init
	! "= Data dependent content ..."
	Contact
	Export		;# (See `export`)
	Stores

	set bytime [m store updates]
	set byname [m store by-name]
	set bysize [m store by-size]
	set byvcs  [m store by-vcs]
	set issues [ErrOnly [NameFill [DropSep $byname]]]

	dict set stats issues  [set n [llength $issues]]
	dict set stats size    [m store total-size]
	dict set stats nrepos  [m repo count]
	dict set stats nmsets  [m mset count]
	dict set stats nstores [m store count]

	List "By Last Change"     index.md      $bytime $stats
	List "By Name, VCS, Size" index_name.md $byname $stats
	List "By Size, Name, VCS" index_size.md $bysize $stats
	List "By VCS, Name, Size" index_vcs.md  $byvcs  $stats

	if {$n} {
	    List "Issues by Name" index_issues.md $issues $stats
	}
	
	# + TODO: submissions pending, submission responses, past rejections

	Fin
    }
    return
}

# # ## ### ##### ######## ############# #####################

proc ::m::web::site::ErrOnly {series} {
    debug.m/web/site {}
    set tmp {}
    foreach row $series {
	set img [SI [lindex [m vcs caps [dict get $row store]] 1]]
	if {$img eq {}} continue
	lappend tmp $row
    }
    return $tmp
}

proc ::m::web::site::NameFill {series} {
    debug.m/web/site {}
    set tmp {}
    set last {}
    foreach row $series {
	set name [dict get $row mname]
	if {$name ne {}} { set name $last }
	dict set row mname $name
	set last $name
	lappend tmp $row
    }
    return $tmp
}

proc ::m::web::site::DropSep {series} {
    debug.m/web/site {}
    set tmp {}
    foreach row $series {
	if {[dict get $row created] eq "."} continue
	lappend tmp $row
    }
    return $tmp
}

proc ::m::web::site::Site {mode action script} {
    debug.m/web/site {}

    set path [m state site-store]
    m msg "$action $path"
    variable dst    $path/web
    variable silent [string equal $mode silent]
    uplevel 1 $script
    unset dst silent
    return
}

proc ::m::web::site::Stores {} {
    debug.m/web/site {}
    foreach {mset mname} [m mset list] {
	foreach store [m mset stores $mset] {
	    Store $mset $mname $store
	}
    }
    return
}

proc ::m::web::site::Store {mset mname store} {
    debug.m/web/site {}

    # Get page pieces ...

    lassign [m store remotes $store] remotes plugin
    lappend r Remotes $remotes
    if {[llength $plugin]} {
	lappend r {*}$plugin
    }

    set sd  [m store get $store]
    dict with sd {}
    # -> size
    #    vcs
    #    vcsname
    #    created
    #    changed
    #    updated
    lassign [m vcs caps $store] stdout stderr
    set logo [T Stdout $stdout]
    set loge [T Stderr $stderr]
    set simg [SI $stderr]

    set export [m vcs export $vcs $store]
    if {$export ne {}} {
	set f external/local_${store}
	WX static/$f $export
	set export [L $f {Local Site}]
    }

    # Assemble page ...

    append text [H $mname]

    append text |||| \n
    append text |---|---|---| \n

    R $simg   {} $vcsname
    R Size    {} [m::glue::Size $size]
    if {$export ne {}} {
	R {} {} $export
    }
    R {Last Check}  {} [m::glue::Date $updated]
    R {Last Change} {} [m::glue::Date $changed]
    R Created       {} [m::glue::Date $created]

    set active 1
    foreach {label urls} $r {
	R $label {}
	foreach url [lsort -dict $urls] {
	    incr id
	    set u [L $url $url]
	    set a {}
	    if {$active} {
		set a [dict get	[m repo get [m repo id $url]] active]
		if {$a} {
		    set a "" ;#[I images/ok.svg "&nbsp;"]
		} else {
		    set a [I images/off.svg "-"]
		}
	    }
	    R ${id}. $a $u
	}
	unset -nocomplain id
	incr active -1
    }
    append text \n

    append text "## Traces" \n\n
    append text $logo \n
    append text $loge \n
    append text \n
    append text [F]
    W pages/store_${store}.md $text
    return
}

proc ::m::web::site::Contact {} {
    debug.m/web/site {}
    append text [H Contact]
    append text [F]
    W pages/contact.md $text
    return
}

proc ::m::web::site::List {suffix page series stats} {
    debug.m/web/site {}

    dict with stats {}
    # issues
    # size
    # nrepos
    # nmsets
    # nstores
    
    append text [H "Index ($suffix)"]
    
    set hvcs   [L index_vcs.html    VCS          ]
    set hsize  [L index_size.html   Size         ]
    set hname  [L index_name.html   {Mirror Set} ]
    set hchan  [L index.html        Changed      ]

    if {$issues} {
	set issues [L index_issues.html "Issues: $issues" ]
    } else {
	set issues {}
    }

    append text "Sets: $nmsets"
    append text " Repos: $nrepos"
    append text " Stores: $nstores"
    append text " Size: [m::glue::Size $size]"
    append text " $issues" \n
    append text \n

    append text "||$hname|$hvcs|$hsize|$hchan|Updated|Created|" \n
    append text "|---|---|---|---:|---|---|---|" \n

    set mname {}
    set last {}
    foreach row $series {
	dict with row {}
	# store mname vcode changed updated created size active remote
	
	if {$created eq "."} {
	    append text "||||||||" \n
	    continue
	}

	set img [SI [lindex [m vcs caps $store] 1]]
	if {$img eq {}} {
	    if {!$active} {
		set img [I images/off.svg "-"]
	    } elseif {$active < $remote} {
		set img [I images/yellow.svg "/"]
	    }
	}
	
	set size    [m::glue::Size $size]
	set changed [m::glue::Date $changed]
	set updated [m::glue::Date $updated]
	set created [m::glue::Date $created]
       	set vcode   [L store_${store}.html $vcode]
	if {$mname ne {}} {
	    set mname [L store_${store}.html $mname]
	}
	append text "|$img|$mname|$vcode|$size|$changed|$updated|$created|" \n
	set last $mname
    }
    append text \n\n

    append text [F]
    W pages/$page $text
    return
}

proc ::m::web::site::Export {} {
    debug.m/web/site {}
    W static/external/spec.txt [m mset spec]
    return
}

proc ::m::web::site::Init {} {
    debug.m/web/site {}
    variable self
    variable dst

    ! "= Clearing web, web_out ..."
    file delete -force $dst ${dst}_out

    ! "= SSG setup web ..."
    SSG init           $dst ${dst}_out

    ! "= Customize web ..."
    foreach child {
	static/images/.placeholder
	pages/blog
	pages/contact.md
	pages/index.md
    } {
	D $child
    }
    dict for {child content} [m asset get $self] {
	W $child $content
    }
    return
}

proc ::m::web::site::Fin {} {
    debug.m/web/site {}
    variable dst
    ! "= SSG build web ..."
    SSG build $dst ${dst}_out
    return
}

proc ::m::web::site::SI {stderr} {
    if {![string length $stderr]} {
	return {}
	set status images/ok.svg
	set stext  OK
    } else {
	set status images/bad.svg
	set stext  ATTEND
    }
    return [I $status $stext]
}

proc ::m::web::site::I {url {alt {}}} {
    debug.m/web/site {}
    return "<img src='$url' alt='$alt'>"
}

proc ::m::web::site::L {url {label {}}} {
    debug.m/web/site {}
    if {$label eq {}} { set label $url }
    return "\[$label]($url)"
}

proc ::m::web::site::R {args} {
    debug.m/web/site {}
    upvar 1 text text
    append text |[join $args "|"]| \n
    return
}

proc ::m::web::site::T {label text} {
    if {$text eq ""} { return "" }
    append t $label \n\n
    append t "```" \n
    append t [string trim $text] \n
    append t "```" \n
    return $t
}

proc ::m::web::site::H {title} {
    debug.m/web/site {}
    append f "\{" \n
    append f "    title \{$title\}" \n
    append f "\}" \n\n
    return $f
}

proc ::m::web::site::F {} {
    debug.m/web/site {}
    append f "# Contact information" \n
    append f \n
    append f "Mail to [L mailto:@-mail-@ @-management-@]"
    return $f
}

proc ::m::web::site::D {child} {
    debug.m/web/site {}
    variable dst

    ! "  - $child"
    file delete -force $dst/$child
    return
}

proc ::m::web::site::WX {child content} {
    debug.m/web/site {}
    file attributes [W $child $content] -permissions u=rwx,go=r
    return
}

proc ::m::web::site::W {child content} {
    debug.m/web/site {}
    variable dst
    set dstfile [file join $dst $child]

    ! "  + $child"
    file mkdir [file dirname $dstfile]
    m futil write $dstfile [string map [M] $content]
    return $dstfile
}

proc ::m::web::site::M {} {
    debug.m/web/site {}

    set u [m state site-url]
    if {![string match */ $u]} { append u / }

    set logo [m state site-logo]

    if {$logo ne {}} {
	if {[file exists $logo]} {
	    variable dst
	    set fname [file tail $logo]
	    file copy $logo $dst/static/images/$fname
	    set logo images/$fname
	}

	set logo "<img src='$logo' style='height: 33px; margin-top: -10px;'>"
    }

    lappend map @-logo-@       $logo
    lappend map @-mail-@       [m state site-mgr-mail]
    lappend map @-management-@ [m state site-mgr-name]
    lappend map @-nav-@        {
	Contact        $rootDirPath/contact.html
	{Content Spec} $rootDirPath/external/spec.txt
    }
    lappend map @-title-@      [m state site-title]
    lappend map @-url-@        $u
    lappend map @-year-@       [clock format [clock seconds] -format %Y]
    proc ::m::web::site::M {} [list return $map]
    return $map
}

proc ::m::web::site::! {text} {
    variable silent
    if {$silent} return
    m msg $text
    return
}

proc ::m::web::site::SSG {args} {
    debug.m/web/site {}
    m exec go ssg {*}$args
    return
}

# # ## ### ##### ######## ############# #####################
## State

namespace eval ::m::web::site {
    variable self [file normalize [info script]]
}

# # ## ### ##### ######## ############# #####################
return
## Site assets follow ...
pages/disclaimer.md

This is the disclaimer and copyright.
website.confwebsiteTitle {@-title-@}
copyright    {<a href="$rootDirPath/disclaimer.html">Copyright &copy;</a> @-year-@ <a href='mailto:@-mail-@'>@-management-@</a>}
url          {@-url-@}
description  {@-title-@}

sitemap { enable 1 }
rss     { enable 0 tagFeeds 0 }
indexPage {index.md}
outputDir {../output}
blogPostsPerFile 0

pageSettings {
    navbarBrand {<div class="pull-left"> @-logo-@ @-title-@</div>}
    favicon     images/favicon.png
    sidebarNote {}
    navbarItems {@-nav-@}
    gridClassPrefix col-md-
    contentColumns 8
    locale en_US
    hideUserComments 1
    hideSidebarNote 1
    sidebarPosition right
    bootstrapTheme {$rootDirPath/external/bootstrap-3.3.1-dist/css/bootstrap-theme.min.css}
    customCss {{$rootDirPath/tclssg.css}}
}
deployCustom {
    start {}
    file  {}
    end   {}
}
enableMacrosInPages 0
comments {
    engine none
    disqusShortname {}
}
static/images/ok.svg<svg xmlns="http://www.w3.org/2000/svg"
     xmlns:xlink="http://www.w3.org/1999/xlink"
     width='32'
     height='32'
     viewBox='0 0 100 100'>
  <circle cx='50' cy='50' r='40' fill='green'/>
</svg>
static/images/bad.svg<svg xmlns="http://www.w3.org/2000/svg"
     xmlns:xlink="http://www.w3.org/1999/xlink"
     width='32'
     height='32'
     viewBox='0 0 100 100'>
  <circle cx='50' cy='50' r='40' fill='red'/>
</svg>
static/images/off.svg<svg xmlns="http://www.w3.org/2000/svg"
     xmlns:xlink="http://www.w3.org/1999/xlink"
     width='32'
     height='32'
     viewBox='0 0 100 100'>
  <circle cx='50' cy='50' r='40' fill='black'/>
</svg>
static/images/yellow.svg<svg xmlns="http://www.w3.org/2000/svg"
     xmlns:xlink="http://www.w3.org/1999/xlink"
     width='32'
     height='32'
     viewBox='0 0 100 100'>
  <circle cx='50' cy='50' r='40' fill='yellow'/>
</svg>
