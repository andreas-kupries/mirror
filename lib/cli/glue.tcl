# -*- tcl -*-
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
package provide m::glue 0

package require Tcl 8.5
package require cmdr::color
package require cmdr::table 0.1 ;# API: headers, borders
package require debug
package require debug::caller
package require m::msg
package require m::format

# # ## ### ##### ######## ############# ######################

namespace eval ::m {
    namespace export glue
    namespace ensemble create
}
namespace eval ::m::glue {
    namespace export cmd_* gen_*
    namespace ensemble create

    namespace import ::cmdr::color

    namespace import ::cmdr::table::general ; rename general table
    namespace import ::cmdr::table::dict    ; rename dict    table/d
}

# # ## ### ##### ######## ############# ######################

debug level  m/glue
debug prefix m/glue {}
#debug prefix m/glue {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::m::glue::gen_report_destination {p} {
    debug.m/glue {[debug caller] | }
    package require m::state

    set email [m state report-mail-destination]

    debug.m/glue {[debug caller] | [$p config] }
    debug.m/glue {[debug caller] | --> $email }
    return $email
}

proc ::m::glue::gen_limit {p} {
    debug.m/glue {[debug caller] | }
    package require m::state

    set limit [m state limit]
    if {$limit == 0} {
	set limit [expr {[$p config @th]-7}]
    }

    debug.m/glue {[debug caller] | [$p config] }
    debug.m/glue {[debug caller] | --> $limit }
    return $limit
}

proc ::m::glue::gen_submit_url {p} {
    debug.m/glue {[debug caller] | }
    package require m::submission
    set details [m submission get [$p config @id]]
    dict with details {}
    # -> url
    #    email
    #    submitter
    #    when
    #    desc
    #    vcode
    debug.m/glue {[debug caller] | [$p config] }
    debug.m/glue {[debug caller] | --> $url }
    return $url
}

proc ::m::glue::gen_submit_name {p} {
    debug.m/glue {[debug caller] | }
    package require m::submission
    set details [m submission get [$p config @id]]
    dict with details {}
    # -> url
    #    email
    #    submitter
    #    when
    #    desc
    #    vcode

    if {$desc eq {}} {
	set desc [gen_name $p]
    }
    debug.m/glue {[debug caller] | [$p config] }
    debug.m/glue {[debug caller] | --> $desc }
    return $desc
}

proc ::m::glue::gen_submit_vcs {p} {
    debug.m/glue {[debug caller] | }
    package require m::submission
    package require m::vcs
    set details [m submission get [$p config @id]]
    dict with details {}
    # -> url
    #    email
    #    submitter
    #    when
    #    desc
    #    vcode
    if {$vcode eq {}} {
	set vcs [gen_vcs $p]
    } else {
	set vcs [m vcs id $vcode]
    }
    debug.m/glue {[debug caller] | [$p config] }
    debug.m/glue {[debug caller] | --> $vcode ($vcs) }
    return $vcs
}

proc ::m::glue::gen_name {p} {
    debug.m/glue {[debug caller] | }
    package require m::project
    package require m::vcs

    # Derive a name from the url when no such was specified by the
    # user. Add a serial number if that name is already in use.
    set name [MakeName \
		  [m vcs name-from-url \
		       [$p config @vcs-code] \
		       [$p config @url]]]

    debug.m/glue {[debug caller] | [$p config] }
    debug.m/glue {[debug caller] | --> $name }
    return $name
}

proc ::m::glue::gen_vcs {p} {
    debug.m/glue {[debug caller] | }
    # Auto detect vcs of url when not specified by the user.
    package require m::validate::vcs
    package require m::vcs
    #
    set vcs [m validate vcs validate $p [m vcs detect [$p config @url]]]

    debug.m/glue {[debug caller] | [$p config] }
    debug.m/glue {[debug caller] | --> $vcs }
    return $vcs
}

proc ::m::glue::gen_vcs_code {p} {
    debug.m/glue {[debug caller] | }
    # Determine vcs code from the database id.
    package require m::vcs
    #
    set vcode [m vcs code [$p config @vcs]]

    debug.m/glue {[debug caller] | [$p config] }
    debug.m/glue {[debug caller] | --> $vcode }
    return $vcode
}

proc ::m::glue::gen_current {p} {
    debug.m/glue {[debug caller] | }
    # Provide current as repository for operation when not specified
    # by the user. Fail if we have no current repository.
    package require m::rolodex
    #
    set r [m rolodex top]
    if {$r ne {}} {
	debug.m/glue {[debug caller] | --> $r }
	return $r
    }

    debug.m/glue {[debug caller] | [$p config] }
    debug.m/glue {[debug caller] | undefined }
    $p undefined!
    # Will not reach here
}

proc ::m::glue::gen_current_project {p} {
    debug.m/glue {[debug caller] | }
    # Provide current as project for operation when not specified
    # by the user. Fail if we have no current repository to trace
    # from.
    package require m::repo
    package require m::rolodex
    #
    set r [m rolodex top]
    if {$r ne {}} {
	set project [m repo project $r]
	if {$project ne {}} {
	    debug.m/glue {[debug caller] | --> $project }
	    return $project
	}
    }

    debug.m/glue {[debug caller] | [$p config] }
    debug.m/glue {[debug caller] | undefined }
    $p undefined!
    # Will not reach here
}

# # ## ### ##### ######## ############# ######################

proc ::m::glue::cmd_import {config} {
    debug.m/glue {[debug caller] | }
    package require m::project
    package require m::repo
    package require m::rolodex
    package require m::store
    package require m::url

    set dated [$config @dated]
    if {[$config @spec set?]} {
	set sname [$config @spec string]
    } else {
	set sname {standard input}
    }

    m msg "Processing ..."
    ImportDo $dated \
	[ImportSkipKnown \
	     [ImportVerify \
		  [ImportRead $sname [$config @spec]]]]
    SiteRegen
    OK
}

proc ::m::glue::cmd_export {config} {
    debug.m/glue {[debug caller] | }
    package require m::project
    package require m::repo

    m msg [m project spec]
}

proc ::m::glue::cmd_reply_add {config} {
    debug.m/glue {[debug caller] | }
    package require m::db
    package require m::reply

    m db transaction {
	set reply [$config @reply]
	set text  [$config @text]
	set mail  [$config @auto-mail]

	m msg "New reason to reject a submission:"
	m msg "  Name:     [color note $reply]"
	m msg "  Text:     [color note $text]"
	m msg "  AutoMail: [expr {$mail ? "yes" : "no"}]"

	m reply add $reply $mail $text
    }
    #SiteRegen
    OK
}

proc ::m::glue::cmd_reply_remove {config} {
    debug.m/glue {[debug caller] | }
    package require m::db
    package require m::reply

    m db transaction {
	set reply [$config @reply]
	set name  [$config @reply string]

	m msg "Remove [color note $name] as reason for rejecting a submission."
	if {[m reply default? $reply]} {
	    m::cmdr::error \
		"Cannot remove default reason" \
		UNREMOVABLE DEFAULT
	}

	m reply remove $reply
    }
    #SiteRegen
    OK
}

proc ::m::glue::cmd_reply_change {config} {
    debug.m/glue {[debug caller] | }
    package require m::db
    package require m::reply

    m db transaction {
	set reply [$config @reply]
	set name  [$config @reply string]
	set text  [$config @text]

	m msg "Change reason [color note $name] to reject a submission:"
	m msg "  New text: [color note $text]"

	m reply change $reply $text
    }
    #SiteRegen
    OK
}

proc ::m::glue::cmd_reply_default {config} {
    debug.m/glue {[debug caller] | }
    package require m::db
    package require m::reply

    m db transaction {
	set reply [$config @reply]
	set name [$config @reply string]
	m msg "Set [color note $name] as default reason to reject a submission."

	m reply default! $reply
    }
    #SiteRegen
    OK
}

proc ::m::glue::cmd_reply_show {config} {
    debug.m/glue {[debug caller] | }
    package require m::db
    package require m::reply

    m db transaction {
	ReplyConfigShow
    }
    OK
}

proc ::m::glue::cmd_mailconfig_show {config} {
    debug.m/glue {[debug caller] | }
    package require m::state

    m db transaction {
	[table/d t {
	    MailConfigShow $t
	}] show
    }
    OK
}

proc ::m::glue::cmd_siteconfig_show {config} {
    debug.m/glue {[debug caller] | }
    package require m::state

    m db transaction {
	[table/d t {
	    SiteConfigShow $t
	}] show
    }
    OK
}

proc ::m::glue::cmd_show {config} {
    debug.m/glue {[debug caller] | }
    package require m::repo
    package require m::state

    set all [$config @all]

    m db transaction {
	set n [m state limit]
	if {!$n} { set n [color note {adjust to terminal height}] }

	[table/d t {
	    $t add Store         [m state store]
	    $t add Limit         $n
	    $t add Take         "[m state take] ([m repo count-pending] pending/[m repo count] total)"
	    $t add Window        [m state store-window-size]
	    $t add {Report To}   [m state report-mail-destination]
	    $t add {-} {}
	    $t add {Cycle, Last} [m format epoch [m state start-of-previous-cycle]]
	    $t add {Cycle, Now}  [m format epoch [m state start-of-current-cycle]]

	    if {$all} {
		package require m::db
		package require m::reply

		$t add Site {}
		SiteConfigShow $t {- }

		$t add Mail {}
		MailConfigShow $t {- }
	    }
	}] show
    }
    OK
}

proc ::m::glue::cmd_mailconfig {key desc config} {
    debug.m/glue {[debug caller] | }
    package require m::state

    set prefix Current
    m db transaction {
	set value [m state $key]

	if {[$config @value set?]} {
	    set new [$config @value]
	    if {$new ne $value} {
		m state $key $new
		set prefix New
		set value $new
	    }
	}
    }

    m msg "$prefix $desc: [color note $value]"
    OK
}

proc ::m::glue::cmd_siteconfig {key desc config} {
    debug.m/glue {[debug caller] | }
    package require m::state

    set prefix Current
    m db transaction {
	set value [m state $key]

	if {[$config @value set?]} {
	    set new [$config @value]
	    if {$new ne $value} {
		m state $key $new
		set prefix New
		set value $new
	    }
	}

        m msg "$prefix $desc: [color note $value]"
	if {($prefix eq "New") && ($value eq "")} {
	    SiteEnable 0
	}
    }
    if {$prefix eq "New"} SiteRegen
    OK
}

proc ::m::glue::cmd_site_off {config} {
    debug.m/glue {[debug caller] | }
    package require m::state
    m db transaction {
	SiteEnable 0
    }
    OK
}

proc ::m::glue::cmd_site_on {config} {
    debug.m/glue {[debug caller] | }
    package require m::state
    package require m::web::site

    set mode [expr {[$config @silent] ? "silent" : ""}]

    m db transaction {
	SiteEnable 1
	[table/d t {
	    SiteConfigShow $t
	}] show
	#
	m web site build $mode
    }
    OK
}

proc ::m::glue::cmd_site_sync {config} {
    debug.m/glue {[debug caller] | }
    package require m::web::site

    m db transaction {
	m web site sync
    }
    OK
}

proc ::m::glue::cmd_store {config} {
    debug.m/glue {[debug caller] | }
    package require m::store

    set prefix Current
    m db transaction {
	set value [m state store]
	if {[$config @path set?]} {
	    set new [file normalize [$config @path]]
	    if {$new ne $value} {
		m store move-location $new
		set prefix New
		set value $new
	    }
	}
    }

    m msg "$prefix Store at [color note $value]"
    if {$prefix eq "New"} SiteRegen
    OK
}

proc ::m::glue::cmd_report2 {config} {
    debug.m/glue {[debug caller] | }
    package require m::state

    m db transaction {
	if {[$config @mail set?]} {
	    m state report-mail-destination [$config @mail]
	}

	set mail [m state report-mail-destination]
    }

    m msg "Send report mails to [color note $mail]"
    OK
}

proc ::m::glue::cmd_take {config} {
    debug.m/glue {[debug caller] | }
    package require m::state

    m db transaction {
	if {[$config @take set?]} {
	    m state take [$config @take]
	}

	set n [m state take]
    }

    set g [expr {$n == 1 ? "project" : "projects"}]
    m msg "Per update, take [color note $n] $g"
    OK
}

proc ::m::glue::cmd_window {config} {
    debug.m/glue {[debug caller] | }
    package require m::state

    m db transaction {
	if {[$config @window set?]} {
	    m state store-window-size [$config @window]
	}

	set n [m state store-window-size]
    }

    set g [expr {$n == 1 ? "time" : "times"}]
    m msg "Keep [color note $n] update $g per repository for the moving average"
    OK
}

proc ::m::glue::cmd_vcs {config} {
    debug.m/glue {[debug caller] | }
    package require m::vcs

    m db transaction {
	set all [m vcs all]
    }
    foreach {code name} $all {
	set version [m vcs version $code issues]
	set vmsg {}
	if {$version ne {}} {
	    lappend vmsg [color note $version]
	}
	if {[llength $issues]} {
	    foreach issue $issues {
		lappend vmsg [color bad $issue]
	    }
	}
	lappend series $code $name [join $vmsg \n]
    }

    m msg [color note {Supported VCS}]
    [table t {Code Name Version} {
	foreach {code name msg} $series {
	    $t add $code $name $msg
	}
    }] show
    OK
}

proc ::m::glue::cmd_add {config} {
    debug.m/glue {[debug caller] | }
    package require m::project
    package require m::repo
    package require m::rolodex
    package require m::store

    m db transaction {
	Add $config [$config @extend]
    }
    ShowCurrent $config
    SiteRegen
    OK
}

proc ::m::glue::cmd_remove {config} {
    debug.m/glue {[debug caller] | }
    package require m::project
    package require m::repo
    package require m::rolodex
    package require m::store

    m db transaction {
	set repos [$config @repositories]

	foreach repo $repos {
	    set rinfo [m repo get $repo]
	    dict with rinfo {}
	    # -> url    : repo url
	    #    vcs    : vcs id
	    # -> vcode  : vcs code
	    # -> project: project id
	    # -> name   : project name
	    # -> store  : id of backing store for repo

	    m msg "Removing $vcode repository [color note $url] ..."
	    
	    m repo remove $repo

	    set siblings  [m store remotes $store]
	    set nsiblings [llength $siblings]
	    if {!$nsiblings} {
		m msg* "Removing unshared $vcode store $store ... "
		m store remove $store
		OKx
	    } else {
		set x [expr {($nsiblings == 1) ? "repository" : "repositories"}]
		m msg "Keeping $vcode store [color note $store]. Still used by $nsiblings $x"
	    }

	    # Remove project if no repositories remain at all.
	    set nsiblings [m project size $project]
	    
	    if {!$nsiblings} {
		m msg* "Removing empty project [color note $name] ... "
		m project remove $project
		OKx
	    } else {
		set x [expr {($nsiblings == 1) ? "repository" : "repositories"}]
		m msg "Keeping project [color note $name]. Still used by $nsiblings $x"
	    }

	    m rolodex drop $repo

	}
	
	m rolodex commit
    }

    ShowCurrent $config
    SiteRegen
    OK
}

proc ::m::glue::L {text} {
    upvar 1 w w
    set r {}
    foreach line [split $text \n] {
	if {[string length $line] > $w} {
	    set line [string range $line 0 ${w}-5]...
	}
	lappend r $line
    }
    join $r \n
}

proc m::glue::Short {repo} {
    set ri [m repo get $repo]
    dict with ri {}

    set active [color {*}[dict get {
	0 {warning offline}
	1 {note UP}
    } [expr {!!$active}]]]

    return "$url ([SIB [expr {!$issues}]] $active)"   
}

proc ::m::glue::cmd_details {config} { ;# XXX REWORK due the project/repo/store relation changes
    debug.m/glue {[debug caller] | }
    package require m::project
    package require m::repo
    package require m::rolodex
    package require m::state
    package require m::store
    package require linenoise

    set w [$config @tw]    ;#linenoise columns
    # table/d -> 2 columns, 7 overhead, 1st col 14 wide =>
    set w [expr {$w - 21}] ;# max width for col 2.

    m db transaction {
	set full [$config @full]
	set repo [$config @repository]

	# Basic repository details ...........................
	set rinfo [m repo get $repo]
	dict with rinfo {}
	#m msg "Details of [color note $url] ..."
	# -> url    : repo url
	#    active : usage state
	#    vcs    : vcs id
	#    vcode  : vcs code
        # *  project: project id
        # *  name   : project name
        # -> store  : id of backing store for repo
	#    min_sec: minimal time spent on setup/update
	#    max_sec: maximal time spent on  setup/update
	#    win_sec: last n times for setup/update
	#    checked: epoch of last check
	#    origin : repository this is forked from, or empty

	set spent [StatsTime $min_sec $max_sec $win_sec]
	
	# Get store details ...

	set path [m store path $store]
	set sd   [m store get  $store]
	dict unset sd vcs
	dict unset sd min_sec
	dict unset sd max_sec
	dict unset sd win_sec
	dict with sd {}
	#  size, sizep
	#  commits, commitp
	#  vcsname
	#  created
	#  changed
	#  updated
	lassign [m vcs caps $store] stdout stderr
	set stdout [string trim $stdout]
	set stderr [string trim $stderr]
	
	# Find repositories sharing the store ................

	set storesibs [m store repos $store]
	
	# Find repositories which are siblings of the same origin

	set forksibs {}
	set dorigin  {}
	if {$origin ne {}} {
	    set forksibs [m repo forks $origin]
	    set dorigin [Short $origin]
	}
	
	# Find repositories which are siblings of the same project

	set projectsibs [m repo for $project]

	#puts O(($origin))/\nR(($repo))/\nS(($storesibs))/\nF(($forksibs))/\nP(($projectsibs))
	
	# Compute derived information ...

	set status  [SI $stderr]
	set export  [m vcs export $vcs $store]
	set dcommit [DeltaCommitFull $commits $commitp]
	set dsize   [DeltaSizeFull $size $sizep]
	set changed [color note [m format epoch $changed]]
	set updated [m format epoch $updated]
	set created [m format epoch $created]

	set active [color {*}[dict get {
	    0 {warning offline}
	    1 {note UP}
	} [expr {!!$active}]]]

	set s [[table/d s {
	    $s borders 0

	    set sibs [lmap sib $storesibs {
		if {$sib == $repo} continue
		Short $sib
	    }]
	    if {[llength $sibs]} {
		$s add {Shared With} [Box [join $sibs \n]]
	    } else {
		$s add Unshared {}
	    }

	    $s add Size $dsize
	    $s add Commits       $dcommit
	    if {$export ne {}} {
		$s add Export [Box $export]
	    }
	    $s add {Update Stats} $spent
	    $s add {Last Change}  $changed
	    $s add {Last Check}   $updated
	    $s add Created        $created

	    if {!$full} {
		set nelines [llength [split $stderr \n]]
		set nllines [llength [split $stdout \n]]

		if {$nelines == 0} { set nelines [color note {no log}] }
		if {$nllines == 0} { set nllines [color note {no log}] }
		
		$s add Operation $nllines
		if {$stderr ne {}} {
		    $s add "Notes & Errors" [color bad $nelines]
		} else {
		    $s add "Notes & Errors" $nelines
		}
	    } else {
		if {$stdout ne {}} { $s add Operation        [L $stdout] }
		if {$stderr ne {}} { $s add "Notes & Errors" [L $stderr] }
	    }
	}] show return]
	
	[table/d t {
	    $t add {} [color note $url]
	    if {$origin ne {}} {
		$t add Origin $dorigin
	    }
	    $t add Status        "$status $active @[color note [m format epoch $checked]]"
	    $t add Project       $name
	    $t add VCS           $vcsname

	    $t add {Local Store} $path
	    $t add {}            $s

	    # Show other locations serving the project, except for forks.
	    # Forks are shown separately. Note that projects sharing the
	    # store are __not excluded__ here.
	    set sibs {}
	    foreach sibling $projectsibs {
		if {$sibling == $repo} continue
		if {$sibling == $origin} continue
		#if {$sibling in $storesibs} continue
		if {$sibling in $forksibs} continue
		lappend sibs [Short $sibling]
		#$t add ${sibs}. [Short $sibling]		
	    }
	    if {[llength $sibs]} {
		$t add {Same Project} [llength $sibs]
		$t add {} [Box [join $sibs \n]]
	    }

	    set threshold 20
	    # Show the sibling forks. Only the first, only if not sharing the store.
	    set sibs {}
	    set more 0
	    foreach sibling $forksibs {
		if {$sibling == $repo} continue
		if {$sibling == $origin} continue
		if {$sibling in $storesibs} continue
		if {[llength $sibs] >= $threshold} { incr more ; continue }
		lappend sibs [Short $sibling]
	    }
	    if {$more} {
		lappend sibs "(+$more more)"
	    }
	    if {[llength $sibs]} {
	        $t add {Sibling Forks} [expr {[llength $sibs] - 1 + $more}]
		$t add {} [Box [join $sibs \n]]
	    }

	}] show
    }
    OK
}

proc ::m::glue::SI {stderr} {
    SIB [expr {$stderr eq {}}]
}

proc ::m::glue::SIB {ok} {
    color {*}[dict get {
	0 {bad ATTEND}
	1 {good OK}
    } $ok]
}

proc ::m::glue::cmd_enable {flag config} {
    debug.m/glue {[debug caller] | }
    package require m::project
    package require m::repo
    package require m::rolodex
    package require m::store

    set op [expr {$flag ? "Enabling" : "Disabling"}]

    m db transaction {
	foreach repo [$config @repositories] {
	    m msg "$op [color note [m repo url $repo]] ..."

	    m repo enable $repo $flag

	    # Note: We do not manipulate `repo_pending`. An existing
	    # repo is always in `repo_pending`, even if it is
	    # inactive. The commands to retrieve the pending repos
	    # (all, or taken for update) is where we do the filtering,
	    # i.e. exclusion of the inactive.
	}
    }

    ShowCurrent $config
    SiteRegen
    OK
}

proc ::m::glue::cmd_move {config} {
    debug.m/glue {[debug caller] | }
    package require m::project
    package require m::repo
    package require m::rolodex

    m db transaction {
	set dst   [$config @name] ; debug.m/glue {dst: $dst}
	set repos [$config @repositories]
	if {![llength $repos]} {
	    lappend repos [m rolodex top]
	}

	# Get/create destination
	if {![m project has $dst]} {
	    m msg "Moving into new project [color note $dst]"
	    m msg* "  Setting up the project ... "
	    set project [m project add $dst]
	    OKx
	} else {
	    m msg "Moving into known project [color note $dst]"
	    set project [m project id $dst]
	}

	# Record origin projects
	set oldprojects \
	    [lsort -unique \
		 [lmap r $repos { m repo project $r }]]

	# Move repositories to destination
	foreach r $repos {
	    m msg "- Moving [color note [m repo url $r]]"
	    m repo move/1 $r $project
	}

	# Remove the origins which became empty.
	set first 1
	foreach p $oldprojects {
	    if {[m project size $p]} continue
	    if {$first} { m msg "Removing now empty projects ..." }
	    set first 0
	    m msg "- [color note [m project name $p]] ..."
	    m project remove $p	    
	}
    }

    ShowCurrent $config
    SiteRegen
    OK
}

proc ::m::glue::cmd_rename {config} {
    debug.m/glue {[debug caller] | }
    package require m::project
    package require m::repo
    package require m::store

    m db transaction {
	set project [$config @project] ; debug.m/glue {project : $project}
	set newname [$config @name]    ; debug.m/glue {new name: $newname}
	set oldname [m project name $project]

	set merge  [$config @merge]
	set action [expr {$merge ? "Merging" : "Renaming"}]
	set al [string length $action]
	
	m msg "$action [color note $oldname] ..."
	if {$newname eq $oldname} {
	    m::cmdr::error \
		"The new name is the same as the current name." \
		NOP
	}

	m msg "[format %${al}s to] [color note $newname]"
	m msg {}
	
	if {[m project has $newname]} {
	    if {!$merge} {
		m::cmdr::error \
		    "New name [color note $newname] already present" \
		    HAVE_ALREADY NAME
	    }
	} else {
	    # Destination does not exist. Merge is nonsense
	    set merge 0
	}

	Rename $merge $project $newname
    }

    ShowCurrent $config
    SiteRegen
    OK
}

proc ::m::glue::cmd_merge {config} {
    debug.m/glue {[debug caller] | }
    package require m::project
    package require m::repo
    package require m::rolodex
    package require m::store
    package require m::vcs

    m db transaction {
	set repos [Dedup [MergeFill [$config @repositories]]]
	# __Attention__: Cannot place the mergefill into a generate
	# clause, the parameter logic is too simple (set / not set) to
	# handle the case of `set only one`.
	debug.m/glue {repos = ($repos)}

	if {[llength $repos] < 2} {
	    m::cmdr::error \
		"Not enough repositories to merge stores" \
		NOP
	}

	set secondaries [lassign $repos primary]
	m msg "Target:  [color note [m repo url $primary]]"

	foreach secondary $secondaries {
	    m msg "Merging: [color note [m repo url $secondary]]"
	    Merge $primary $secondary
	}
    }

    ShowCurrent $config
    SiteRegen
    OK
}

proc ::m::glue::cmd_split {config} {
    debug.m/glue {[debug caller] | }
    package require m::project
    package require m::repo
    package require m::rolodex
    package require m::store
    package require m::vcs

    m db transaction {
	set repo [$config @repository]
	set rinfo [m repo get $repo]
	dict with rinfo {}
	#    url    : repo url
	#    vcs    : vcs id
	#    vcode  : vcs code
	#    project: project id
	#    name   : project name
	# -> store  : id of backing store for repo

	m rolodex push $repo
	m rolodex commit

	m msg "Separating [m vcs name $vcs] repository [color note $url]"
	m msg "from any other repository it shares its store with"

	set sharers [m store repos $store]

	if {[llength $sharers] < 2} {
	    # Store is unshared.
	    m::cmdr::error \
		"The repository already has its own store." \
		ATOMIC

	}

	m msg* "Splitting store ..."
	
	set newstore [m store cleave $store $name]
	m repo store! $repo $newstore

	OKx
    }

    ShowCurrent $config
    SiteRegen
    OK
}

proc ::m::glue::cmd_current {config} {
    debug.m/glue {[debug caller] | }

    ShowCurrent $config
    OK
}

proc ::m::glue::cmd_swap_current {config} {
    debug.m/glue {[debug caller] | }
    package require m::repo
    package require m::rolodex

    m db transaction {
	m rolodex swap
	m rolodex commit
    }

    ShowCurrent $config
    OK
}

proc ::m::glue::cmd_set_current {config} {
    debug.m/glue {[debug caller] | }
    package require m::repo
    package require m::rolodex

    m db transaction {
	m rolodex push [$config @repository]
	m rolodex commit
    }

    ShowCurrent $config
    OK
}

proc ::m::glue::cmd_update {config} {
    debug.m/glue {[debug caller] | }
    package require m::project
    package require m::state
    package require m::store
    package require struct::set

    set startcycle [m state start-of-current-cycle]
    set nowcycle   [clock seconds]

    m db transaction {
	set verbose  [$config @verbose]
	set repos    [UpdateRepos $startcycle $nowcycle [$config @repositories]]

	debug.m/glue {repositories = ($repos)}

	foreach repo $repos {
	    set ri [m repo get $repo]
	    dict with ri {}
	    # url, active, issues, vcs, vcode, project, name, store
	    # min/max/win_sec, checked, origin

	    set si [m store get $store]
	    # size, vcs, sizep, commits, commitp, vcsname, updated, changed, created
	    # (atted, min/max/win, remote, active)
	    set before [dict get $si commits]

	    set durl [color note $url]
	    if {$origin eq {}} { set durl [color bg-cyan $durl] }
	    
	    m msg "Updating repository $durl ..."
	    m msg "In project          [color note $name]"
	    if {$verbose} {
		m msg  "  [color note [string totitle $vcode]] store ... "
	    } else {
		m msg* "  [string totitle $vcode] store ... "
	    }
	    set primary [expr {$origin eq {}}]

	    # -- has_issues, is_active/enable -- fork handling

	    set now [clock seconds]
	    lassign [m store update $primary $url $store $nowcycle $now $before] \
		ok duration commits size forks
	    set attend [expr {!$ok || [m store has-issues $store]}]
	    set suffix ", in [color note [m format interval $duration]]"
	    
	    m repo times  $repo $duration $now $attend
	    if {!$primary && $attend} { m repo enable $repo 0 }

	    if {!$ok} {
		lassign [m vcs caps $store] _ e
		m msg "[color bad Fail]$suffix"
		m msg $e

		continue		
	    } elseif {$before != $commits} {
		set delta [expr {$commits - $before}]
		if {$delta < 0} {
		    set mark bad
		} else {
		    set mark note
		    set delta +$delta
		}
		m msg "[color note Changed] $before $commits ([color $mark $delta])$suffix"
	    } elseif {$verbose} {
		m msg "[color note "No changes"]$suffix"
	    } else {
		m msg "No changes$suffix"
	    }

	    if {$primary} {
		# check currently found forks against what is claimed by the system
		set forks_prev [m repo fork-locations $repo]
		
		lassign [struct::set intersect3 $forks_prev $forks] same removed added
		# previous - current => removed from previous
		# current  - previous => added over previous

		# Actions:
		# - The removed forks are detached from the primary.
		#   We keep the repository. Activation state is unchanged
		#
		# - Unchanged forks are reactivated if they got disabled.
		#
		# - New forks are attempted to be added back
		#   This may actually reclaim a fork which was declaimed before.
		#
		#   Note: Only these new forks have to be validated!
		#   Note: Tracking threshold is irrelevant here.
		
		foreach r $removed {
		    m msg "  [color warning {Detaching lost}] [color note $r]"
		    m repo declaim [m repo id $r]
		}
		foreach r $same {
		    # m msg "  Unchanged      [color note $r], activating"
		    m repo enable [m repo id $r]
		}

		AddForks $added $repo $vcs $vcode $name $project
	    }
	}
    }

    SiteRegen
    OK
}

proc ::m::glue::cmd_updates {config} {
    debug.m/glue {[debug caller] | }
    package require m::store

    m db transaction {

	# m store updates XXX rework actually repos
	
	# TODO: get status (stderr), show - store id
	set series {}
	foreach row [TruncH [m store updates] [expr {[$config @th]-1}]] {


	    
	    if {[lindex $row 0] eq "..."} {
		lappend series [list ... {} {} {} {} {} {}]
		continue
	    }
	    # store mname vcode changed updated created size active
	    # remote sizep commits commitp mins maxs lastn url origin

	    dict with row {}
	    if {$created eq "."} {
		lappend series [list - - - - - - -]
		continue
	    }

	    set changed [m format epoch $changed]
	    set updated [m format epoch $updated]
	    set created [m format epoch $created]
	    set dsize   [DeltaSize $size $sizep]
	    set dcommit [DeltaCommit $commits $commitp]
	    set lastn   [LastTime $lastn]

	    if {$origin eq {}} { set url [color bg-cyan $url] }

	    lappend series [list $url $vcode $dsize $dcommit $lastn $changed $updated $created]
	}
    }
    lassign [TruncW \
		 {Project VCS Size Commits Time Changed Updated Created} \
		 {1       0   0    0       0    0       0       0} \
		 $series [$config @tw]] \
	titles series
    m msg "Cycles: [m format epoch [m state start-of-previous-cycle]] ... [m format epoch [m state start-of-current-cycle]] ..."
    [table t $titles {
	foreach row $series {
	    $t add {*}$row
	}
    }] show
    OK
}

proc ::m::glue::cmd_pending {config} {
    debug.m/glue {[debug caller] | }
    package require m::project
    package require m::state

    set tw [$config @tw]
    set th [$config @th] ; incr th -1 ;# Additional line before the table (counts).

    set nrepo    [m repo count]
    set npending [m repo count-pending]

    m db transaction {
	set series {}
	set take   [m state take]

	foreach {pname url origin nforks} [m repo pending] {
	    if {$origin eq {}} { set url [color bg-cyan $url] }
	    set row {}
	    if {$take} {
		lappend row *
		incr take -1
	    } else {
		lappend row {}
	    }
	    lappend row $url $nforks $pname
	    lappend series $row
	}
    }

    lassign [TruncW \
		 {{} Repository Forks Project} \
		 {0  0          0     1} \
		 [TruncH $series $th] $tw] \
	titles series

    puts @[color note $npending]/$nrepo
    [table t $titles {
	foreach row $series {
	    $t add {*}$row
	}
    }] show
    OK
}

proc ::m::glue::cmd_issues {config} {
    debug.m/glue {[debug caller] | }
    package require m::project
    package require m::repo
    package require m::rolodex
    package require m::store

    m db transaction {
	set series {}
	foreach row [m store issues] {	;# XXX rework actually repo issues
	    dict with row {}
	    # store mname vcode changed updated created size active remote rid url
	    set size [m format size $size]

	    if {$origin eq {}} { set url [color bg-cyan $url] }

	    lappend series [list $rid $url $mname $vcode $size]
	    m rolodex push $rid
	}

	m rolodex commit
	set n [llength $series]

	set table {}
	foreach row $series {
	    incr n -1
	    set row [lassign $row rid]
	    set dex [m rolodex id $rid]
	    set tag @$dex
	    if {$n == 1} { lappend tag @p }
	    if {$n == 0} { lappend tag @c }
	    lappend table [list $tag {*}$row]
	}
    }
    lassign [TruncW \
		 {Tag Repository Project VCS Size} \
		 {0   0          1       0   0} \
		 $table [$config @tw]] \
	titles series
    [table t $titles {
	foreach row $series {
	    $t add {*}[C $row 1 note] ;# 1 => url
	}
    }] show
    OK
}

proc ::m::glue::cmd_disabled {config} {
    debug.m/glue {[debug caller] | }
    package require m::project
    package require m::repo
    package require m::rolodex
    package require m::store

    m db transaction {
	set series {}
	foreach row [m store disabled] {	# XXX REWORK actually repo state
	    dict with row {}
	    # store mname vcode changed updated created size active remote attend rid url origin
	    set size [m format size $size]

	    if {$origin eq {}} { set url [color bg-cyan $url] }
	    
	    lappend series [list $rid $url $mname $vcode $size]
	    m rolodex push $rid
	}
	m rolodex commit
	set n [llength $series]

	set table {}
	foreach row $series {
	    incr n -1
	    set row [lassign $row rid]
	    set dex [m rolodex id $rid]
	    set tag @$dex
	    if {$n == 1} { lappend tag @p }
	    if {$n == 0} { lappend tag @c }
	    lappend table [list $tag {*}$row]
	}
    }
    lassign [TruncW \
		 {Tag Repository Project VCS Size} \
		 {0   0          1       0   0} \
		 $table [$config @tw]] \
	titles series
    [table t $titles {
	foreach row $series {
	    $t add {*}[C $row 1 note] ;# 1 => url
	}
    }] show
    OK
}

proc ::m::glue::cmd_list {config} {
    debug.m/glue {[debug caller] | }
    package require m::repo
    package require m::rolodex
    package require m::state

    m db transaction {
	if {[$config @pattern set?]} {
	    # Search, shows all results. Does not move the cursor.
	    set pattern [$config @pattern]
	    set series [m repo search $pattern]
	} else {
	    # No search, show a chunk of the list as per options.
	    if {[$config @repository set?]} {
		set repo [$config @repository]
		set ri [m repo get $repo]
		dict with ri {}
		# -> url    : repo url
		#    vcs    : vcs id
		#    vcode  : vcs code
		#    project: project id
		# -> name   : project name
		#    store  : id of backing store for repo
		set first [list $name $url]
		debug.m/glue {from request: $first}
		unset name url vcs vcode store ri project
	    } else {
		set first [m state top]
		debug.m/glue {from state: $first}
	    }
	    set limit [$config @limit]
	    if {$limit == 0} {
		set limit [expr {[$p config @th]-7}]
	    }

	    lassign [m repo get-n $first $limit] next series

	    debug.m/glue {next   ($next)}
	    m state top $next
	}
	# series = list (dict (primary name url rid vcode sizekb active sizep commits commitp mins maxs lastn))

	debug.m/glue {series ($series)}

	set n 0
	foreach row $series {
	    m rolodex push [dict get $row id]
	    incr n
	}

	set idx -1
	set table {}
	foreach row $series {
	    dict with row {}
	    # primary name url id vcode sizekb active sizep commits commitp mins maxs lastn
	    incr idx
	    #set url [color note $url]
	    set ix  [m rolodex id $id]
	    set tag {}
	    if {$ix  ne {}}     { lappend tag @$ix }
	    if {$idx == ($n-2)} { lappend tag @p }
	    if {$idx == ($n-1)} { lappend tag @c }
	    set a [expr {$active ? "A" : "-"}]

	    if {$primary} { set url [color bg-cyan $url] }
	    
	    set dsize   [DeltaSize $sizekb $sizep]
	    set dcommit [DeltaCommit $commits $commitp]
	    set lastn   [LastTime $lastn]

	    lappend table [list $tag $a $url $name $vcode $dsize $dcommit $lastn]
	    # ................. 0    1   2    3    4      5      6        7
	}
    }

    # See also ShowCurrent
    # TODO: extend list with store times ?
    lassign [TruncW \
		 {Tag {} Repository Project VCS Size Commits Time} \
		 {0   0  0          1       0   -1   -1      0} \
		 $table [$config @tw]] \
	titles series
    [table t $titles {
	foreach row $series {
	    $t add {*}[C $row 2 note] ;# 2 => url
	}
    }] show
    OK
}

proc ::m::glue::cmd_reset {config} {
    debug.m/glue {[debug caller] | }
    package require m::state

    m state top {}

    m msg "List paging reset to start from the top/bottom"
    OK
}

proc ::m::glue::cmd_rewind {config} {
    debug.m/glue {[debug caller] | }
    puts [info level 0]		;# XXX TODO FILL-IN rewind
    return
}

proc ::m::glue::cmd_limit {config} {
    debug.m/glue {[debug caller] | }
    package require m::rolodex
    package require m::state

    m db transaction {
	if {[$config @limit set?]} {
	    set limit [$config @limit]

	    m state limit $limit
	    m rolodex truncate
	}

	set n [m state limit]
    }

    if {$n == 0} {
	m msg "Per list/rewind, [color note {adjust to terminal height}]"
    } else {
	set e [expr {$n == 1 ? "entry" : "entries"}]
	m msg "Per list/rewind, show up to [color note $n] $e"
    }
    OK
}

proc ::m::glue::cmd_statistics {config} {
    debug.m/glue {[debug caller] | }
    package require m::project
    package require m::repo
    package require m::store

    m db transaction {
	set stats [m project statistics]
    }

    dict with stats {}
    #array set _ $stats ; parray _
    dict with st    {}
    #unset _ ; array set _ $st ; parray _

    set sz_min    [m format size $sz_min]
    set sz_max    [m format size $sz_max]
    set sz_mean   [m format size $sz_mean]
    set sz_median [m format size $sz_median]
    
    [table/d t {
	$t add Projects       $np
	$t add Repositories   $nr
	$t add "- Issues"     $ni
	$t add "- Disabled"   $nd
	$t add Stores         $ns
	$t add "- Lost"       $nl
	$t add "- Statistics" ""
	$t add "  - Size"     "$sz_min ... $sz_max"
	$t add "      Total " [m format size $sz]
	$t add "      Mean  " $sz_mean
	$t add "      Median" $sz_median
	$t add "  - Commits"  "$cm_min ... $cm_max"
	$t add "      Mean  " $cm_mean
	$t add "      Median" $cm_median
	$t add Cycles {}
	$t add "- Current began" [m format epoch $cc]
	$t add "  - Changes"     $ncc
	$t add "- Last began"    [m format epoch $pc]
	$t add "  - Changes"     $npc
	$t add "- Taking"        [m format interval [expr {$cc - $pc}]]
    }] show
    OK
}

proc ::m::glue::cmd_project {config} {
    debug.m/glue {[debug caller] | }
    package require m::project
    package require m::repo

    set project [$config @project]
    
    m db transaction {
	set pname [m project name $project]
	foreach repo [m repo for $project] {
	    set ri [m repo get $repo]
	    dict with ri {}
	    # -> vcode, store
	    lappend r [list [string totitle $vcode] [Short $repo] $store]
	}
    }

    [table/d t {
	$t add {} [color note $pname]
	$t add Repositories [[table s {VCS Repository Store} {
	    foreach item [lsort -index 1 $r] {
		$s add {*}$item
	    }
	}] show return]
    }] show
    OK
    return
}

proc ::m::glue::cmd_projects {config} {
    debug.m/glue {[debug caller] | }
    package require m::project
    package require m::state

    m db transaction {
	if {[$config @pattern set?]} {
	    # Search, shows all results. Does not move the cursor.
	    set pattern [$config @pattern]
	    set series [m project search $pattern]
	} else {
	    # No search, show a chunk of the list as per options.
	    if {[$config @project set?]} {
		set project [$config @project]
		set pi [m project get $project]
		dict with pi {}
		# - name nrepos nforks
		set first $name
		debug.m/glue {from request: $first}
		unset name nrepos nforks
	    } else {
		# Note: top is repository, use containing project.
		set first [m repo project [m state top]]
		debug.m/glue {from state: $first}
	    }
	    set limit [$config @limit]
	    if {$limit == 0} {
		set limit [expr {[$p config @th]-7}]
	    }

	    lassign [m project get-n $first $limit] next series

	    debug.m/glue {next   ($next)}
	    # next is project -> chose any repo in it as new top.
	    m state top [m project a-repo $next]
	}
	# series = list (dict (id name nrepos nstores))
	# #x, for x in set-of-vcs ?

	debug.m/glue {series ($series)}

	set idx -1
	set table {}

	set trepos  0
	set tstores 0
	
	foreach row $series {
	    dict with row {}
	    # name nrepos nstores
	    lappend table [list $name $nrepos $nstores]
	    # ................. 0     1       2
	    incr trepos $nrepos
	    incr tstores $nstores
	}
    }

    set seprepos  [string repeat - [string length $trepos]]
    set sepstores [string repeat - [string length $tstores]]
    
    lassign [TruncW \
		 {Project #Repositories #Stores} \
		 {1       0             0} \
		 $table [$config @tw]] \
	titles series
    [table t $titles {
	foreach row $series {
	    $t add {*}[C $row 0 note] ;# 0 => name
	}
	$t add {}     $seprepos $sepstores
	$t add Totals $trepos $tstores
    }] show
    OK
}

proc ::m::glue::cmd_submissions {config} {
    debug.m/glue {[debug caller] | }
    package require m::submission

    m db transaction {
	# Dynamic: Description, Submitter
	set series {}
	foreach {id when url vcode desc email submitter} [m submission all] {
	    set id %$id
	    set when [m format epoch $when]

	    lappend series [list $id $when $url $vcode $desc $email $submitter]
	}
    }
    lassign [TruncW \
		 {{} When Url VCS Description Email Submitter} \
		 {0  0    0   0   3           0     1} \
		 $series [$config @tw]] \
	titles series
    [table t $titles {
	foreach row $series {
	    $t add {*}[C $row 2 note] ;# 2 => url
	}
    }] show
    OK
}

proc ::m::glue::cmd_rejected {config} {
    debug.m/glue {[debug caller] | }
    package require m::submission

    m db transaction {
	set series {}
	foreach {url reason} [m submission rejected] {
	    lappend series [list $url $reason]
	}
    }
    lassign [TruncW \
		 {Url Reason} \
		 {1   0} \
		 $series [$config @tw]] \
	titles series
    [table t $titles {
	foreach row $series {
	    $t add {*}[C $row 0 note] ;# 0 => url
	}
    }] show
    OK
}

proc ::m::glue::cmd_submit {config} {
    debug.m/glue {[debug caller] | }
    package require m::submission
    package require m::repo

    # session id for cli, daily rollover, keyed to host and user
    set sid "cli.[expr {[clock second] % 86400}]/[info hostname]/$::tcl_platform(user)"

    m db transaction {
	set url       [Url $config]
	set email     [$config @email]
	set submitter [$config @submitter]
	set vcode     [$config @vcs-code]
	set desc      [$config @name]
	set url       [m vcs url-norm $vcode $url]

	set name <[color note $email]>
	if {$submitter ne {}} {
	    set name "[color note $submitter] $name"
	}

	m msg "Submitted:   [color note $vcode] @ [color note $url]"
	if {$desc ne {}} {
	    m msg "Description: [color note $desc]"
	}
	m msg "By:          $name"

	if {[m repo has $url]} {
	    m msg [color bad "Already known"]
	    return
	}

	if {[set reason [m submission dup $url]] ne {}} {
	    m msg [color bad "Already rejected: $reason"]
	    return
	} elseif {[m submission has^ $url $sid]} {
	    m msg [color warning "Already submitted, replacing"]
	} else {
	    m msg [color warning "Adding"]
	}

	m submission add $url $sid $vcode $desc $email $submitter
    }
    SiteRegen
    OK
}

proc ::m::glue::cmd_accept {config} {
    debug.m/glue {[debug caller] | }
    package require m::project
    package require m::repo
    package require m::rolodex
    package require m::store
    package require m::submission
    package require m::mail::generator
    package require m::mailer

    m db transaction {
	set nomail     [$config @nomail]
	set submission [$config @id]
	set details    [m submission get $submission]
	dict with details {}
	# -> url
	#    email
	#    submitter
	#    when
	#    desc
	#    vcode
	set name [color note $email]
	if {$submitter ne {}} {
	    append name " ([color note $submitter])"
	}

	m msg "Accepted $url"
	m msg "By       $name"

	Add $config
	m submission accept $submission

	# TODO: Ordering ... mail failure has to undo the store
	# creation, and other non-database effects of `Add`.
	if {!$nomail} {
	    m msg "Sending acceptance mail to $email ..."

	    dict set details when [m format epoch $when]
	    if {![info exists $submitter] || ($submitter eq {})} {
		dict set details submitter $email
	    }

	    MailHeader accept_mail Accepted $desc
	    lappend accept_mail "Your submission has been accepted."
	    lappend accept_mail "The repository should appear on our web-pages soon."
	    MailFooter accept_mail

	    set accept_mail [join $accept_mail \n]
	    m mailer to $email [m mail generator reply $accept_mail $details]
	}
    }
    SiteRegen
    OK
}

proc ::m::glue::cmd_reject {config} {
    debug.m/glue {[debug caller] | }
    package require m::submission
    package require m::mail::generator
    package require m::mailer
    package require m::reply

    m db transaction {
	set submissions [$config @id]
	set cause       [$config @cause]

	set cdetails [m reply get $cause]
	dict with cdetails {}
	debug.m/glue {reply $cause => ($cdetails)}
	# -> text
	#    mail

	if {[$config @mail set?]} {
	    set mail [$config @mail]
	}

	m msg "Cause: $text"

	foreach submission $submissions {
	    set details [m submission get $submission]
	    dict with details {}
	    # -> url
	    #    email
	    #    submitter
	    #    when
	    #    desc
	    #    vcode
	    set name [color note $email]
	    if {$submitter ne {}} {
		append name " ([color note $submitter])"
	    }

	    m msg "  Rejected $url ($desc)"
	    m msg "  By       $name"

	    m submission reject $submission $text

	    if {!$mail} continue
	    m msg "    Sending rejection notice to $email ..."

	    dict set details when [m format epoch $when]
	    if {![info exists $submitter] || ($submitter eq {})} {
		dict set details submitter $email
	    }

	    MailHeader decline_mail Declined $desc
	    lappend    decline_mail "We are sorry to tell you that we are declining it."
	    lappend    decline_mail $text ;# cause
	    MailFooter decline_mail

	    set decline_mail [join $decline_mail \n]
	    m mailer to $email [m mail generator reply $decline_mail $details]
	    unset decline_mail
	}
    }
    SiteRegen
    OK
}

proc ::m::glue::cmd_drop {config} {
    debug.m/glue {[debug caller] | }
    package require m::submission

    m db transaction {
	set rejections [$config @rejections]
	foreach rejection $rejections {
	    m msg "  Dropping [color note [m submission rejected-url $rejection]]"

	    m submission drop $rejection
	}
    }
    SiteRegen
    OK
}

proc ::m::glue::cmd_test_cycle_mail {config} {
    debug.m/glue {[debug caller] | }
    package require m::db
    package require m::state

    if {[$config @mail]} {
	# For mailing no color control sequences in the output!
	set active [cmdr color active]
	cmdr color activate 0
	m db transaction {
	    set message [ComeAroundMail [m state mail-width] [m state start-of-current-cycle] [clock seconds]]
	}
	cmdr color activate $active
	package require m::mail::generator
	package require m::mailer
	m mailer to [$config @destination] [m mail generator reply $message {}]
    } else {
	m db transaction {
	    set message [ComeAroundMail [$config @tw] [m state start-of-current-cycle] [clock seconds]]
	}
	m msg $message
    }
    OK
}

proc ::m::glue::cmd_test_mail_config {config} {
    debug.m/glue {[debug caller] | }
    package require m::mailer
    package require m::mail::generator

    try {
	m mailer to [$config @destination] [m mail generator test]
    } on error {e o} {
	m msg [color bad $e]
	exit
    }
    OK
}

proc ::m::glue::cmd_test_vt_repository {config} {
    debug.m/glue {[debug caller] | }
    package require m::repo

    set map [m repo known]
    [table/d t {
	foreach k [lsort -dict [dict keys $map]] {
	    set v [dict get $map $k]
	    $t add $v $k
	}
    }] show
    OK
}

proc ::m::glue::cmd_test_vt_project {config} {
    debug.m/glue {[debug caller] | }
    package require m::project

    set map [m project known]
    [table/d t {
	foreach k [lsort -dict [dict keys $map]] {
	    set v [dict get $map $k]
	    $t add $v $k
	}
    }] show
    OK
}

proc ::m::glue::cmd_test_vt_reply {config} {
    debug.m/glue {[debug caller] | }
    package require m::reply

    set map [m reply known]
    [table/d t {
	foreach k [lsort -dict [dict keys $map]] {
	    set v [dict get $map $k]
	    $t add $v $k
	}
    }] show
    OK
}

proc ::m::glue::cmd_test_vt_submission {config} {
    debug.m/glue {[debug caller] | }
    package require m::submission

    set map [m submission known]
    [table/d t {
	foreach k [lsort -dict [dict keys $map]] {
	    set v [dict get $map $k]
	    $t add $v $k
	}
    }] show
    OK
}

proc ::m::glue::cmd_debug_levels {config} {
    debug.m/glue {[debug caller] | }
    puts [info level 0]		;# XXX TODO FILL-IN debug levels
    return
}

# # ## ### ##### ######## ############# ######################

proc ::m::glue::MailFooter {mv} {
    debug.m/glue {[debug caller] | }
    upvar 1 $mv mail

    lappend mail ""
    lappend mail "Sincerely"
    lappend mail "  @sender@"
    return
}

proc ::m::glue::MailHeader {mv label desc} {
    debug.m/glue {[debug caller] | }
    upvar 1 $mv mail

    set title [m state site-title]
    if {$title eq {}} { set title Mirror }

    lappend mail "$title. $label submission of @s:url@"
    lappend mail "Hello @s:submitter@"
    lappend mail ""
    lappend mail "Thank you for your submission of"
    if {$desc ne {}} {
	lappend mail "  \[@s:desc@](@s:url@)"
    } else {
	lappend mail "  @s:url@"
    }
    lappend mail "to $title, as of @s:when@"
    lappend mail ""
    return
}

proc ::m::glue::Url {config} {
    debug.m/glue {[debug caller] | }

    set url [$config @url]
    debug.m/glue {[debug caller] | re'url = $url }

    try {
	set in  [$config @url string]
	debug.m/glue {[debug caller] | in'url = $in }
    } trap {CMDR PARAMETER UNDEFINED} {} {
	# This is possible for cmd_accept where the state url by
	# glue::gen_url, which leaves out the string information
	set in $url
    }

    if {$url ne $in} {
	m msg "[color warning Redirected] to [color note $url]"
	m msg "From          [color note $in]"
    }

    debug.m/glue {[debug caller] | --> $url }
    return $url
}

proc ::m::glue::ImportRead {label chan} {
    debug.m/glue {[debug caller] | }
    m msg "Reading [color note $label] ..."
    return [split [string trim [read $chan]] \n]
    #         :: list (command)
    # command :: list ('M' name)        - old: Mirrorset
    #          | list ('P' name)        - new: Project
    #          | list ('R' vcode url)   -      Repository
    #          | list ('E' vcode url)   - new: Repository, Extend previous
    #          | list ('B' url)         - new: Repository, Set Base
}

proc ::m::glue::ImportVerify {commands} {
    debug.m/glue {ImportVerify}
    # commands :: list (command)
    # command  :: list ('M' name)       - old: Mirrorset
    #           | list ('P' name)       - new: Project
    #           | list ('R' vcode url)  -      Repository
    #           | list ('E' vcode url)  - new: Repository, Extend previous
    #           | list ('B' url)        - new: Repository, Set Base
    #
    # The verification not only checks syntax and use of the commands,
    # it also assembles the internal data structures linking projects,
    # repositories and stores.
    
    m msg "Verifying ..."

    # Parsing state, and spec assembly
    #
    # 'vcs'     -> (code/name -> '.')
    # 'project' -> 'lno'  -> int
    #           -> 'repo' -> (url -> '.')
    # 'repo'    -> (url -> 'vcs'     -> code
    #                   -> 'store'   -> id
    #                   -> 'project' -> name)
    # 'store'   -> (id -> (url -> '.'))

    # In memory quick access to VCS data
    foreach {code name} [m vcs all] {
	dict set state vcs $code .
	dict set state vcs $name .
    }

    dict set state lno      0
    dict set state lfmt     %-[string length [llength $commands]]s
    dict set state issues   {} ;# list (string)
    dict set state run      {} ;# list(url) - current repos
    dict set state base     {} ;# no base store
    dict set state resolved {} ;# url -> resolved
    #
    dict set state project  {} ;# (name -> (lno, url...))
    dict set state repo     {} ;# url -> (vcs, store)
    dict set state store    {} ;# id  -> list (url)
    
    set expected  {
	m 2 p 2 b 2 e 3 r 3 proj 2 base 2 extr 3 repo 3
    }
    
    foreach command $commands {
	dict incr state lno
	debug.m/glue {[format [dict get $state lfmt] [dict get $state lno]]: '$command'}
	
	# strip (trailing) comments, leading & trailing whitespace
	regsub -- "#.*\$" $command {} command
	set command [string trim $command]

	# skip empty lines
	if {$command eq {}} continue

	Ping "  $command"
	
	set args [lassign $command cmd]
	set lcmd [string tolower $cmd]
	if {![dict exists $expected $lcmd]} {
	    ImportError "Unknown command: $command"
	    continue
	} elseif {![ImportCheckArgs [dict get $expected $lcmd]]} {
	    ImportError "Bad syntax: $command"
	    continue
	}

	ImportVerify/[dict get {
	    m    Project
	    p    Project b    Base e    Extend r    Repository
	    proj Project base Base extr Extend repo Repository
	} $lcmd] {*}$args
    }

    # Start a last ping to erase the animation remnants.
    Ping ""
    set issues [dict get $state issues]

    #array set _ $state ; parray _
    
    if {[llength $issues]} {
	m::cmdr::error \n\t[join $issues \n\t] IMPORT BAD
    }

    dict unset state lno
    #dict unset state lfmt  -- Keep, for warnings when skipping
    dict unset state issues
    dict unset state run
    dict unset state base
    dict unset state resolved
    dict unset state vcs

    return $state
}

proc ::m::glue::IS/KnownBase {id store} {
    dict for {url _} [dict get $store $id] {
	if {[m repo has $url]} { return $url }
    }
    return {}
}

proc ::m::glue::IS/AddResolved {url resolved} {
    debug.m/glue {[debug caller] | }
    upvar 1 state state
    dict set state resolved $url $resolved
    return
}

proc ::m::glue::IS/HasResolved {url} {
    debug.m/glue {[debug caller] | }
    upvar 1 state state
    return [dict exists $state resolved $url]
}

proc ::m::glue::IS/Resolved {url} {
    debug.m/glue {[debug caller] | }
    upvar 1 state state
    return [dict get $state resolved $url]
}

proc ::m::glue::IS/HasRepo {url} {
    upvar 1 state state
    return [dict exists $state repo $url]
}

proc ::m::glue::IS/CheckVCS {vcs} {
    upvar 1 state state
    return [dict exists $state vcs $vcs]
}

proc ::m::glue::IS/NewStore {} {
    upvar 1 state state
    set newid [dict size [dict get $state store]]
    dict set state store $newid {}
    return $newid
}

proc ::m::glue::IS/SetBase {store} {
    upvar 1 state state
    dict set state base $store
    return
}

proc ::m::glue::IS/Base {} {
    upvar 1 state state
    return [dict get $state base]
}

proc ::m::glue::IS/RepoStore {url} {
    upvar 1 state state
    return [dict get $state repo $url store]
}

proc ::m::glue::IS/AddRepo {url vcs store} {
    upvar 1 state state
    dict set state repo $url vcs   $vcs
    dict set state repo $url store $store
    dict set state repo $url lno   [dict get $state lno]
    #dict set state repo $url project ?

    # Add repo to current run for coming project
    dict set state run $url .

    # Add repo to its store.
    dict set state store $store $url .
    return
}

proc ::m::glue::IS/HasProject {name} {
    upvar 1 state state

    return [dict exists $state project $name]
}

proc ::m::glue::IS/ExtendProject {name} {
    upvar 1 state state

    dict for {url _} [dict get $state run] {
	dict set state project $name repo    $url .
	dict set state repo    $url  project $name
    }
    dict set state run {}
    return
}

proc ::m::glue::IS/NumProjects {} {
    upvar 1 state state
    return [dict size [dict get $state project]]
}

proc ::m::glue::IS/AddProject {name} {
    upvar 1 state state

    set run [dict get $state run]
    
    dict set state project $name lno  [dict get $state lno]
    dict set state project $name repo $run
    dict set state run {}

    # Fill project back references
    dict for {url _} $run {
	dict set state repo $url project $name
    }
    return
}

proc ::m::glue::IS/CheckRepo {vcs url} {
    upvar 1 state state

    if {![IS/CheckVCS $vcs]} { ImportError "Unknown vcs '$vcs'"; return }
    Ping+ " ..."

    if {![m url ok $url resolved]} { ImportError "Bad url: $url" ; return }
    IS/AddResolved $url $resolved

    if {$url ne $resolved} {
	Ping+ " [color warning redirected] $resolved"
    }
    Ping+ " [color good Ok]"
    
    if {[IS/HasRepo $resolved]} {
	ImportError "Duplicate repository $url" ; return {no {}}
    }

    Close
    return [list yes $resolved]
}

proc ::m::glue::ImportVerify/Repository {vcs url} {
    debug.m/glue {[debug caller] | }
    upvar 1 state state
    
    lassign [IS/CheckRepo $vcs $url] ok resolved
    if {!$ok} return

    set sid [IS/NewStore]
    IS/SetBase $sid
    IS/AddRepo $resolved $vcs $sid
    return    
}

proc ::m::glue::ImportVerify/Extend {vcs url} {
    debug.m/glue {[debug caller] | }
    upvar 1 state state

    set base [IS/Base]
    if {$base eq {}} { ImportError "No base known for $url" ; return }

    lassign [IS/CheckRepo $vcs $url] ok resolved
    if {!$ok} return

    IS/AddRepo $resolved $vcs $base
    return    
}

proc ::m::glue::ImportVerify/Base {url} {
    debug.m/glue {[debug caller] | }
    upvar 1 state state
    
    #Ping+ " extending $url"

    if {![IS/HasResolved $url]} { ImportError "Unresolvable reference $url" ; return }
    set url [IS/Resolved $url]
    if {![IS/HasRepo $url]}     { ImportError "Bad base reference $url" ; return }

    IS/SetBase [IS/RepoStore $url]
    return
}

proc ::m::glue::ImportVerify/Project {name} {
    debug.m/glue {[debug caller] | }
    upvar 1 state state

    if {[IS/HasProject $name]} {
	IS/ExtendProject $name
	ImportWarning "[color warning Duplicate] project [color note $name]. Merged"
    } else {
	IS/AddProject $name
    }

    IS/SetBase {}
    return
}
    
proc ::m::glue::ImportError {e} {
    debug.m/glue {[debug caller] | }
    upvar 1 state state
    
    dict with state {}
    # lno, lfmt, issues, projects, base    
    dict lappend state issues "Line [format $lfmt $lno]: $e"
    return
}
    
proc ::m::glue::ImportWarning {w} {
    debug.m/glue {[debug caller] | }
    upvar 1 state state
    
    dict with state {}
    # lno, lfmt, issues, projects, base
    m msg "Line [format $lfmt $lno]: $w"
    return
}

proc ::m::glue::ImportCheckArgs {expected} {
    debug.m/glue {[debug caller] | }

    upvar 1 command command
    return [expr {[llength $command] == $expected}]
}

proc ::m::glue::ImportSkipKnown {state} {
    debug.m/glue {ImportSkipKnown}
    m msg "Weeding ..."

    dict with state {}
    # 'project' -> 'lno'  -> int
    #           -> 'repo' -> (url -> '.')
    # 'repo'    -> (url -> 'vcs'     -> code
    #                   -> 'store'   -> id
    #                   -> 'project' -> name)
    # 'store'   -> (id -> (url -> '.'))
    
    #array set _ $state ; parray _

    set storebak $store ;# store backup.

    # Look for known repositories, and eliminate them.
    dict for {url spec} [dict get $state repo] {
	if {![m repo has $url]} {
	    # Repository is not known. Keep. Simplify.
	    dict unset spec lno
	    dict unset spec project
	    dict set state repo $url $spec
	    continue
	}
	
	# Repo is known. Drop all references and uses in the structure.
	dict with spec {}
	# vcs, store, project, lno

	dict set state lno $lno
	ImportWarning "[color warning Skip] known repository [color note $url]"

	dict unset state repo                  $url ;# Main entry
	dict unset state project $project repo $url ;# Reference from project.
	dict unset state store   $store        $url ;# Reference from store.
    }

    # Look for projects with no repositories
    dict for {name spec} [dict get $state project] {
	if {[dict size [dict get $spec repo]]} {
	    # Project is used. Simplify.
	    dict set state project $name [dict get $spec repo]
	    continue
	}

	# Project is empty.
	dict with spec {}
	# lno, repo
	dict set state lno $lno
	ImportWarning "[color warning Skip] empty project [color note $name]"
	dict unset state project $name
    }

    # Abort early when nothing is left to import.
    if {![IS/NumProjects]} {
	return {}
    }
    
    #puts \n__________________________________weeded
    #array set _ $state ; parray _

    # Store processing ...
    ##
    # When something is left look at the stores in detail to ensure
    # that sharing is still handled correctly.
    ##
    # - Unused stores are removed.
    # - For still used stores it is checked (in the backup) if a known
    #   repository used them. If yes, then that repository is
    #   remembered as the base.

    dict for {id repos} [dict get $state store] {
	if {![dict size $repos]} {
	    # Not used, eliminate
	    dict unset state store $id
	    continue
	}
	# Still used.
	dict set state store $id [IS/KnownBase $id $storebak]
    }

    #puts \n__________________________________final____
    #array set _ $state ; parray _

    dict unset state lno
    dict unset state lfmt
    
    return $state
}

proc ::m::glue::ImportDo {dated state} {
    debug.m/glue {[debug caller] | }

    # 'project' -> (url -> '.')
    # 'repo'    -> (url -> 'vcs'     -> code
    #                   -> 'store'   -> id)
    # 'store'   -> (id  -> base)

    if {![dict size $state]} {
	m msg [color warning "Nothing to import"]
	return
    }

    set n [dict size [dict get $state project]]
    set x [expr {($n == 1) ? "project" : "projects"}]
    m msg "Importing $n $x ..."

    if {$dated} {
	set date _[lindex [split [m format epoch [clock seconds]]] 0]
    } else {
	set date {}
    }

    foreach name [lsort -dict [dict keys [dict get $state project]]] {
	debug.m/glue { | project $name}
	
	m db transaction {
	    Import1 $name$date $state [dict keys [dict get $state project $name]]
	}
	# signal commit
	m msg [color good OK]
    }
    return
}

proc ::m::glue::Import1 {pname state repos} {
    debug.m/glue {[debug caller] | }
    # repos = list (url)

    set n [llength $repos]
    set x [expr {($n == 1) ? "repository" : "repositories"}]
    m msg "Handling [color note $pname] ($n $x) ..."
    
    if {![m project has $pname]} {
	m msg* "  Setting up the project ... "
	set project [m project add $pname]
	OKx
    } else {
	m msg "  Project is known"
	set project [m project id $pname]
    }

    debug.m/glue {[debug caller] | ($repos) }
    
    foreach url $repos {
	set ri [dict get $state repo $url]
	dict with ri {}
	# -> vcs, store
	set base [dict get $state store $store]

	debug.m/glue { | + $vcs $url ($base)}

	m msg "Repository [color note $url]"
	
	if {$base ne {}} {
	    set base [m repo id $base]
	    m msg "Extending  [color note [m repo url $base]]"
	}

	set vcsid [m vcs id $vcs]

	try {
	    lassign [AddStoreRepo $base $vcsid $vcs $pname $url $project] repo forks

	    # Forks are not processed. It is expected that forks are in the import file.
	    # The next update of the primary will link them to the origin.
	    set nforks [llength $forks]
	    if {$nforks} {
		m msg "  [color warning "Forks found ($nforks), ignored"]"
	    }

	    m rolodex push $repo

	} on error {e o} {
	    puts EEEE\t$e
	    puts EEEE\t[join [split $::errorInfo \n] \nEEEE\t]

	    # undo repo, undo unused stores
	}
    }

    # undo project if empty.
    if {![m project size $project]} {
	m msg "Removing project, nothing imported for it"
	m project remove $project
    }
    
    m rolodex commit
    return
}

proc ::m::glue::Add {config {base {}}} {
    debug.m/glue {[debug caller] | }

    set url   [Url $config]
    set vcs   [$config @vcs]
    set vcode [$config @vcs-code]
    set name  [$config @name]
    set url   [m vcs url-norm $vcode $url]
    # __Attention__: Cannot move the url normalization into a
    # when-set clause of the parameter. That generates a
    # dependency cycle:
    #
    #   url <- vcode <- vcs <- url

    m msg "Attempting to add"
    m msg "  Repository [color note $url]"
    m msg "  Managed by [color note [m vcs name $vcs]]"
    m msg "Into"
    m msg "  Project    [color note $name]"

    if {[m repo has $url]} {
	m::cmdr::error \
	    "Repository already present" \
	    HAVE_ALREADY REPOSITORY
    }

    if {$base ne {}} {
	m msg "Extending"
	m msg "  Repository [color note [m repo url $base]]"
    }
    
    # Relevant entities
    #  1. repository
    #  2. store
    #  3. project
    #
    # As the repository references the other two these have to be initialized first.
    # The creation of the repository caps the process.
    # Issues roll database changes back.

    m msg "Actions ..."

    # ---------------------------------- Project
    if {![m project has $name]} {
	m msg* "  Setting up the project ... "
	set project [m project add $name]
	OKx
    } else {
	m msg "  Project is known"
    }

    lassign [AddStoreRepo $base $vcs $vcode $name $url $project] repo forks

    # ---------------------------------- Forks
    if {$forks ne {}} {
	set threshold 22
	set nforks [llength $forks]
	m msg "Found [color note $nforks] forks to track."
	
	if {![$config @track-forks] && ($nforks > $threshold)} {
	    m msg [color warning "Auto-tracking threshold of $threshold forks exceeded"]
	    m::cmdr::error "Please confirm using [color note --track-forks] that this many forks should be tracked." \
		TRACKING-THRESHOLD
	}

	AddForks $forks $repo $vcs $vcode $name $project
    }

    # ----------------------------------
    m msg "Setting new primary as current repository"
    
    m rolodex push $repo
    m rolodex commit

    return
}

proc ::m::glue::AddForks {forks repo vcs vcode name project} {
    debug.m/glue {[debug caller] | }

    set nforks [llength $forks]
    set format %-[string length $nforks]d
    set pad [string repeat " " [expr {3+[string length $nforks]}]]
    
    foreach fork $forks {
	incr k
	m msg "  [color cyan "([format $format $k])"] Fork [color note $fork] ... "

	if {[m repo has $fork]} {
	    m msg "  $pad[color note "Already known, claiming it"]"
	    
	    # NOTE: The fork exists in a different project. We
	    # leave that part alone.  The ERD allows that, a fork
	    # and its origin do not have to be in the same
	    # project.
	    
	    m repo claim $repo [m repo id $fork]
	    continue
	}
	
	# Note: Fork urls have to be validated, same as the primary location.
	if {![m url ok $fork xr]} {
	    m msg "  [color warning {Not reachable}], might be private or gone"
	    m msg "  Ignored"
	    continue
	}

	AddStoreRepo {} $vcs $vcode $name $fork $project $repo
    }
    return
}

proc ::m::glue::AddStoreRepo {base vcs vcode name url project {origin {}}} {
    debug.m/glue {[debug caller] | }

    # ---------------------------------- Store

    if {$base ne {}} {
	set binfo [m repo get $base]
	set bvcs  [dict get $binfo vcs]

	if {$vcs != $bvcs} {
	    m::cmdr::error \
		"Extension rejected due to VCS mismatch ([m vcs name $vcs] vs [m vcs name $bvcs])" \
		MISMATCH
	}
    }
    
    set ext [expr {($base ne {}) ? "a transient" : "the"}]
    
    m msg* "  Setting up $ext $vcode store ... "
    lassign [m store add $vcs $name $url] \
	store duration commits size forks
    #   id    seconds  int     int  list(url)
    set x [expr {($commits == 1) ? "commit" : "commits"}]
    m msg "[color good OK] in [color note [m format interval $duration]] ($commits $x, $size KB)"

    if {$base ne {}} {
	set bstore [dict get $binfo store]

	if {![m store check $store $bstore]} {
	    m store remove $store
	    m::cmdr::error \
		"Extension rejected by [m vcs name $vcs]" \
		MISMATCH
	}

	# Extension is ok. Drop the created store again, it was only needed to perform the checks.
	m store remove $store

	# And point the new repository to the store of the base.
	set store $bstore

	m msg "  Extension [color good accepted] by [m vcs name $vcs]."
    }
    
    # ---------------------------------- Repository
    
    m msg* "  Creating repository ... "    
    set repo [m repo add $vcs $project $store $url $duration $origin]
    OKx

    return [list $repo $forks]
}

proc ::m::glue::InvalE {label key} {
    set v [m state $key]
    return [list [Inval $label {$v ne {}}] $v]
}

proc ::m::glue::Inval {x isvalid} {
    debug.m/glue {[debug caller] | }
    if {[uplevel 1 [list ::expr $isvalid]]} {
	return $x
    } else {
	return [color bad $x]
    }
}

# TODO: Bool, Date, Size => utility package
proc ::m::glue::Bool {flag} {
    debug.m/glue {[debug caller] | }
    return [expr {$flag ? "[color good on]" : "[color bad off]"}]
}

proc ::m::glue::ShowCurrent {config} {
    debug.m/glue {[debug caller] | }
    package require m::repo
    package require m::rolodex

    m db transaction {
	set rolodex [m rolodex get]
	set n [llength $rolodex]
	if {$n} {
	    set id -1
	    set series {}
	    foreach r $rolodex {
		incr id
		set rinfo [m repo get $r]
		dict with rinfo {}
		# -> url    : repo url
		#    vcs    : vcs id
		# -> vcode  : vcs code
		#    project: project id
		# -> name   : project name
		#    store  : id of backing store for repo

		lappend tag @$id
		if {$id == ($n-2)} { lappend tag @p }
		if {$id == ($n-1)} { lappend tag @c }
		lappend series [list $tag $url $name $vcode]
		unset tag
	    }
	}
    }
    if {$n} {
	lassign [TruncW \
		     {{} {} {} {}} \
		     {0  1  3  0} \
		     $series [$config @tw]] \
	    titles series
	[table t $titles {
	    $t borders 0
	    $t headers 0
	    foreach row $series {
		$t add {*}[C $row 1 note] ;# 1 => url
	    }
	}] show
    }
    return
}

proc ::m::glue::OK {} {
    debug.m/glue {[debug caller] | }
    m msg [color good OK]
    return -code return
}

proc ::m::glue::OKx {} {
    debug.m/glue {[debug caller] | }
    m msg [color good OK]
}

proc ::m::glue::MakeName {prefix} {
    debug.m/glue {[debug caller] | }
    if {![m project has $prefix]} { return $prefix }
    set n 1
    while {[m project has ${prefix}#$n]} { incr n }
    return "${prefix}#$n"
}

proc ::m::glue::ComeAroundMail {width current newcycle} {
    debug.m/glue {[debug caller] | }
    package require m::db
    package require m::state
    package require m::store
    package require m::format

    # Get updates and convert into a series for the table. A series we
    # can compress width-wise before formatting.
    set series {}
    foreach row [m store updates] {
	dict with row {}
	# store mname vcode changed updated created size active remote
	# sizep commits commitp mins maxs lastn
	if {$created eq "."} continue ;# ignore separations
	if {$changed < $current} continue ;# older cycle

	set dcommit [DeltaCommit $commits $commitp]
	set dsize   [DeltaSize $size $sizep]
	set changed [m format epoch/short $changed]
	set spent   [LastTime $lastn]

	lappend series [list $changed $vcode $mname $spent $dsize $dcommit]
    }

    lappend mail "\[[info hostname]\] Cycle Report."
    lappend mail "Cycle\nFrom [clock format $current]\nTo   [clock format $newcycle]"
    set n [llength $series]
    if {!$n} {
	lappend mail "Found no changes."
    } else {
	lappend mail "Found @/n/@ changed repositories:\n"

	lassign [TruncW \
		     {Changed VCS Project Time Size Commits} \
		     {0       0   1       0    0    0} \
		     $series \
		     $width] \
	    titles series

	table t $titles {
	    foreach row $series {
		$t add {*}$row
	    }
	}
	lappend mail [$t show return]
	$t destroy
    }

    MailFooter mail
    return [string map [list @/n/@ $n] [join $mail \n]]
}

proc ::m::glue::ComeAround {newcycle} {
    debug.m/glue {[debug caller] | }
    # Called when the update cycle comes around back to the start.
    # Creates a mail reporting on all the projects which where
    # changed in the previous cycle.

    set current [m state start-of-current-cycle]
    m state start-of-previous-cycle $current
    m state start-of-current-cycle  $newcycle

    m msg "Cycle complete, coming around and starting new ..."

    set email [m state report-mail-destination]

    if {$email eq {}} {
	debug.m/glue {[debug caller] | Skipping report without destination}
	# Nobody to report to, skipping report
	m msg "- [color warning {Skipping mail report, no destination}]"
	return
    }

    package require m::mail::generator
    package require m::mailer
    m msg "- [color good "Mailing report to"] [color note $email]"

    set comearound [ComeAroundMail [m state mail-width] $current $newcycle]
    m mailer to $email [m mail generator reply $comearound {}]

    m msg [color good OK]
    return
}

proc ::m::glue::UpdateRepos {start now repos} {
    debug.m/glue {[debug caller] | }

    set n [llength $repos]
    if {$n} {
	# The note below is not shown when the user explicitly
	# specifies the repositories to process. Because that is
	# outside any cycle.
	return $repos
    }

    set take     [m state take]
    set nrepo    [m repo count]
    set npending [m repo count-pending]

    m msg "In cycle started on [m format epoch $start]: $take/$npending/$nrepo"

    # No repositories specified.
    # Pull repositories directly from pending
    return [m repo take-pending $take \
		::m::glue::ComeAround $now]
}

proc ::m::glue::Dedup {values} {
    debug.m/glue {[debug caller] | }
    # While keeping the order
    set res {}
    set have {}
    foreach v $values {
	if {[dict exist $have $v]} continue
	lappend res $v
	dict set have $v .
    }
    return $res
}

proc ::m::glue::MergeFill {repos} {
    debug.m/glue {[debug caller] | }
    set n [llength $repos]

    if {!$n} {
	# No repositories. Use the current and previous repositories
	# as merge target and source

	set target [m rolodex top]
	if {$target eq {}} {
	    m::cmdr::error \
		"No current repository as merge target" \
		MISSING CURRENT
	}
	set origin [m rolodex next]
	if {$origin eq {}} {
	    m::cmdr::error \
		"No previously current repository as merge source" \
		MISSING PREVIOUS
	}
	lappend repos $target $origin
	return $repos
    }
    if {$n == 1} {
	# A single repository is the merge origin. Use the current
	# repository as merge target.
	set target [m rolodex top]
	if {$target eq {}} {
	    m::cmdr::error \
		"No current repository as merge target" \
		MISSING CURRENT
	}
	return [linsert $repos 0 $target]
    }
    return $repos
}

proc ::m::glue::Rename {merge project newname} {
    debug.m/glue {[debug caller] | }
    
    if {$merge} {
	# Bulk move the repositories to the existing destination
	m repo move/project $project [m project id $newname]
	m project remove    $project
	
    } else {
	# Just change the source to the new name.
	m project rename $project $newname
    }

    return
}

proc ::m::glue::Merge {target origin} {
    debug.m/glue {[debug caller] | }
    # Target and origin are repositories

    # Check that the repositories have compatible stores
    #  - Same VCS
    #  - VCS allows merging

    set oinfo [m repo get $origin]
    set tinfo [m repo get $target]
    
    set ovcs [dict get $oinfo vcs]
    set tvcs [dict get $tinfo vcs]

    if {$ovcs != $tvcs} {
	m::cmdr::error \
	    "Merge rejected due to VCS mismatch ([m vcs name $ovcs] vs [m vcs name $tvcs])" \
	    MISMATCH
    }

    set ostore [dict get $oinfo store]
    set tstore [dict get $tinfo store]
    
    if {![m store check $tstore $ostore]} {
	m::cmdr::error \
	    "Merge rejected by [m vcs name $ovcs]" \
	    MISMATCH
    }

    m store merge  $tstore $ostore
    m repo store!  $origin $tstore
    
    return
}

proc ::m::glue::MailConfigShow {t {prefix {}}} {
    debug.m/glue {[debug caller] | }

    set u [m state mail-user]
    set s [m state mail-sender]

    $t add ${prefix}Host   [m state mail-host]
    $t add ${prefix}Port   [m state mail-port]
    $t add ${prefix}User   [Inval $u {$u ne "undefined"}]
    $t add ${prefix}Pass   [m state mail-pass]
    $t add ${prefix}TLS    [m state mail-tls]
    $t add ${prefix}Sender [Inval $s {$s ne "undefined"}]
    $t add ${prefix}Header [m state mail-header]
    $t add ${prefix}Footer [m state mail-footer]
    $t add ${prefix}Width  [m state mail-width]
    $t add ${prefix}Debug  [m state mail-debug]
    return
}

proc ::m::glue::ReplyConfigShow {} {
    debug.m/glue {[debug caller] | }

    [table t {{} Name Mail Text} {
	foreach {name default mail text} [m reply all] {
	    set mail    [expr {$mail    ? "*" : ""}]
	    set default [expr {$default ? "#" : ""}]

	    $t add $default [color note $name] $mail $text
	}
    }] show
    return
}

proc ::m::glue::SiteRegen {} {
    debug.m/glue {[debug caller] | }
    package require m::state
    if {![m state site-active]} return
    package require m::web::site
    m web site build silent
    return
}

proc ::m::glue::SiteConfigShow {t {prefix {}}} {
    debug.m/glue {[debug caller] | }

    $t add ${prefix}State [Bool [m state site-active]]
    #
    $t add {*}[InvalE "${prefix}Location" site-store]
    $t add {*}[InvalE ${prefix}Url        site-url]
    $t add ${prefix}Logo       [m state   site-logo]
    $t add {*}[InvalE ${prefix}Title      site-title]
    #
    $t add ${prefix}Manager  {}
    $t add {*}[InvalE "${prefix}- Name"   site-mgr-name]
    $t add {*}[InvalE "${prefix}- Mail"   site-mgr-mail]
    #
    $t add ${prefix}Related  {}
    $t add "${prefix}- Url"    [m state site-related-url]
    $t add "${prefix}- Label"  [m state site-related-label]
    return
}

proc ::m::glue::SiteEnable {flag} {
    debug.m/glue {[debug caller] | }
    if {[m state site-active] != $flag} {
	if {$flag} SiteConfigValidate
	m state site-active $flag
	set flag [expr {$flag ? "Activated" : "Disabled"}]
    } else {
	set flag [expr {$flag ? "Still active" : "Still disabled"}]
    }
    m msg "$flag web site generation"
    return
}

proc ::m::glue::SiteConfigValidate {} {
    debug.m/glue {[debug caller] | }
    set m {}
    set ok 1

    # site-logo :: Optional.

    foreach {k label} {
	site-store    {No location for generation result}
	site-mgr-name {No manager specified}
	site-mgr-mail {No manager mail specified}
	site-title    {No title specified}
	site-url      {No publication url specified}
    } {
	if {[m state $k] ne ""} continue
	lappend m "- $label"
	set ok 0
    }
    if {$ok} return
    m msg [join $m \n]
    m::cmdr::error "Unable to activate site generation" \
	SITE CONFIG INCOMPLETE
}

proc ::m::glue::Ping+ {text} {
    debug.m/glue {[debug caller] | }
    # Extend current line with more text, stay on the line, except
    # when text does not.
    puts -nonewline stdout $text
    flush           stdout
    return
}

proc ::m::glue::Ping {text} {
    debug.m/glue {[debug caller] | }
    # Move to start of line, erase all, write new text, stay on the
    # line, except when text does not.
    puts -nonewline stdout \r\033\[0K$text
    flush           stdout
    return
}

proc ::m::glue::Close {} { puts "" }

proc ::m::glue::C {row index color} {
    return [lreplace $row $index $index [color $color [lindex $row $index]]]
}

proc ::m::glue::W {wv} {
    upvar 1 $wv wc
    set cols [lsort -integer [array names wc]]
    set ww {}
    foreach c $cols { lappend ww $wc($c) }
    return $ww
}

proc ::m::glue::TruncH {series height} {
    debug.m/glue {[debug caller] | }
    incr height -4 ; # table overhead (header and borders)
    incr height -3 ; # lines before and after table (prompt with command + OK)
    if {[llength $series] > $height} {
	set     series [lrange $series 0 ${height}-2]
	lappend series [lrepeat [llength [lindex $series 0]] ...]
    }
    return $series
}

##
## TODO column specific minimum widths
## TODO column specific shaving (currently all on the right, urls: left better, or middle)
## TODO column specific shave commands (ex: size rounding)
## TODO
## TODO
##

proc ::m::glue::TruncW {titles weights series width} {
    # series  :: list (row)
    # row     :: list (0..n-1 str)
    # weights :: list (0..k-1 int)
    # titles  :: list (0..n-1 str) - Hard min (for now: include in full width)
    # width   :: int 'terminal width'
    #
    # n < k => Ignore superfluous weights.
    # n > k => Pad to the right with weight 0.
    #
    # weight -1: Do not touch at all. (Colorized?!)

    set n [llength [lindex $series 0]]
    set k [llength $weights]

    debug.m/glue { terminal     : $width }
    debug.m/glue { len(series)  : [llength $series] }
    debug.m/glue { len(row)     : $n }
    debug.m/glue { len(weights) : $k ($weights)}

    if {$n < $k} {
	set d [expr {$k - $n}]
	set weights [lreplace $weights end-$d end]
	# TODO: Check arith (off by x ?)
    }
    if {$n > $k} {
	set d [expr {$n - $k}]
	lappend weights {*}[lrepeat $d 0]
    }

    # Remove table border overhead to get usable terminal space
    set width [expr {$width - (3*$n+1)}]

    debug.m/glue { terminal'    : $width (-[expr {3*$n+1}]) }
    debug.m/glue { weights'     : ($weights)}

    # Compute series column widths (max len) for all columns.  If the
    # total width is larger than width we have to shrink by weight.
    # Note: Min column width after shrinking is 6 (because we want to
    # show something for each column).  If shrink by weight goes below
    # this min width bump up to it and remove the needed characters
    # from the weight 0 columns, but not below min width.
    set min 6

    while {$k} { incr k -1 ; set wc($k) 0 }

    foreach row [linsert $series 0 $titles] {
	set col 0
	foreach el $row {
	    set n [string length $el]
	    if {$n > $wc($col)} { set wc($col) $n }
	    incr col
	}
    }

    debug.m/glue { col.widths  = [W wc] }

    # max width over all rows.

    set fw 0
    foreach {_ v} [array get wc] { incr fw $v }

    debug.m/glue { full        = $fw vs terminal $width }

    # Nothing to do if the table fits already
    if {$fw <= $width} { return [list $titles $series] }

    # No fit, start shrinking.

    # Sum of weights to apportion
    set tw 0
    foreach w $weights { if {$w <= 0} continue ; incr tw $w }

    # Number of characters over the allowed width.
    set over [expr {$fw - $width}]
    debug.m/glue { over         : $over }

    # Shrink columns per weight
    set col 0 ; set removed 0
    foreach w $weights {
	set c $col ; incr col
	if {$w <= 0} {
	    debug.m/glue { ($col): skip }
	    continue
	}
	set drop [format %.0f [expr {double($over * $w)/$tw}]]

	debug.m/glue { ($col): drop $drop int(($over*$w)/$tw)) }
	
	incr removed $drop
	incr wc($c) -$drop
    }
    # --assert: removed >= over
    debug.m/glue { removed      : $removed }
    # Rounding may cause removed < over, leaving too many characters behind.
    # Run a constant shaver, on the weighted cols
    set over [expr {$over - $removed}]
    if {$over} { ShaveWeighted wc $weights $over }

    debug.m/glue { col.widths  = [W wc] }

    # If a weighted column has become to small, i.e. less than the
    # allowed min, in the above we bump it back to that width and will
    # shave these then from other columns.
    set col 0
    set under 0
    foreach w $weights {
	set c $col ; incr col
	if {($w <= 0) || ($wc($c) >= $min)} continue
	incr under [expr {$min - $wc($c)}]
	set wc($c) $min
    }

    debug.m/glue { under        : $under }
    debug.m/glue { col.widths  = [W wc] }

    # Claw back the added characters from other columns now, as much
    # as we can.  We try to shrink other weighted columns first before
    # goign for the unweighted, i.e. strongly fixed ones.
    if {$under} { set under [ShaveWeighted   wc $weights $under] }
    if {$under} { set under [ShaveUnweighted wc $weights $under] }

    debug.m/glue { col.widths  = [W wc] }

    # At last, truncate the series elements to the chosen column
    # widths. Same for the titles.
    set new {}
    foreach row $series {
	set col 0
	set newrow {}
	foreach el $row {
	    if {[string length $el] > $wc($col)} {
		set el [string range $el 0 $wc($col)-1]
	    }
	    lappend newrow $el
	    incr col
	}
	lappend new $newrow
    }

    set col 0
    set newtitles {}
    foreach el $titles {
	if {[string length $el] > $wc($col)} {
	    set el [string range $el 0 $wc($col)-1]
	}
	lappend newtitles $el
	incr col
    }

    return [list $newtitles $new]
}

proc ::m::glue::ShaveWeighted {wv weights shave} {
    set min 6 ;# todo place in common
    upvar 1 $wv wc
    set changed 1
    while {$changed} {
	set changed 0
	set col 0
	foreach w $weights {
	    set c $col ; incr col
	    if {$w <= 0} continue
	    if {$wc($c) <= $min} continue
	    incr wc($c) -1
	    incr shave -1
	    set changed 1
	    if {!$shave} { return 0 }
	}
    }
    return $shave
}

proc ::m::glue::ShaveUnweighted {wv weights shave} {
    set min 6 ;# todo place in common
    upvar 1 $wv wc
    set changed 1
    while {$changed} {
	set changed 0
	set col 0
	foreach w $weights {
	    set c $col ; incr col
	    if {$w != 0} continue
	    if {$wc($c) <= $min} continue
	    incr wc($c) -1
	    incr shave -1
	    set changed 1
	    if {!$shave} { return 0 }
	}
    }
    return $shave
}

# # ## ### ##### ######## ############# ######################
## Delta formatting, various kinds (size, commits, time spent)
## With and without previous. Always current and delta.

proc ::m::glue::LastTime {lastn} {
    return [m format interval [lindex [split [string trim $lastn ,] ,] end]]
}

proc ::m::glue::StatsTime {mins maxs lastn} {
    set mins [expr {$mins < 0 ? "+Inf" : [m format interval $mins]}]
    set maxs [m format interval $maxs]

    # See also ::m::repo::times, ::m::web::site::Store
    
    append text "$mins ... $maxs"

    set lastn [m format win $lastn]
    set n [llength $lastn]
    if {!$n} { return $text }

    set lastn [m format win-trim $lastn [m state store-window-size]]
    set n       [llength $lastn]
    set total   [expr [join $lastn +]]
    set avg     [m format interval [format %.0f [expr {double($total)/$n}]]]

    append text " \[avg (last $n) $avg ([join $lastn ,]))]"
    return $text
}

proc ::m::glue::DeltaSizeFull {current previous} {
    append text [m format size $current]
    if {$previous != $current} {
	if {$current < $previous} {
	    # shrink
	    set color bad
	    set delta -[m format size [expr {$previous - $current}]]
	} else {
	    # grow
	    set color note
	    set delta +[m format size [expr {$current - $previous}]]
	}
	set dprev [m format size $previous]
	append text " (" [color $color "$dprev ($delta)"] ")"
    }

    return $text
}

proc ::m::glue::DeltaSize {current previous} {
    append text [m format size $current]
    if {$previous != $current} {
	if {$current < $previous} {
	    # shrink
	    set color bad
	    set delta -[m format size [expr {$previous - $current}]]
	} else {
	    # grow
	    set color note
	    set delta +[m format size [expr {$current - $previous}]]
	}
	append text " (" [color $color "$delta"] ")"
    }

    return $text
}

proc ::m::glue::DeltaCommitFull {current previous} {
    if {$previous == $current} { return $current }

    set delta [expr {$current - $previous}]
    if {$delta < 0} {
	set color bad
    } else {
	# delta > 0
	set color note
	set delta +$delta
    }

    append text $current " (" [color $color "$previous ($delta)"] ")"
    return $text
}

proc ::m::glue::DeltaCommit {current previous} {
    if {$previous == $current} { return $current }

    set delta [expr {$current - $previous}]
    if {$delta < 0} {
	set color bad
    } else {
	# delta > 0
	set color note
	set delta +$delta
    }

    append text $current " (" [color $color "$delta"] ")"
    return $text
}

proc ::m::glue::Box {text} {
    return [[table t {n/a} {
	$t headers 0
	$t add $text
    }] show return]    
}

# # ## ### ##### ######## ############# ######################
## Nicer table styles using the box drawing characters
#
## ATTENTION: This globally __overwrites__ the styles defined inside
## of the cmdr::table package.

# Borders and header row.
::report::rmstyle  cmdr/table/borders
::report::defstyle cmdr/table/borders {} {

    data	set [lrepeat [expr {[columns]+1}] \u2502]
    top         set [list \u250c {*}[concat {*}[lrepeat [expr {[columns]-1}] {\u2500 \u252c}]] \u2500 \u2510]
    bottom      set [list \u2514 {*}[concat {*}[lrepeat [expr {[columns]-1}] {\u2500 \u2534}]] \u2500 \u2518]
    topdata	set [data get]
    topcapsep	set [list \u251c {*}[concat {*}[lrepeat [expr {[columns]-1}] {\u2500 \u253c}]] \u2500 \u2524]

    top		enable
    bottom	enable
    topcapsep	enable
    tcaption	1
    for {set i 0 ; set n [columns]} {$i < $n} {incr i} {
	pad $i both { }
    }
    return
}

# Borders, no header row.
::report::rmstyle  cmdr/table/borders/nohdr
::report::defstyle cmdr/table/borders/nohdr {} {
    data	set [lrepeat [expr {[columns]+1}] \u2502]
    top         set [list \u250c {*}[concat {*}[lrepeat [expr {[columns]-1}] {\u2500 \u252c}]] \u2500 \u2510]
    bottom      set [list \u2514 {*}[concat {*}[lrepeat [expr {[columns]-1}] {\u2500 \u2534}]] \u2500 \u2518]
    top		enable
    bottom	enable
    for {set i 0 ; set n [columns]} {$i < $n} {incr i} {
	pad $i both { }
    }
    return
}

# # ## ### ##### ######## ############# ######################
return
