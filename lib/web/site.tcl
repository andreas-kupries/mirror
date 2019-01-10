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
package require m::db
package require m::exec
package require m::format
package require m::futil
package require m::mset
package require m::site
package require m::state
package require m::store
package require m::vcs

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
    namespace export build sync
    namespace ensemble create
}

# # ## ### ##### ######## ############# #####################

proc ::m::web::site::sync {} {
    debug.m/web/site {}

    m::site transaction {
	Sync
    }

    return
}

proc ::m::web::site::build {{mode verbose}} {
    debug.m/web/site {}
    Site $mode Generating {
	Init
	! "= Data dependent content ..."
	Contact
	Export		;# (See `export`)
	Search
	Submit
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
	if {$name eq {}} { set name $last }
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
    foreach {mset mname} [m mset all] {
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
    set logo [T "Operation" $stdout]
    set loge [T "Notes & Errors" $stderr]
    set simg [SI $stderr]

    set export [m vcs export $vcs $store]
    if {$export ne {}} {
	set f external/local_${store}
	WX static/$f $export
	set export [LB $f {Local Site}]
    }

    # Assemble page ...

    append text [H $mname]

    append text |||| \n
    append text |---|---|---| \n

    R $simg   {} "[IH 32 images/logo/[m vcs code $vcs].svg $vcsname] $vcsname"
    R Size    {} [m format size $size]
    if {$export ne {}} {
	R {} {} $export
    }
    R {Last Check}  {} [set lc [m format epoch $updated]]
    R {Last Change} {} [m format epoch $changed]
    R Created       {} [m format epoch $created]

    set active 1
    foreach {label urls} $r {
	R $label {}
	foreach url [lsort -dict $urls] {
	    incr id
	    set u [LB $url $url]
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

    append text "## Messages as of last check on $lc" \n\n
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
    append text " Size: [m format size $size]"
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

	set size    [m format size $size]
	set changed [m format epoch $changed]
	set updated [m format epoch $updated]
	set created [m format epoch $created]

	set vcode   "[IH 32 images/logo/${vcode}.svg $vcode] $vcode"
       	set vcode   [LB store_${store}.html $vcode]
	
	if {$mname ne {}} {
	    set mname [LB store_${store}.html $mname]
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
    W static/spec.txt [m mset spec]
    return
}

proc ::m::web::site::Search {} {
    debug.m/web/site {}
    WX static/search [CGI mirror-search]
    return
}

proc ::m::web::site::Submit {} {
    debug.m/web/site {}
    WX static/submit [CGI mirror-submit]
    return
}

proc ::m::web::site::CGI {app} {
    debug.m/web/site {}
    global argv0

    # With respect to locations
    # - The CGI apps are siblings of the manager cli.
    # - The CGI database is a sibling of the main database.
    #   See `Sync` here for the code keeping it up-to-date.
    #   However note that `m::site` automaitcally goes for the sibling
    #   given the path to the main, so we do not do this here.
    
    set bindir [file dirname $argv0]    
    append t "#![file normalize [file join $bindir $app]]" \n
    append t "database: [m::db::location get]" \n
    return $t
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

proc ::m::web::site::Fin {} { #return
    debug.m/web/site {}
    variable dst
    ! "= SSG build web ..."
    SSG build $dst ${dst}_out

    # dst     = path/web     = site input
    # dst_out = path/web_out = site stage
    #           path/site    = site serve

    set stage ${dst}_out
    set serve [file join [file dirname $dst] site]

    ! "= Sync and flip stage to serve"

    # Allow for 10 second transactions from the CGI helpers before
    # giving up.
    m::site::wait 10
    m::site transaction {
	Sync
	file delete -force ${serve}_last
	if {[file exists $serve]} {
	    file rename $serve ${serve}_last
	}
	file rename $stage $serve
    }
    return
}

proc ::m::web::site::Sync {} {
    debug.m/web/site {}

    # Data flows
    # - Main
    #   - mset_pending			local, no sync
    #   - reply				local, no sync
    #   - rolodex			local, no sync
    #   - schema			local, no sync
    #
    #   - mirror_set			[1] join/view pushed to site
    #   - name				[1] store_index, total replacement
    #   - repository			[1]
    #   - store				[1]
    #   - store_times			[1]
    #   - version_control_system	[1], plus copy to vcs
    #
    #   - rejected			push to site rejected, total replacement
    #   - submission			pull from site (insert or update)
    #   - submission_handled		push to site, deletions in submission
    #
    # - Site
    #   - cache_desc	local, no sync
    #   - cache_url	local, no sync
    #   - schema	local, no sync
    #
    #   - rejected	pulled from main rejected, total replacement
    #   - store_index	pulled from main [1], total replacement
    #
    #   - submission	pulled deletions from main (submission_handled)
    #			push remaining to main (insert or update)
    
    FillIndex
    FillRejected
    SyncSubmissions
    return
}

proc ::m::web::site::SyncSubmissions {} {
    debug.m/web/site {}

    # Syncing the submissions is easier than originally
    # thought. Because the flow is more restricted than thought, due
    # to the use of sessions.

    # 1. Submissions from CGI flow through site to main. Only
    #    deletions flow back, as the cli handles them in main.
    
    # 2. Submissions done in main, via the cli, have their own format
    #    for session identifiers which cannot overlap with sessions
    #    from the CGI. As such there is no need to push them to site,
    #    CGI will has no use for them when looking for pre-existing
    #    submissions. Anything needed there comes into site through
    #    the index and rejection tables.
    
    DropHandledSubmissions
    GetNewSubmissions
    return
}

proc ::m::web::site::GetNewSubmissions {} {
    debug.m/web/site {}
    m msg "- Pull new submissions"

    # Phase II of syncing submissions between main and site.

    # Iterate over all the submissions in site. Update the entries in
    # main, or create new entries for them. It is the same logic
    # mirror-submit uses for the site database to distinguish and
    # perform add or edit (insert / update). Except this crosses two
    # databases.

    m site eval {
	SELECT session
	,      url
	,      vcode
	,      description
	,      email
	,      submitter
	,      when_submitted
	FROM submission
    } {
	if {[m db onecolumn {
	    SELECT count (*)
	    FROM  submission
	    WHERE url     = :url
	    AND   session = :session
	}]} {
	    # exists, update
	    m db eval {
		UPDATE submission
		SET vcode       = :vcode
		,   description = :description
		,   email       = :email
		,   submitter   = :submitter
		,   sdate       = :when_submitted
		WHERE url     = :url
		AND   session = :session
	    }
	} else {
	    # not known, insert
	    m db eval {
		INSERT
		INTO submission
		VALUES ( NULL, :session, :url, :vcode,
			 :description, :email, :submitter,
			 :when_submitted )
	    }
	}
    }
    
    return
}

proc ::m::web::site::DropHandledSubmissions {} {
    debug.m/web/site {}
    m msg "- Remove handled submissions"

    # Phase I of syncing submissions between main and site.

    # Iterate over all the submissions marked as handled in main and
    # remove them from site. From the main helper table also.

    m db eval {
	SELECT url
	,      session
	FROM submission_handled
    } {
	m site eval {
	    DELETE
	    FROM submission
	    WHERE url     = :url
	    AND   session = :session
	}
    }

    m db eval {
	DELETE
	FROM submission_handled
    }
    
    return
}

proc ::m::web::site::FillRejected {} {
    debug.m/web/site {}
    m msg "- Push rejections"

    # Copy current state of url rejections from main to site database.
    # Implemented as `delete all old ; insert all new`.
    
    m site eval { DELETE FROM rejected }
    
    m db eval {
	SELECT url
	,      reason
	FROM rejected
    } {
	m site eval {
	    INSERT
	    INTO rejected
	    VALUES ( NULL, :url, :reason )
	}
    }
    return
}

proc ::m::web::site::FillIndex {} {
    debug.m/web/site {}
    m msg "- Push index"

    # Copy current state of known stores and remotes from main to site
    # database. Implemented as `delete all old ; insert all new`.

    m site eval { DELETE FROM store_index }

    # m store search '' (inlined, simply all)
    m db eval {
	SELECT S.id      AS store
	,      N.name    AS mname
	,      V.code    AS vcode
	,      T.changed AS changed
	,      T.updated AS updated
	,      T.created AS created
	,      S.size_kb AS size
	,      (SELECT count (*)
		FROM  repository R
		WHERE R.mset = S.mset
		AND   R.vcs  = S.vcs) AS remote
	,      (SELECT count (*)
		FROM  repository R
		WHERE R.mset = S.mset
		AND   R.vcs  = S.vcs
		AND   R.active) AS active
	FROM store_times            T
	,    store                  S
	,    mirror_set             M
	,    version_control_system V
	,    name                   N
	WHERE T.store   = S.id
	AND   S.mset    = M.id
	AND   S.vcs     = V.id
	AND   M.name    = N.id
    } {
	# store, mname, vcode, changed, updated, created, size, remote, active

	set page    store_${store}.html
	set status  [Status $store $active $remote]
	set remotes [m db eval {
	    SELECT R.url
	    FROM repository R
	    ,    store      S
	    WHERE S.id   = :store
	    AND   S.vcs  = R.vcs
	    AND   S.mset = R.mset
	}]
	
	lappend remotes $mname
	set remotes [string tolower [join $remotes { }]]
	# We are using the remotes field for the entire text we can
	# search over.  Should rename the field, not bothering until
	# we need a larger schema change it can be folded into.

	m site eval {
	    INSERT
	    INTO store_index
	    VALUES ( NULL,
		     :mname, :vcode, :page, :remotes, :status,
		     :size, :changed, :updated, :created )
	}
    }

    # Copy the VCS information

    m site eval { DELETE FROM vcs }

    m db eval {
	SELECT id
	,      code
	,      name
	FROM version_control_system
    } {
	m site eval {
	    INSERT
	    INTO vcs
	    VALUES ( :id, :code, :name )
	}
    }
    return
}

proc ::m::web::site::Status {store active remote} {
    debug.m/web/site {}

    set stderr [lindex [m vcs cap $store] 1]
    if {[string length $stderr]} {
	return bad.svg
    } elseif {!$active} {
	return off.svg
    } elseif {$active < $remote} {
	return yellow.svg
    } else {
	return {}
    }
}
    
proc ::m::web::site::SI {stderr} {
    debug.m/web/site {}
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

proc ::m::web::site::IH {h url {alt {}}} {
    debug.m/web/site {}
    return "<img height='$h' src='$url' alt='$alt'>"
}

proc ::m::web::site::L {url {label {}}} {
    debug.m/web/site {}
    if {$label eq {}} { set label $url }
    return "\[$label]($url)"
}

proc ::m::web::site::LB {url {label {}}} {
    debug.m/web/site {}
    if {$label eq {}} { set label $url }
    return "<a target='_blank' href='$url'>$label </a>"
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
	{Content Spec} $rootDirPath/spec.txt
	Search         $rootDirPath/search
	Submit         $rootDirPath/submit
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
static/images/submit.svg<svg width='32' height='32' viewBox='0 0 100 100' xmlns="http://www.w3.org/2000/svg"><circle cx='50' cy='50' r='50' fill='green'/><line x1='15' y1='50' x2='85' y2='50' stroke='white' stroke-width='20'/><line x1='50' y1='15' x2='50' y2='85' stroke='white' stroke-width='20'/></svg>
static/images/logo/git.svg<svg role="img" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><title>Git icon</title><path d="M23.546 10.93L13.067.452c-.604-.603-1.582-.603-2.188 0L8.708 2.627l2.76 2.76c.645-.215 1.379-.07 1.889.441.516.515.658 1.258.438 1.9l2.658 2.66c.645-.223 1.387-.078 1.9.435.721.72.721 1.884 0 2.604-.719.719-1.881.719-2.6 0-.539-.541-.674-1.337-.404-1.996L12.86 8.955v6.525c.176.086.342.203.488.348.713.721.713 1.883 0 2.6-.719.721-1.889.721-2.609 0-.719-.719-.719-1.879 0-2.598.182-.18.387-.316.605-.406V8.835c-.217-.091-.424-.222-.6-.401-.545-.545-.676-1.342-.396-2.009L7.636 3.7.45 10.881c-.6.605-.6 1.584 0 2.189l10.48 10.477c.604.604 1.582.604 2.186 0l10.43-10.43c.605-.603.605-1.582 0-2.187"/></svg>
static/images/logo/github.svg<svg role="img" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><title>GitHub icon</title><path d="M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12"/></svg>
static/images/logo/hg.svg<?xml version="1.0"?>
<svg width="100" height="120"
      xmlns="http://www.w3.org/2000/svg"
      xmlns:xlink="http://www.w3.org/1999/xlink">
  <title>Mercurial</title>
  <defs>
    <g id="hg">
      <path d="
	M 85.685,67.399
	C 100.47,42.815 82.562,2.944 49.818,6.995
	C 20.233,10.652 19.757,41.792 45.83,49.189
	C 68.393,55.597 50.491,69.909 51.014,79.439
	C 51.54,88.968 70.63,92.425 85.685,67.399
	" />
      <circle cx="31.579" cy="70.617" r="12.838"/>
      <circle cx="16.913" cy="43.476" r="8.4" />
    </g>
  </defs>
  <rect width="100" height="120"
	style="fill:#ffffff; stroke:#000000; stroke-width:1.6;" />
  <use xlink:href="#hg" style="fill:#1b1b1b;" />
  <use xlink:href="#hg" style="fill:#bfbfbf;"
       transform="translate(0.559,-0.997)" />
  <path style="fill:#000000;" d="
    M 55.367,82.205
    C 54.471,80.751 55.841,79.137 57.25,79.26
    C 59.492,79.456 64.373,79.233 68.225,77.05
    C 77.847,71.595 92.656,45.348 85.208,28.793
    C 81.874,21.383 80.25,19.261 76.816,15.636
    C 76.116,14.897 76.518,14.937 76.992,15.187
    C 78.849,16.161 82.112,19.936 85.459,26.08
    C 91.114,36.46 90.821,48.8 88.718,56.541
    C 87.253,61.926 82.206,74.109 74.816,79.376
    C 67.41,84.655 58.743,87.683 55.367,82.205
    M 48.662,48.142
    C 43.621,46.646 37.122,44.562 33.363,39.645
    C 30.591,36.019 29.185,32.063 28.825,29.819
    C 28.698,29.018 28.589,28.351 28.82,28.166
    C 28.926,28.081 30.889,32.517 33.823,36.235
    C 36.756,39.954 40.856,42.129 44.272,42.919
    C 47.31,43.621 53.603,45.165 55.732,46.978
    C 57.921,48.843 58.104,52.871 57.367,53.326
    C 56.624,53.783 55.118,50.058 48.662,48.142
    M 24.497,78.973
    C 34.48,88.223 49.506,75.517 42.89,64.293
    C 42.147,63.033 41.182,62.074 41.499,63.039
    C 43.614,69.493 41.66,74.598 38.014,77.228
    C 34.439,79.808 29.526,80.239 25.592,78.2
    C 24.437,77.601 23.958,78.474 24.497,78.973
    M 12.851,48.865
    C 12.903,49.459 13.715,50.221 14.992,50.571
    C 16.089,50.872 18.917,51.64 22.55,49.347
    C 26.182,47.055 26.601,40.922 24.95,39.118
    C 24.439,38.204 23.774,37.539 24.303,38.997
    C 25.639,42.679 23.043,46.123 20.804,47.718
    C 18.567,49.313 15.728,48.558 14.569,48.205
    C 13.411,47.851 12.799,48.252 12.851,48.865
    " />
  <path style="fill:#ffffff;" d="
    M 59.057,82.915
    C 58.96,84.069 60.285,84.295 62.069,84.028
    C 64.356,83.685 66.29,83.428 68.922,82.109
    C 72.489,80.321 76.099,77.764 78.742,74.314
    C 86.631,64.022 89.424,51.845 88.994,50.094
    C 88.85,51.54 86.946,59.134 82.591,65.979
    C 76.997,74.773 72.941,79.456 63.587,81.727
    C 60.983,82.359 59.185,81.396 59.057,82.915
    M 38.31,42.895
    C 39.375,43.799 41.558,45.003 45.853,46.412
    C 51.041,48.113 53.567,49.588 54.625,50.294
    C 55.746,51.045 56.456,52.72 56.526,51.232
    C 56.6,49.743 55.682,48.463 53.634,47.783
    C 52.248,47.323 49.917,46.228 47.682,45.787
    C 46.246,45.503 43.91,44.941 41.907,44.327
    C 40.809,43.99 39.69,43.399 38.31,42.895
    M 32.33,80.873
    C 33.601,80.606 40.994,78.691 42.73,72.611
    C 43.271,70.715 43.368,71.096 43.215,72.123
    C 42.435,77.366 37.48,81.233 33.263,81.377
    C 32.407,81.465 31.284,81.092 32.33,80.873
    M 17.539,49.689
    C 17.872,49.389 19.558,49.512 21.08,48.693
    C 22.601,47.875 24.408,46.082 24.731,43.533
    C 24.921,42.036 24.978,42.412 25.054,43.227
    C 24.818,47.464 20.921,49.805 18.693,50.114
    C 18.091,50.197 17.033,50.146 17.539,49.689
    " />
  <path style="fill:#999999;" d="
    M 84.196,50.431
    C 90.491,32.286 77.318,4.883 50.667,8.18
    C 26.587,11.157 26.198,36.502 47.42,42.524
    C 71.459,46.163 56.984,64.297 54.931,73.442
    C 53.09,81.639 74.357,82.988 84.196,50.431
    M 23.98,76.365
    C 25.487,76.391 26.399,76.603 27.926,77.674
    C 30.944,78.928 36.492,78.134 39.053,74.761
    C 41.615,71.389 41.699,66.742 40.723,63.934
    C 38.336,57.063 28.192,57.184 23.661,62.889
    C 18.759,69.26 22.472,76.34 23.98,76.365
    M 10.515,44.521
    C 10.815,45.468 11.583,46.849 13.205,47.079
    C 15.37,47.386 15.813,48.365 18.37,47.857
    C 20.927,47.349 22.865,45.254 23.64,42.936
    C 24.528,39.729 23.199,38.074 21.198,36.595
    C 19.197,35.117 14.796,35.276 12.169,37.67
    C 10.302,39.371 9.783,42.217 10.515,44.521
    " />
  <path style="fill:#f3f3f3;" d="
    M 67.724,64.604
    C 61.212,63.799 51.841,78.502 60.677,76.78
    C 69.512,75.059 51.841,78.502 60.677,76.78
    C 64.924,76.15 68.443,74.65 71.592,71.055
    C 75.699,66.368 81.834,56.245 83.609,49.704
    C 85.103,44.189 84.352,35.644 82.811,43.672
    C 81.231,51.912 74.237,65.41 67.724,64.604
    M 33.77,76.855
    C 35.447,76.416 40.582,74.327 39.617,66.861
    C 39.129,63.08 37.067,71.554 33.247,72.822
    C 27.461,74.742 28.111,78.337 33.77,76.855
    M 19.018,46.642
    C 20.983,46.128 23.581,43.451 22.291,41.407
    C 20.7,38.889 16.266,41.044 16.116,43.848
    C 15.966,46.653 16.936,47.187 19.018,46.642
    " />
  <path style="fill:#010101;" d="
    M 8.552,98.31
    C 9.954,97.692 11.444,97.383 12.875,97.383
    C 14.248,97.383 15.124,97.72 15.62,98.422
    C 16.671,97.72 18.103,97.383 19.213,97.383
    C 22.543,97.383 22.659,98.731 22.659,102.691
    V 111.453
    C 22.659,111.846 22.718,111.846 21.053,111.846
    V 102.522
    C 21.053,99.658 20.994,98.787 19.097,98.787
    C 18.25,98.787 17.373,98.983 16.439,99.601
    V 111.453
    C 16.439,111.846 16.498,111.846 14.832,111.846
    V 102.522
    C 14.832,99.77 14.832,98.759 12.846,98.759
    C 11.999,98.759 11.152,98.927 10.159,99.405
    V 111.453
    C 10.159,111.846 10.217,111.846 8.553,111.846
    V 98.31
    M 30.51,97.383
    C 28.028,97.383 25.283,98.085 25.283,105.584
    C 25.283,111.369 27.297,112.267 30.073,112.267
    C 32.204,112.267 34.044,111.565 34.044,111.228
    C 34.044,110.807 33.986,110.161 33.84,109.795
    C 32.934,110.413 31.649,110.75 30.218,110.75
    C 28.261,110.75 26.947,110.189 26.917,105.836
    C 28.203,105.836 31.475,105.808 33.898,105.33
    C 34.103,104.403 34.19,103.055 34.19,101.876
    C 34.19,99.068 33.051,97.383 30.51,97.383
    M 30.364,98.787
    C 32.117,98.787 32.584,99.938 32.613,102.185
    C 32.613,102.774 32.584,103.476 32.496,104.15
    C 30.86,104.544 28.085,104.544 26.917,104.544
    C 27.122,99.433 28.874,98.787 30.364,98.787
    M 36.732,98.619
    C 38.104,97.72 39.36,97.383 40.645,97.383
    C 42.076,97.383 42.748,97.776 42.748,98.254
    C 42.748,98.535 42.66,99.012 42.514,99.293
    C 42.105,99.068 41.639,98.872 40.878,98.872
    C 39.944,98.872 39.068,99.124 38.367,99.742
    V 111.453
    C 38.367,111.847 38.396,111.847 36.732,111.847
    V 98.619
    M 51.477,98.31
    C 51.477,97.944 50.251,97.383 49.024,97.383
    C 46.657,97.383 43.766,98.197 43.766,105.134
    C 43.766,111.705 45.519,112.295 48.585,112.295
    C 50.103,112.295 51.477,111.481 51.477,111.032
    C 51.477,110.779 51.419,110.385 51.272,110.048
    C 50.658,110.497 49.724,110.919 48.731,110.919
    C 46.629,110.919 45.402,110.33 45.402,105.218
    C 45.402,99.573 47.417,98.787 49.169,98.787
    C 50.162,98.787 50.717,99.068 51.272,99.433
    C 51.419,99.096 51.477,98.619 51.477,98.31
    M 62.665,111.369
    C 61.379,112.015 59.686,112.268 58.226,112.268
    C 54.487,112.268 53.932,110.696 53.932,106.96
    V 98.17
    C 53.932,97.805 53.903,97.805 55.568,97.805
    V 107.129
    C 55.568,109.938 55.977,110.893 58.167,110.893
    C 59.014,110.893 60.182,110.724 61.059,110.219
    V 98.171
    C 61.059,97.806 61,97.806 62.665,97.806
    V 111.369
    M 65.996,98.619
    C 67.368,97.72 68.624,97.383 69.909,97.383
    C 71.34,97.383 72.012,97.776 72.012,98.254
    C 72.012,98.535 71.924,99.012 71.778,99.293
    C 71.369,99.068 70.902,98.872 70.142,98.872
    C 69.208,98.872 68.332,99.124 67.631,99.742
    V 111.453
    C 67.631,111.847 67.66,111.847 65.996,111.847
    V 98.619
    M 75.762,97.804
    C 74.476,97.804 74.097,97.804 74.097,98.563
    V 111.846
    C 75.733,111.846 75.762,111.846 75.762,111.453
    V 97.804
    M 74.039,92.862
    C 74.039,93.789 74.331,94.125 74.914,94.153
    C 75.586,94.153 75.908,93.676 75.908,92.833
    C 75.937,91.963 75.703,91.57 75.031,91.57
    C 74.389,91.57 74.068,92.047 74.039,92.862
    M 78.533,98.619
    C 78.533,98.31 78.591,98.141 78.708,98.057
    C 79.263,97.748 81.396,97.383 83.82,97.383
    C 85.66,97.383 86.828,98.254 86.828,100.781
    V 102.606
    C 86.828,107.605 86.682,111.34 86.682,111.34
    C 86.01,111.705 84.754,112.267 82.709,112.267
    C 80.606,112.295 78.504,112.099 78.504,107.942
    C 78.504,103.983 80.665,103.365 82.826,103.365
    C 83.644,103.365 84.608,103.449 85.251,103.702
    C 85.251,103.702 85.251,101.876 85.251,101.09
    C 85.251,99.265 84.317,98.871 83.206,98.871
    C 81.717,98.871 79.644,99.152 78.738,99.573
    C 78.562,99.265 78.533,98.787 78.533,98.619
    M 85.25,104.854
    C 84.695,104.657 83.907,104.573 83.352,104.573
    C 81.687,104.573 80.168,104.91 80.168,107.999
    C 80.168,110.891 81.424,110.92 82.913,110.92
    C 83.848,110.92 84.783,110.667 85.104,110.33
    C 85.104,110.33 85.25,106.96 85.25,104.854
    M 91.448,111.453
    C 91.448,111.846 91.477,111.846 89.841,111.846
    V 91.963
    C 89.841,91.204 90.162,91.204 91.448,91.204
    V 111.453
    " />
</svg>
static/images/logo/fossil.svg<svg width="320" height="440" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"><g transform="translate(-223.69964,-322.98867)" style="fill:#808080;stroke:none"><g transform="matrix(3.4464775e-2,0,0,3.4464775e-2,64.3835,244.04121)" visibility="visible" style="visibility:visible"><path d="M 7207,8311 L 7191,8307 L 7176,8299 L 7162,8289 L 7149,8276 L 7136,8260 L 7124,8242 L 7103,8197 L 7084,8142 L 7069,8078 L 7057,8006 L 7048,7926 L 7041,7744 L 7048,7538 L 7068,7312 L 7104,7073 L 7153,6836 L 7210,6617 L 7274,6421 L 7343,6252 L 7379,6179 L 7415,6115 L 7451,6061 L 7487,6016 L 7522,5981 L 7540,5967 L 7557,5957 L 7574,5949 L 7591,5944 L 7608,5943 L 7624,5944 L 7640,5948 L 7655,5956 L 7669,5966 L 7683,5979 L 7695,5995 L 7707,6013 L 7729,6058 L 7747,6113 L 7762,6177 L 7774,6249 L 7783,6329 L 7790,6511 L 7784,6717 L 7763,6943 L 7727,7182 L 7679,7419 L 7621,7638 L 7557,7834 L 7488,8003 L 7452,8075 L 7416,8139 L 7380,8194 L 7344,8239 L 7309,8274 L 7291,8287 L 7274,8298 L 7257,8306 L 7240,8310 L 7223,8312 L 7207,8311 z"/><path d="M 7607,10301 L 7592,10303 L 7576,10302 L 7560,10299 L 7544,10294 L 7527,10286 L 7511,10275 L 7477,10248 L 7442,10212 L 7408,10169 L 7373,10117 L 7339,10058 L 7272,9921 L 7210,9761 L 7154,9581 L 7106,9386 L 7070,9188 L 7048,9001 L 7040,8829 L 7045,8677 L 7052,8610 L 7063,8549 L 7077,8494 L 7094,8448 L 7114,8409 L 7125,8393 L 7136,8379 L 7149,8368 L 7162,8358 L 7176,8351 L 7191,8347 L 7206,8345 L 7222,8346 L 7238,8349 L 7254,8354 L 7271,8362 L 7288,8372 L 7322,8399 L 7356,8435 L 7391,8479 L 7425,8531 L 7460,8589 L 7526,8726 L 7589,8887 L 7645,9066 L 7693,9262 L 7729,9460 L 7750,9647 L 7758,9818 L 7753,9971 L 7746,10038 L 7735,10099 L 7721,10153 L 7704,10200 L 7684,10239 L 7673,10255 L 7662,10269 L 7649,10280 L 7636,10290 L 7622,10297 L 7607,10301 z"/><path d="M 8749,11736 L 8737,11743 L 8724,11749 L 8709,11752 L 8694,11754 L 8677,11754 L 8659,11751 L 8621,11742 L 8579,11726 L 8534,11703 L 8486,11673 L 8436,11638 L 8330,11551 L 8219,11443 L 8107,11316 L 7995,11173 L 7892,11023 L 7805,10878 L 7735,10739 L 7684,10612 L 7665,10553 L 7652,10499 L 7643,10449 L 7640,10404 L 7643,10365 L 7646,10348 L 7651,10332 L 7657,10317 L 7665,10304 L 7674,10293 L 7685,10284 L 7697,10277 L 7711,10271 L 7725,10268 L 7741,10266 L 7757,10266 L 7775,10268 L 7814,10278 L 7855,10294 L 7900,10317 L 7948,10346 L 7998,10381 L 8104,10469 L 8215,10577 L 8328,10704 L 8440,10847 L 8543,10996 L 8630,11142 L 8699,11280 L 8751,11408 L 8769,11466 L 8783,11521 L 8791,11570 L 8794,11615 L 8791,11655 L 8788,11672 L 8783,11688 L 8777,11703 L 8769,11716 L 8760,11727 L 8749,11736 z"/><path d="M 10683,12127 L 10680,12139 L 10674,12151 L 10666,12162 L 10656,12173 L 10643,12183 L 10628,12192 L 10592,12209 L 10547,12224 L 10494,12237 L 10434,12247 L 10368,12255 L 10217,12263 L 10045,12261 L 9857,12248 L 9657,12224 L 9458,12190 L 9275,12149 L 9110,12103 L 8968,12052 L 8906,12025 L 8852,11999 L 8805,11972 L 8766,11945 L 8736,11918 L 8725,11904 L 8715,11891 L 8708,11878 L 8704,11865 L 8702,11852 L 8702,11840 L 8705,11828 L 8711,11816 L 8719,11805 L 8729,11794 L 8742,11784 L 8757,11775 L 8793,11758 L 8838,11743 L 8891,11730 L 8950,11720 L 9017,11712 L 9168,11704 L 9339,11706 L 9527,11719 L 9727,11743 L 9926,11777 L 10110,11818 L 10275,11864 L 10417,11915 L 10479,11942 L 10533,11968 L 10580,11995 L 10619,12022 L 10649,12049 L 10660,12063 L 10670,12076 L 10677,12089 L 10681,12102 L 10683,12115 L 10683,12127 z"/><path d="M 10761,12053 L 10758,12043 L 10758,12032 L 10760,12021 L 10763,12009 L 10769,11996 L 10777,11983 L 10799,11955 L 10828,11925 L 10864,11894 L 10955,11826 L 11070,11755 L 11206,11682 L 11359,11610 L 11526,11540 L 11696,11478 L 11858,11427 L 12007,11389 L 12140,11363 L 12253,11350 L 12301,11349 L 12343,11351 L 12378,11357 L 12392,11361 L 12405,11367 L 12416,11373 L 12425,11380 L 12432,11388 L 12437,11397 L 12440,11407 L 12440,11418 L 12438,11429 L 12435,11441 L 12429,11454 L 12421,11467 L 12399,11495 L 12370,11525 L 12334,11556 L 12243,11624 L 12127,11695 L 11992,11768 L 11838,11840 L 11671,11910 L 11501,11972 L 11340,12023 L 11191,12061 L 11058,12087 L 10945,12100 L 10897,12101 L 10855,12099 L 10820,12093 L 10806,12089 L 10793,12083 L 10782,12077 L 10773,12070 L 10766,12062 L 10761,12053 z"/><path d="M 12410,11353 L 12408,11351 L 12406,11349 L 12404,11344 L 12402,11337 L 12402,11330 L 12402,11322 L 12403,11312 L 12409,11291 L 12418,11267 L 12430,11239 L 12465,11175 L 12511,11102 L 12568,11022 L 12635,10936 L 12710,10847 L 12788,10761 L 12864,10683 L 12937,10616 L 13003,10560 L 13061,10518 L 13087,10502 L 13110,10490 L 13130,10482 L 13139,10479 L 13147,10478 L 13154,10477 L 13161,10478 L 13166,10480 L 13169,10481 L 13171,10483 L 13173,10485 L 13175,10487 L 13177,10492 L 13179,10499 L 13180,10506 L 13179,10514 L 13178,10524 L 13173,10545 L 13164,10569 L 13152,10597 L 13117,10661 L 13071,10734 L 13014,10814 L 12947,10900 L 12872,10989 L 12794,11075 L 12718,11153 L 12645,11220 L 12579,11276 L 12521,11318 L 12495,11334 L 12472,11346 L 12451,11354 L 12442,11357 L 12434,11358 L 12427,11359 L 12420,11358 L 12415,11356 L 12412,11355 L 12410,11353 z"/><path d="M 8102,11826 L 8102,11791 L 8101,11755 L 8100,11720 L 8098,11685 L 8096,11651 L 8093,11617 L 8089,11583 L 8086,11550 L 8081,11518 L 8077,11487 L 8072,11456 L 8066,11427 L 8060,11398 L 8054,11371 L 8047,11344 L 8039,11319 L 8032,11296 L 8024,11273 L 8016,11252 L 8007,11233 L 7999,11215 L 7990,11198 L 7980,11184 L 7971,11171 L 7961,11159 L 7951,11149 L 7941,11141 L 7931,11135 L 7921,11131 L 7911,11128 L 7901,11127 L 7901,11127 L 7891,11128 L 7881,11131 L 7871,11135 L 7861,11141 L 7851,11149 L 7841,11159 L 7831,11171 L 7822,11184 L 7812,11198 L 7803,11215 L 7795,11233 L 7786,11252 L 7778,11273 L 7770,11296 L 7763,11319 L 7755,11344 L 7748,11371 L 7742,11398 L 7736,11427 L 7730,11456 L 7725,11487 L 7721,11518 L 7716,11550 L 7713,11583 L 7709,11617 L 7706,11651 L 7704,11685 L 7702,11720 L 7701,11755 L 7700,11791 L 7700,11826 L 7700,11826 L 7700,11861 L 7701,11897 L 7702,11932 L 7704,11967 L 7706,12001 L 7709,12035 L 7713,12069 L 7716,12102 L 7721,12134 L 7725,12165 L 7730,12196 L 7736,12225 L 7742,12254 L 7748,12281 L 7755,12308 L 7763,12333 L 7770,12356 L 7778,12379 L 7786,12400 L 7795,12419 L 7803,12437 L 7812,12454 L 7822,12468 L 7831,12481 L 7841,12493 L 7851,12503 L 7861,12511 L 7871,12517 L 7881,12521 L 7891,12524 L 7901,12525 L 7901,12525 L 7911,12524 L 7921,12521 L 7931,12517 L 7941,12511 L 7951,12503 L 7961,12493 L 7971,12481 L 7980,12468 L 7990,12454 L 7999,12437 L 8007,12419 L 8016,12400 L 8024,12379 L 8032,12356 L 8039,12333 L 8047,12308 L 8054,12281 L 8060,12254 L 8066,12225 L 8072,12196 L 8077,12165 L 8081,12134 L 8086,12102 L 8089,12069 L 8093,12035 L 8096,12001 L 8098,11967 L 8100,11932 L 8101,11897 L 8102,11861 L 8102,11826 z"/><path d="M 7825,12576 L 7819,12584 L 7810,12591 L 7801,12597 L 7789,12601 L 7777,12604 L 7762,12606 L 7730,12607 L 7692,12603 L 7649,12595 L 7602,12583 L 7551,12567 L 7438,12522 L 7313,12463 L 7181,12391 L 7043,12306 L 6910,12215 L 6790,12123 L 6685,12033 L 6599,11948 L 6563,11907 L 6533,11869 L 6508,11833 L 6490,11800 L 6477,11770 L 6473,11756 L 6471,11743 L 6470,11731 L 6471,11719 L 6474,11709 L 6479,11700 L 6486,11692 L 6494,11685 L 6504,11679 L 6515,11675 L 6528,11672 L 6542,11670 L 6575,11669 L 6613,11673 L 6656,11681 L 6703,11693 L 6754,11709 L 6867,11753 L 6992,11812 L 7124,11884 L 7262,11969 L 7395,12061 L 7515,12153 L 7619,12243 L 7706,12328 L 7741,12369 L 7771,12407 L 7796,12443 L 7815,12476 L 7827,12506 L 7831,12520 L 7834,12533 L 7834,12545 L 7833,12557 L 7830,12567 L 7825,12576 z"/><path d="M 6460,11695 L 6457,11697 L 6454,11699 L 6451,11701 L 6447,11702 L 6443,11703 L 6438,11703 L 6428,11702 L 6416,11700 L 6403,11696 L 6389,11691 L 6374,11684 L 6342,11666 L 6307,11643 L 6270,11616 L 6233,11584 L 6197,11550 L 6166,11517 L 6139,11485 L 6118,11455 L 6110,11441 L 6103,11427 L 6098,11415 L 6094,11404 L 6092,11393 L 6092,11389 L 6092,11385 L 6093,11381 L 6094,11377 L 6096,11374 L 6098,11371 L 6101,11369 L 6104,11366 L 6107,11365 L 6111,11364 L 6115,11363 L 6120,11363 L 6130,11363 L 6142,11366 L 6154,11370 L 6168,11375 L 6183,11382 L 6216,11399 L 6251,11422 L 6288,11450 L 6325,11481 L 6361,11515 L 6392,11548 L 6418,11581 L 6439,11611 L 6448,11625 L 6455,11638 L 6460,11651 L 6464,11662 L 6465,11672 L 6466,11677 L 6465,11681 L 6465,11685 L 6464,11689 L 6462,11692 L 6460,11695 z"/><path d="M 13184,10437 L 13182,10436 L 13179,10434 L 13175,10430 L 13171,10424 L 13168,10418 L 13166,10410 L 13164,10401 L 13163,10379 L 13164,10353 L 13167,10322 L 13179,10251 L 13200,10167 L 13229,10073 L 13266,9970 L 13309,9862 L 13357,9756 L 13405,9659 L 13453,9572 L 13498,9499 L 13540,9440 L 13560,9416 L 13578,9398 L 13595,9384 L 13602,9378 L 13610,9374 L 13616,9372 L 13623,9370 L 13629,9371 L 13631,9371 L 13634,9372 L 13636,9373 L 13639,9375 L 13643,9379 L 13646,9385 L 13649,9391 L 13651,9399 L 13653,9408 L 13655,9430 L 13654,9456 L 13651,9487 L 13638,9558 L 13617,9642 L 13588,9736 L 13551,9839 L 13508,9947 L 13461,10053 L 13413,10150 L 13365,10237 L 13320,10311 L 13278,10369 L 13258,10393 L 13240,10411 L 13223,10425 L 13216,10431 L 13208,10435 L 13202,10437 L 13195,10439 L 13189,10438 L 13187,10438 L 13184,10437 z"/><path d="M 10098,10825 L 10098,10790 L 10097,10754 L 10096,10719 L 10094,10684 L 10092,10650 L 10089,10616 L 10086,10582 L 10082,10549 L 10078,10517 L 10073,10486 L 10068,10455 L 10062,10426 L 10056,10397 L 10050,10370 L 10043,10343 L 10036,10318 L 10029,10295 L 10021,10272 L 10013,10251 L 10004,10232 L 9996,10214 L 9987,10197 L 9977,10183 L 9968,10170 L 9959,10158 L 9949,10148 L 9939,10140 L 9929,10134 L 9919,10130 L 9909,10127 L 9899,10126 L 9899,10126 L 9889,10127 L 9879,10130 L 9869,10134 L 9859,10140 L 9849,10148 L 9839,10158 L 9830,10170 L 9821,10183 L 9811,10197 L 9802,10214 L 9794,10232 L 9785,10251 L 9777,10272 L 9769,10295 L 9762,10318 L 9755,10343 L 9748,10370 L 9742,10397 L 9736,10426 L 9730,10455 L 9725,10486 L 9720,10517 L 9716,10549 L 9712,10582 L 9709,10616 L 9706,10650 L 9704,10684 L 9702,10719 L 9701,10754 L 9700,10790 L 9700,10825 L 9700,10825 L 9700,10860 L 9701,10896 L 9702,10931 L 9704,10966 L 9706,11000 L 9709,11034 L 9712,11068 L 9716,11101 L 9720,11133 L 9725,11164 L 9730,11195 L 9736,11224 L 9742,11253 L 9748,11280 L 9755,11307 L 9762,11332 L 9769,11355 L 9777,11378 L 9785,11399 L 9794,11418 L 9802,11436 L 9811,11453 L 9821,11467 L 9830,11480 L 9839,11492 L 9849,11502 L 9859,11510 L 9869,11516 L 9879,11520 L 9889,11523 L 9899,11524 L 9899,11524 L 9909,11523 L 9919,11520 L 9929,11516 L 9939,11510 L 9949,11502 L 9959,11492 L 9968,11480 L 9977,11467 L 9987,11453 L 9996,11436 L 10004,11418 L 10013,11399 L 10021,11378 L 10029,11355 L 10036,11332 L 10043,11307 L 10050,11280 L 10056,11253 L 10062,11224 L 10068,11195 L 10073,11164 L 10078,11133 L 10082,11101 L 10086,11068 L 10089,11034 L 10092,11000 L 10094,10966 L 10096,10931 L 10097,10896 L 10098,10860 L 10098,10825 z"/><path d="M 9827,11575 L 9821,11583 L 9812,11590 L 9803,11596 L 9791,11600 L 9779,11603 L 9764,11605 L 9732,11606 L 9694,11602 L 9651,11594 L 9604,11582 L 9553,11566 L 9440,11521 L 9315,11462 L 9183,11390 L 9045,11305 L 8912,11214 L 8792,11122 L 8687,11032 L 8601,10947 L 8565,10906 L 8535,10868 L 8510,10832 L 8492,10799 L 8479,10769 L 8475,10755 L 8473,10742 L 8472,10730 L 8473,10718 L 8476,10708 L 8481,10699 L 8488,10691 L 8496,10684 L 8506,10678 L 8517,10674 L 8530,10671 L 8544,10669 L 8577,10668 L 8615,10672 L 8658,10680 L 8705,10692 L 8756,10708 L 8869,10752 L 8994,10811 L 9126,10883 L 9264,10968 L 9397,11060 L 9517,11152 L 9621,11242 L 9708,11327 L 9743,11368 L 9773,11406 L 9798,11442 L 9817,11475 L 9829,11505 L 9833,11519 L 9836,11532 L 9836,11544 L 9835,11556 L 9832,11566 L 9827,11575 z"/><path d="M 6085,9230 L 6075,9220 L 6067,9209 L 6060,9197 L 6055,9184 L 6050,9169 L 6047,9154 L 6045,9120 L 6048,9083 L 6055,9042 L 6067,8998 L 6083,8952 L 6104,8904 L 6128,8853 L 6190,8749 L 6266,8641 L 6357,8533 L 6456,8432 L 6555,8346 L 6653,8274 L 6701,8245 L 6747,8220 L 6791,8199 L 6833,8183 L 6873,8172 L 6910,8165 L 6944,8164 L 6960,8166 L 6975,8169 L 6989,8173 L 7001,8179 L 7013,8186 L 7024,8194 L 7034,8204 L 7042,8215 L 7049,8227 L 7054,8241 L 7059,8255 L 7062,8271 L 7064,8304 L 7062,8342 L 7054,8383 L 7043,8426 L 7027,8473 L 7006,8521 L 6981,8571 L 6920,8676 L 6843,8784 L 6753,8892 L 6654,8993 L 6554,9079 L 6456,9151 L 6409,9180 L 6362,9205 L 6318,9226 L 6276,9242 L 6236,9253 L 6199,9259 L 6165,9260 L 6149,9259 L 6134,9256 L 6120,9251 L 6108,9246 L 6096,9239 L 6085,9230 z"/><path d="M 5910,9183 L 5900,9185 L 5890,9184 L 5879,9182 L 5868,9177 L 5856,9171 L 5845,9163 L 5820,9141 L 5795,9113 L 5769,9078 L 5743,9037 L 5716,8991 L 5663,8882 L 5611,8754 L 5561,8612 L 5516,8456 L 5479,8299 L 5451,8150 L 5434,8014 L 5427,7893 L 5427,7839 L 5430,7791 L 5435,7748 L 5443,7711 L 5454,7680 L 5460,7667 L 5467,7656 L 5474,7647 L 5483,7639 L 5491,7634 L 5501,7630 L 5511,7628 L 5521,7629 L 5532,7631 L 5543,7636 L 5555,7642 L 5566,7650 L 5591,7671 L 5616,7700 L 5642,7735 L 5668,7776 L 5695,7822 L 5748,7931 L 5800,8058 L 5850,8201 L 5895,8357 L 5932,8514 L 5960,8663 L 5977,8799 L 5984,8920 L 5984,8974 L 5981,9022 L 5975,9065 L 5967,9102 L 5957,9133 L 5951,9146 L 5944,9157 L 5936,9166 L 5928,9174 L 5919,9179 L 5910,9183 z"/><path d="M 8630,9344 L 8623,9336 L 8617,9328 L 8613,9318 L 8609,9306 L 8607,9294 L 8607,9281 L 8609,9251 L 8615,9217 L 8626,9180 L 8642,9140 L 8662,9097 L 8713,9004 L 8779,8903 L 8858,8798 L 8950,8691 L 9048,8589 L 9144,8500 L 9238,8425 L 9325,8365 L 9366,8341 L 9405,8321 L 9440,8306 L 9473,8296 L 9503,8291 L 9516,8291 L 9529,8291 L 9540,8294 L 9550,8297 L 9560,8302 L 9568,8308 L 9575,8316 L 9581,8325 L 9585,8335 L 9588,8346 L 9590,8358 L 9591,8372 L 9589,8401 L 9582,8435 L 9571,8472 L 9556,8512 L 9536,8555 L 9485,8648 L 9419,8749 L 9339,8854 L 9248,8961 L 9150,9063 L 9054,9152 L 8960,9228 L 8873,9288 L 8832,9312 L 8793,9331 L 8758,9346 L 8725,9356 L 8695,9361 L 8682,9362 L 8669,9361 L 8658,9359 L 8648,9355 L 8638,9350 L 8630,9344 z"/><path d="M 8566,9557 L 8557,9563 L 8547,9566 L 8536,9568 L 8524,9569 L 8511,9568 L 8497,9565 L 8465,9555 L 8431,9539 L 8393,9517 L 8353,9490 L 8310,9458 L 8218,9378 L 8120,9282 L 8019,9170 L 7917,9044 L 7821,8913 L 7739,8787 L 7670,8668 L 7617,8558 L 7597,8509 L 7581,8462 L 7569,8420 L 7562,8383 L 7561,8350 L 7562,8336 L 7564,8323 L 7567,8311 L 7572,8301 L 7578,8292 L 7586,8285 L 7595,8279 L 7605,8276 L 7616,8274 L 7628,8273 L 7641,8274 L 7655,8277 L 7687,8287 L 7721,8303 L 7759,8325 L 7799,8352 L 7842,8385 L 7934,8464 L 8032,8561 L 8133,8673 L 8235,8799 L 8330,8930 L 8413,9056 L 8482,9175 L 8535,9285 L 8555,9334 L 8571,9380 L 8583,9422 L 8589,9460 L 8591,9492 L 8590,9507 L 8588,9520 L 8585,9531 L 8580,9541 L 8574,9550 L 8566,9557 z"/><path d="M 6578,11626 L 6575,11627 L 6572,11627 L 6569,11627 L 6565,11626 L 6561,11624 L 6557,11622 L 6549,11616 L 6540,11608 L 6531,11598 L 6521,11586 L 6510,11573 L 6489,11541 L 6467,11503 L 6445,11460 L 6424,11413 L 6405,11365 L 6390,11319 L 6379,11277 L 6371,11239 L 6369,11222 L 6367,11207 L 6367,11193 L 6367,11181 L 6369,11171 L 6370,11166 L 6372,11163 L 6374,11159 L 6376,11157 L 6378,11155 L 6381,11153 L 6384,11152 L 6387,11152 L 6391,11152 L 6394,11153 L 6398,11155 L 6402,11157 L 6411,11163 L 6420,11171 L 6429,11181 L 6439,11193 L 6449,11206 L 6471,11238 L 6493,11276 L 6514,11319 L 6535,11366 L 6554,11414 L 6569,11460 L 6581,11502 L 6588,11540 L 6591,11557 L 6592,11572 L 6593,11586 L 6592,11598 L 6590,11608 L 6589,11613 L 6587,11616 L 6585,11620 L 6583,11622 L 6581,11624 L 6578,11626 z"/><path d="M 5952,11673 L 5953,11670 L 5955,11667 L 5957,11665 L 5960,11663 L 5963,11660 L 5967,11658 L 5977,11655 L 5989,11652 L 6003,11651 L 6037,11649 L 6077,11651 L 6122,11655 L 6172,11663 L 6224,11674 L 6276,11687 L 6323,11701 L 6366,11717 L 6402,11733 L 6432,11748 L 6444,11756 L 6454,11764 L 6461,11771 L 6464,11775 L 6466,11778 L 6468,11781 L 6469,11785 L 6469,11788 L 6469,11791 L 6468,11794 L 6466,11797 L 6464,11799 L 6461,11802 L 6458,11804 L 6454,11806 L 6444,11809 L 6432,11812 L 6418,11814 L 6384,11815 L 6344,11814 L 6299,11809 L 6249,11802 L 6197,11791 L 6145,11778 L 6098,11763 L 6055,11748 L 6019,11732 L 5989,11716 L 5977,11708 L 5967,11701 L 5960,11693 L 5957,11690 L 5955,11686 L 5953,11683 L 5952,11679 L 5952,11676 L 5952,11673 z"/><path d="M 5384,7616 L 5381,7618 L 5378,7620 L 5375,7622 L 5371,7623 L 5367,7624 L 5362,7624 L 5352,7623 L 5340,7621 L 5327,7617 L 5313,7612 L 5298,7605 L 5266,7587 L 5231,7564 L 5194,7537 L 5157,7505 L 5121,7471 L 5090,7438 L 5063,7406 L 5042,7376 L 5034,7362 L 5027,7348 L 5022,7336 L 5018,7325 L 5016,7314 L 5016,7310 L 5016,7306 L 5017,7302 L 5018,7298 L 5020,7295 L 5022,7292 L 5025,7290 L 5028,7287 L 5031,7286 L 5035,7285 L 5039,7284 L 5044,7284 L 5054,7284 L 5066,7287 L 5078,7291 L 5092,7296 L 5107,7303 L 5140,7320 L 5175,7343 L 5212,7371 L 5249,7402 L 5285,7436 L 5316,7469 L 5342,7502 L 5363,7532 L 5372,7546 L 5379,7559 L 5384,7572 L 5388,7583 L 5389,7593 L 5390,7598 L 5389,7602 L 5389,7606 L 5388,7610 L 5386,7613 L 5384,7616 z"/><path d="M 5502,7547 L 5499,7548 L 5496,7548 L 5493,7548 L 5489,7547 L 5485,7545 L 5481,7543 L 5473,7537 L 5464,7529 L 5455,7519 L 5445,7507 L 5434,7494 L 5413,7462 L 5391,7424 L 5369,7381 L 5348,7334 L 5329,7286 L 5314,7240 L 5303,7198 L 5295,7160 L 5293,7143 L 5291,7128 L 5291,7114 L 5291,7102 L 5293,7092 L 5294,7087 L 5296,7084 L 5298,7080 L 5300,7078 L 5302,7076 L 5305,7074 L 5308,7073 L 5311,7073 L 5315,7073 L 5318,7074 L 5322,7076 L 5326,7078 L 5335,7084 L 5344,7092 L 5353,7102 L 5363,7114 L 5373,7127 L 5395,7159 L 5417,7197 L 5438,7240 L 5459,7287 L 5478,7335 L 5493,7381 L 5505,7423 L 5512,7461 L 5515,7478 L 5516,7493 L 5517,7507 L 5516,7519 L 5514,7529 L 5513,7534 L 5511,7537 L 5509,7541 L 5507,7543 L 5505,7545 L 5502,7547 z"/><path d="M 4875,7594 L 4876,7591 L 4878,7588 L 4880,7586 L 4883,7584 L 4886,7581 L 4890,7579 L 4900,7576 L 4912,7573 L 4926,7572 L 4960,7570 L 5000,7572 L 5045,7576 L 5095,7584 L 5147,7594 L 5199,7607 L 5246,7622 L 5289,7637 L 5325,7653 L 5355,7669 L 5367,7677 L 5377,7684 L 5384,7692 L 5387,7695 L 5389,7699 L 5391,7702 L 5392,7706 L 5392,7709 L 5392,7712 L 5391,7715 L 5389,7718 L 5387,7720 L 5384,7722 L 5381,7725 L 5377,7727 L 5367,7730 L 5355,7733 L 5341,7734 L 5307,7736 L 5267,7734 L 5222,7730 L 5172,7722 L 5120,7711 L 5068,7698 L 5021,7684 L 4978,7668 L 4942,7653 L 4912,7637 L 4900,7629 L 4890,7621 L 4883,7614 L 4880,7610 L 4878,7607 L 4876,7604 L 4875,7600 L 4875,7597 L 4875,7594 z"/><path d="M 9763,8248 L 9761,8245 L 9759,8242 L 9758,8238 L 9758,8234 L 9757,8230 L 9758,8226 L 9759,8215 L 9763,8204 L 9768,8192 L 9775,8178 L 9784,8164 L 9805,8134 L 9831,8102 L 9862,8069 L 9897,8035 L 9934,8004 L 9970,7976 L 10005,7953 L 10037,7936 L 10052,7929 L 10066,7923 L 10079,7919 L 10090,7917 L 10100,7916 L 10105,7916 L 10109,7917 L 10113,7918 L 10116,7920 L 10119,7922 L 10122,7924 L 10124,7927 L 10126,7930 L 10127,7933 L 10127,7937 L 10128,7941 L 10127,7946 L 10126,7956 L 10122,7967 L 10117,7979 L 10110,7993 L 10102,8007 L 10080,8037 L 10054,8069 L 10023,8102 L 9988,8136 L 9951,8167 L 9914,8195 L 9880,8218 L 9847,8236 L 9833,8242 L 9819,8248 L 9806,8252 L 9794,8254 L 9784,8255 L 9780,8255 L 9775,8255 L 9772,8254 L 9768,8252 L 9765,8250 L 9763,8248 z"/><path d="M 9639,8179 L 9636,8177 L 9634,8175 L 9632,8173 L 9630,8169 L 9628,8166 L 9627,8161 L 9625,8151 L 9624,8139 L 9625,8126 L 9626,8110 L 9629,8093 L 9636,8056 L 9648,8013 L 9663,7968 L 9682,7920 L 9703,7873 L 9725,7830 L 9747,7792 L 9768,7760 L 9779,7746 L 9789,7734 L 9798,7724 L 9807,7717 L 9815,7711 L 9819,7709 L 9823,7707 L 9827,7706 L 9830,7706 L 9833,7706 L 9836,7707 L 9839,7708 L 9841,7710 L 9843,7713 L 9845,7716 L 9847,7720 L 9848,7724 L 9850,7734 L 9851,7746 L 9850,7760 L 9849,7775 L 9846,7792 L 9839,7830 L 9827,7872 L 9812,7918 L 9793,7966 L 9772,8013 L 9750,8056 L 9728,8094 L 9707,8126 L 9697,8140 L 9687,8152 L 9677,8162 L 9668,8169 L 9660,8175 L 9656,8177 L 9652,8179 L 9648,8180 L 9645,8180 L 9642,8180 L 9639,8179 z"/><path d="M 10269,8228 L 10269,8231 L 10269,8234 L 10268,8237 L 10267,8241 L 10264,8244 L 10262,8248 L 10254,8255 L 10244,8263 L 10232,8270 L 10203,8286 L 10166,8302 L 10123,8317 L 10076,8331 L 10024,8344 L 9972,8355 L 9922,8362 L 9877,8367 L 9837,8368 L 9803,8367 L 9789,8365 L 9777,8362 L 9767,8359 L 9763,8357 L 9760,8355 L 9757,8352 L 9755,8350 L 9753,8347 L 9752,8344 L 9752,8341 L 9752,8338 L 9753,8334 L 9755,8331 L 9757,8327 L 9760,8324 L 9767,8316 L 9777,8309 L 9789,8301 L 9803,8293 L 9819,8285 L 9855,8269 L 9898,8254 L 9946,8240 L 9998,8227 L 10050,8217 L 10099,8209 L 10144,8205 L 10184,8204 L 10218,8205 L 10232,8207 L 10244,8210 L 10254,8213 L 10258,8215 L 10261,8217 L 10264,8220 L 10266,8222 L 10268,8225 L 10269,8228 z"/><path d="M 9749,10085 L 9746,10087 L 9743,10089 L 9740,10091 L 9736,10092 L 9732,10093 L 9727,10093 L 9717,10092 L 9705,10090 L 9693,10086 L 9679,10081 L 9664,10074 L 9631,10056 L 9597,10034 L 9560,10006 L 9523,9975 L 9488,9941 L 9457,9908 L 9430,9876 L 9409,9846 L 9401,9832 L 9394,9819 L 9388,9806 L 9385,9795 L 9383,9785 L 9382,9780 L 9383,9776 L 9383,9772 L 9384,9768 L 9386,9765 L 9388,9762 L 9391,9760 L 9394,9758 L 9397,9756 L 9401,9755 L 9405,9754 L 9410,9754 L 9421,9755 L 9432,9757 L 9445,9761 L 9459,9767 L 9474,9774 L 9507,9791 L 9541,9814 L 9578,9841 L 9615,9872 L 9650,9906 L 9681,9939 L 9707,9971 L 9729,10001 L 9737,10015 L 9744,10029 L 9749,10041 L 9753,10052 L 9754,10063 L 9755,10067 L 9754,10071 L 9754,10075 L 9753,10079 L 9751,10082 L 9749,10085 z"/><path d="M 9868,10017 L 9865,10018 L 9862,10018 L 9859,10018 L 9855,10017 L 9852,10015 L 9848,10013 L 9840,10007 L 9831,9999 L 9821,9989 L 9801,9963 L 9780,9931 L 9758,9893 L 9736,9850 L 9715,9803 L 9696,9755 L 9681,9710 L 9670,9667 L 9662,9630 L 9658,9597 L 9657,9584 L 9658,9572 L 9660,9562 L 9661,9557 L 9662,9554 L 9664,9550 L 9666,9548 L 9668,9546 L 9671,9544 L 9674,9543 L 9677,9543 L 9680,9543 L 9684,9544 L 9688,9546 L 9692,9548 L 9700,9554 L 9709,9562 L 9718,9572 L 9728,9584 L 9739,9598 L 9760,9630 L 9782,9668 L 9803,9711 L 9824,9758 L 9843,9806 L 9858,9851 L 9870,9894 L 9878,9931 L 9880,9948 L 9882,9964 L 9882,9977 L 9882,9989 L 9880,9999 L 9879,10004 L 9877,10007 L 9875,10011 L 9873,10013 L 9871,10015 L 9868,10017 z"/><path d="M 9242,10063 L 9243,10060 L 9245,10057 L 9247,10055 L 9250,10053 L 9253,10050 L 9257,10048 L 9267,10045 L 9279,10042 L 9293,10041 L 9327,10039 L 9367,10041 L 9412,10045 L 9462,10053 L 9514,10064 L 9566,10077 L 9613,10091 L 9656,10107 L 9692,10123 L 9722,10138 L 9734,10146 L 9744,10154 L 9751,10161 L 9754,10165 L 9756,10168 L 9758,10171 L 9759,10175 L 9759,10178 L 9759,10181 L 9758,10184 L 9756,10187 L 9754,10189 L 9751,10192 L 9748,10194 L 9744,10196 L 9734,10199 L 9722,10202 L 9708,10204 L 9674,10205 L 9634,10204 L 9589,10199 L 9539,10192 L 9487,10181 L 9435,10168 L 9388,10153 L 9345,10138 L 9309,10122 L 9279,10106 L 9267,10098 L 9257,10091 L 9250,10083 L 9247,10080 L 9245,10076 L 9243,10073 L 9242,10069 L 9242,10066 L 9242,10063 z"/><path d="M 6841,4401 L 6832,4382 L 6827,4362 L 6826,4339 L 6828,4314 L 6834,4288 L 6843,4260 L 6872,4199 L 6914,4133 L 6968,4061 L 7035,3985 L 7112,3904 L 7298,3734 L 7521,3555 L 7777,3372 L 8060,3190 L 8352,3022 L 8632,2879 L 8894,2763 L 9130,2676 L 9237,2644 L 9336,2621 L 9424,2606 L 9503,2599 L 9570,2601 L 9599,2606 L 9625,2613 L 9648,2622 L 9667,2633 L 9683,2648 L 9696,2664 L 9705,2683 L 9710,2703 L 9711,2726 L 9709,2751 L 9703,2777 L 9694,2805 L 9665,2866 L 9623,2932 L 9569,3004 L 9502,3080 L 9425,3161 L 9239,3331 L 9016,3510 L 8760,3693 L 8477,3875 L 8185,4043 L 7905,4186 L 7643,4302 L 7407,4389 L 7300,4420 L 7201,4444 L 7113,4459 L 7034,4466 L 6967,4464 L 6938,4459 L 6912,4452 L 6889,4443 L 6870,4432 L 6854,4417 L 6841,4401 z"/><path d="M 9098,6041 L 9075,6069 L 9049,6094 L 9020,6117 L 8989,6137 L 8956,6155 L 8920,6170 L 8843,6193 L 8757,6206 L 8665,6209 L 8567,6203 L 8463,6188 L 8354,6163 L 8242,6129 L 8127,6087 L 8009,6035 L 7890,5975 L 7770,5907 L 7651,5830 L 7532,5745 L 7418,5654 L 7311,5560 L 7212,5464 L 7122,5366 L 7040,5267 L 6968,5168 L 6904,5069 L 6851,4972 L 6808,4876 L 6775,4783 L 6753,4694 L 6742,4608 L 6743,4527 L 6748,4489 L 6755,4452 L 6766,4417 L 6780,4383 L 6798,4351 L 6818,4321 L 6841,4293 L 6867,4268 L 6896,4245 L 6927,4225 L 6960,4207 L 6996,4192 L 7073,4169 L 7159,4156 L 7251,4152 L 7349,4158 L 7453,4174 L 7562,4199 L 7674,4232 L 7789,4275 L 7907,4326 L 8026,4387 L 8146,4455 L 8265,4532 L 8384,4617 L 8498,4708 L 8605,4802 L 8704,4898 L 8794,4996 L 8876,5095 L 8948,5194 L 9012,5293 L 9065,5390 L 9108,5486 L 9141,5579 L 9163,5668 L 9174,5754 L 9173,5835 L 9168,5873 L 9161,5910 L 9150,5945 L 9136,5979 L 9118,6011 L 9098,6041 z"/><path d="M 7879,5222 L 7868,5212 L 7858,5199 L 7851,5184 L 7845,5167 L 7841,5147 L 7839,5126 L 7841,5077 L 7850,5020 L 7866,4957 L 7888,4888 L 7917,4812 L 7992,4647 L 8091,4466 L 8210,4274 L 8348,4075 L 8496,3883 L 8643,3712 L 8786,3563 L 8921,3442 L 8984,3392 L 9044,3349 L 9099,3316 L 9150,3290 L 9196,3274 L 9217,3269 L 9237,3267 L 9255,3267 L 9272,3270 L 9287,3275 L 9300,3283 L 9311,3293 L 9321,3306 L 9329,3321 L 9334,3338 L 9338,3358 L 9340,3379 L 9338,3428 L 9329,3484 L 9314,3547 L 9291,3617 L 9263,3692 L 9187,3858 L 9089,4039 L 8970,4231 L 8832,4430 L 8684,4621 L 8536,4793 L 8393,4941 L 8258,5063 L 8195,5113 L 8136,5155 L 8080,5189 L 8029,5214 L 7983,5231 L 7962,5235 L 7942,5238 L 7924,5238 L 7907,5235 L 7892,5230 L 7879,5222 z"/><path d="M 9004,6100 L 8984,6094 L 8965,6084 L 8948,6069 L 8931,6050 L 8915,6027 L 8901,6001 L 8875,5936 L 8854,5857 L 8837,5764 L 8825,5660 L 8818,5543 L 8817,5279 L 8834,4980 L 8871,4652 L 8927,4303 L 8999,3957 L 9082,3638 L 9173,3352 L 9269,3106 L 9317,2999 L 9366,2906 L 9415,2825 L 9463,2759 L 9510,2708 L 9533,2688 L 9556,2672 L 9578,2661 L 9600,2653 L 9621,2651 L 9642,2652 L 9662,2658 L 9681,2668 L 9699,2683 L 9715,2702 L 9731,2725 L 9746,2752 L 9771,2816 L 9793,2895 L 9809,2988 L 9821,3093 L 9829,3209 L 9830,3473 L 9812,3773 L 9775,4100 L 9719,4449 L 9647,4795 L 9564,5114 L 9473,5400 L 9377,5647 L 9329,5753 L 9280,5846 L 9231,5927 L 9183,5993 L 9136,6044 L 9113,6064 L 9090,6080 L 9068,6091 L 9046,6099 L 9025,6101 L 9004,6100 z"/></g></g></svg>

static/images/ok.svg<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width='32' height='32' viewBox='0 0 100 100'><circle cx='50' cy='50' r='40' fill='green'/></svg>
static/images/bad.svg<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width='32' height='32' viewBox='0 0 100 100'><circle cx='50' cy='50' r='40' fill='red'/></svg>
static/images/off.svg<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width='32' height='32' viewBox='0 0 100 100'><circle cx='50' cy='50' r='40' fill='black'/></svg>
static/images/yellow.svg<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width='32' height='32' viewBox='0 0 100 100'><circle cx='50' cy='50' r='40' fill='yellow'/></svg>
