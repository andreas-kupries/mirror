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
	Add $config
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
	set repo [$config @repository]

        set rinfo [m repo get $repo]
        dict with rinfo {}
        # -> url    : repo url
        #    vcs    : vcs id
        # -> vcode  : vcs code
        # -> project: project id
        # -> name   : project name
        # -> store  : id of backing store for repo

	m msg "Removing $vcode repository [color note $url] ..."
	m msg "from Project [color note $name]"
	
	m repo remove $repo

	set siblings [m store remotes $store]
	set nsiblings [llength $siblings]
	if {!$nsiblings} {
	    m msg "- Removing unshared $vcode store $store ..."
	    m store remove $store
	} else {
	    set x [expr {($nsiblings == 1) ? "repository" : "repositories"}]
	    m msg "- Keeping $vcode store $store still used by $nsiblings $x"
	}

	# Remove project if no repositories remain at all.
	set nsiblings [m project size $project]
	
	if {!$nsiblings} {
	    m msg "- Removing now empty project ..."
	    m project remove $project
	} else {
	    set x [expr {($nsiblings == 1) ? "repository" : "repositories"}]
	    m msg "- Keeping project still used by $nsiblings $x"
	}

	m rolodex drop $repo
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
	    set sibs 0
	    foreach sibling $storesibs {
		if {$sibling == $repo} continue
		incr sibs
		$s add ${sibs}. [Short $sibling]
	    }
	    if {$sibs} { $s add {} {} }
	    $s add Size $dsize
	    $s add Commits       $dcommit
	    if {$export ne {}} {
		$s add Export $export
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
	    # Forks are shown separately.
	    set sibs 0
	    foreach sibling $projectsibs {
		if {$sibling == $repo} continue
		if {$sibling == $origin} continue
		if {$sibling in $storesibs} continue
		if {$sibling in $forksibs} continue
		if {!$sibs} { $t add Other {} }
		incr sibs
		$t add ${sibs}. [Short $sibling]		
	    }

	    set threshold 20
	    # Show the sibling forks. Only the first, only if not sharing the store.
	    set sibs 0
	    foreach sibling $forksibs {
		if {$sibling == $repo} continue
		if {$sibling == $origin} continue
		if {$sibling in $storesibs} continue
		if {!$sibs} { $t add Related {} }
		incr sibs

		# 
		if {$sibs > $threshold} continue
		$t add ${sibs}. [Short $sibling]
	    }
	    if {$sibs > $threshold} {
		$t add {} "(+[expr {$sibs - $threshold}] more)"
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
	    m msg "$op [color note [m repo name $repo]] ..."

	    set rinfo [m repo get $repo]
	    dict with rinfo {}
	    # -> url	: repo url
	    #    vcs	: vcs id
	    #    vcode	: vcs code
	    #    project: project id
	    #    name	: project name
	    #    store  : id of backing store for repo

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
	m msg "Target:  [color note [m repo name $primary]]"

	foreach secondary $secondaries {
	    m msg "Merging: [color note [m repo name $secondary]]"
	    MergeR $primary $secondary
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
	# series = list (dict (name #repos $stores))
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
    # command :: list ('M' name)	- old: 'M'irrorset
    #          | list ('P' name)	- new: 'P'roject
    #          | list ('R' vcode url)
}

proc ::m::glue::ImportVerify {commands} {
    debug.m/glue {}
    # commands :: list (command)
    # command  :: list ('M' name)	- old: 'M'irrorset
    #           | list ('P' name)	- new: 'P'roject
    #           | list ('R' vcode url)

    m msg "Verifying ..."

    foreach {code name} [m vcs all] {
	dict set vcs $code .
	dict set vcs $name .
    }

    set lno 0
    set maxl [llength $commands]
    set lfmt %-[string length $maxl]s
    set msg {}
    set new {}
    foreach command $commands {
	incr lno
	debug.m/glue {[format $lfmt $lno]: '$command'}

	# strip (trailing) comments, leading & trailing whitespace
	regsub -- "#.*\$" $command {} command
	set command [string trim $command]

	# skip empty lines
	if {$command eq {}} continue

	lassign $command cmd a b
	switch -exact -- $cmd {
	    M -
	    P {
		Ping "  $command"
		# M name --> a = name, b = ((empty string))
		if {[llength $command] != 2} {
		    lappend msg "Line [format $lfmt $lno]: Bad syntax: $command"
		}
	    }
	    R {
		Ping "  [list R $b]"
		# R kind url --> a = kind, b = url
		if {[llength $command] != 3} {
		    lappend msg "Line [format $lfmt $lno]: Bad syntax: $command"
		} else {
		    if {![dict exists $vcs $a]} {
			lappend msg "Line [format $lfmt $lno]: Unknown vcs: $command"
		    }

		    Ping+ " ..."
		    if {![m url ok $b resolved]} {
			lappend msg "Line [format $lfmt $lno]: Bad url: $b"
		    } else {
			#Ping+ \n
			Ping "  = $resolved"
			# Add resolution to R commands.
			lappend command $resolved
		    }
		}
	    }
	    default {
		Ping "  $command"
		lappend msg "Line [format $lfmt $lno]: Unknown command: $command"
	    }
	}
	lappend new $command
	#Ping+ \n
    }

    # Start a last ping to erase the animation remnants.
    Ping ""

    if {[llength $msg]} {
	m::cmdr::error \n\t[join $msg \n\t] IMPORT BAD
    }

    # Unchanged.
    return $new
}

proc ::m::glue::ImportSkipKnown {commands} {
    # commands :: list (command)
    # command  :: list ('M' name)
    #           | list ('R' vcode url resolved)
    debug.m/glue {}
    m msg "Weeding ..."

    set seen {}
    set lno 0
    set new {}
    set repo {}
    foreach command $commands {
	debug.m/glue {$command}

	incr lno
	lassign $command cmd vcs url resolved
	switch -exact -- $cmd {
	    R {
		if {$url ne $resolved} {
		    m msg "Line $lno: [color warning Redirected] to [color note $resolved]"
		    m msg "Line $lno: From          [color note $url]"
		}

		set check [m vcs url-norm $vcs $resolved]
		debug.m/glue {checking $check}

		if {[m repo has $check]} {
		    m msg "Line $lno: [color warning Skip] known repository [color note $url]"
		    continue
		}
		if {$resolved in $repo} {
		    m msg "Line $lno: [color warning Skip] [color bad duplicate] [color note $url]"
		    continue
		}
		if {[dict exists $seen $resolved]} {
		    lassign [dict get $seen $resolved] olno m
		    m msg "Line $lno: [color warning Skip] [color bad duplicate] [color note $url]"
		    m msg "Line $lno: Belongs to    [color note $m] (Line $olno)"
		    continue
		}

		dict set seen $resolved $lno
		lappend x $resolved
	        lappend repo $vcs $resolved
	    }
	    M {
		if {![llength $repo]} {
		    m msg "Line $lno: [color warning Skip] empty project [color note $vcs]"
		    set repo {}
		    continue
		}
		foreach r $x { dict lappend seen $r $vcs } ;# vcs = mname
		unset x

		lappend command $repo
		lappend new $command
		set repo {}
	    }
	}
    }

    # new   :: list (mset)
    # mset  :: list ('M' name repos)
    # repos :: list (vcode1 url1 v2 u2 ...)
    return $new
}

proc ::m::glue::ImportDo {dated commands} {
    # commands :: list (mset)
    # mset     :: list ('M' name repos)
    # repos    :: list (vcode1 url1 v2 u2 ...)
    debug.m/glue {}

    if {![llength $commands]} {
	m msg [color warning "Nothing to import"]
    } else {
	m msg "Importing [llength $commands] (finally) ..."
    }

    if {$dated} {
	set date _[lindex [split [m format epoch [clock seconds]]] 0]
    } else {
	set date {}
    }

    foreach command $commands {
	lassign $command _ msetname repos
	m db transaction {
	    Import1 $date $msetname$date $repos
	}
	# signal commit
	m msg [color good OK]
    }
    return
}

proc ::m::glue::Import1 {date mname repos} {
    debug.m/glue {[debug caller] | }
    # repos = list (vcode url ...)

    m msg "Handling project [color note $mname] ..."

    if {[llength $repos] == 2} {
	lassign $repos vcode url
	# The project contains only a single repository.
	# We might be able to skip the merge
	if {![m project has $mname]} {
	    # No project of the given name exists.
	    # Create directly in final form. Skip merge.
	    try {
		ImportMake1 $vcode $url $mname
	    } trap {M VCS CHILD} {e o} {
		# Revert creation of mset and repository
		set repo [m rolodex top]
		set mset [m repo project $repo]
		m repo remove  $repo
		m rolodex drop $repo
		m project remove  $mset

		m msg "[color bad {Unable to import}] [color note $mname]: $e"
		# No rethrow, the error in the child is not an error
		# for the whole command. Continue importing the remainder.
	    }
	    return
	}
    }

    # More than a single repository in this set, or the destination
    # project exists. Merging is needed. And the untrusted nature
    # of the input means that we cannot be sure that merging is even
    # allowed.

    # Two phases:
    # - Create the repositories. Each in its own project, like for
    #   `add`.  Project names are of the form `import_<date>`, plus a
    #   serial number.  Comes with associated store.
    #
    # - Go over the repositories again and merge them.  If a
    #   repository is rejected by the merge keep it separate. Retry
    #   merging using the rejections. The number of retries is finite
    #   because each round finalizes at least one project and its
    #   repositories of the finite supply. At the end of this phase we
    #   have one or more projects each with maximally merged
    #   repositories. Each finalized project is renamed to final form,
    #   based on the incoming mname and date.

    set serial 0
    set r {}
    foreach {vcode url} $repos {
	try {
	    set tmpname import${date}_[incr serial]
	    set data    [ImportMake1 $vcode $url $tmpname]
	    dict set r $url $data
	} trap {M VCS CHILD} {e o} {
	    # Revert creation of mset and repository
	    set repo [m rolodex top]
	    set mset [m repo project $repo]
	    m repo remove  $repo
	    m rolodex drop $repo
	    m project remove  $mset

	    m msg "[color bad {Unable to use}] [color note $url]: $e\n"
	    # No rethrow, the error in the child is not an error
	    # for the whole command. Continue importing the remainder.
	}
    }

    if {![dict size $r]} {
	# All inputs fail, report and continue with the remainder
	m msg "[color bad {Unable to import}] [color note $mname]: No repositories"
	return
    }

    set rename 1
    if {[m project has $mname]} {
	# Targeted project exists. Make it first in the merge list.
	set mset [m project id $mname]
	set repos [linsert $repos 0 dummy_vcode @$mname]
	dict set r @$mname [list dummy_vcs $mset dummy_store]
	set rename 0
    }

    while on {
	set remainder [lassign $repos v u]
	lassign [dict get $r $u] vcsp msetp storep
	m msg "Merge to $u ..."

	set unmatched {}
	foreach {vcode url} $remainder {
	    lassign [dict get $r $url] vcs mset store
	    try {
		m msg "Merging  $url"
		Merge $msetp $mset
	    } trap {M::CMDR MISMATCH} {} {
		m msg "  Rejected"
		lappend unmatched $vcode $url
	    } on error {e o} {
		puts [color bad ////////////////////////////////////////]
		puts [color bad $e]
		puts [color bad $o]
		puts [color bad ////////////////////////////////////////]
	    }
	}

	if {$rename} {
	    # Rename primary mset to final form.
	    Rename $msetp [MakeName $mname]
	    set rename 0
	}

	if {![llength $unmatched]} break

	# Retry to merge the leftovers.  Note, each iteration
	# finalizes at least one project, ensuring termination of the
	# loop.
	set repos $unmatched
	set rename 1
    }

    m rolodex commit
    return
}

proc ::m::glue::ImportMake1 {vcode url base} {
    debug.m/glue {[debug caller] | }
    set vcs     [m vcs id $vcode]
    set tmpname [MakeName $base]
    set project [m project add $tmpname]
    set url     [m vcs url-norm $vcode $url]
    set vcode   [m vcs code $vcs]

    m msg "> [string totitle $vcode] repository [color note $url]"
    
    # -----------------------
    # vcs project url

    lassign [AddStoreRepo $vcs $vcode $tmpname $url $project] repo forks
    set store [m repo store $repo]

    # Forks are not processed. It is expected that forks are in the import file.
    # The next update of the primary will link them to the origin.
    set nforks [llength $forks]
    if {$nforks} {
	m msg "  [color warning "Forks found ($nforks), ignored"]"
    }
    
    m rolodex push $repo

    return [list $vcs $project $store]
}

proc ::m::glue::Add {config} {
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
    m msg "New"
    m msg "  Project    [color note $name]"

    if {[m repo has $url]} {
	m::cmdr::error \
	    "Repository already present" \
	    HAVE_ALREADY REPOSITORY
    }
    if 0 {if {[m project has $name]} {
	m::cmdr::error \
	    "Name already present" \
	    HAVE_ALREADY NAME
    }}

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

    lassign [AddStoreRepo $vcs $vcode $name $url $project] repo forks

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

	AddStoreRepo $vcs $vcode $name $fork $project $repo
    }
    return
}

proc ::m::glue::AddStoreRepo {vcs vcode name url project {origin {}}} {
    debug.m/glue {[debug caller] | }

    # ---------------------------------- Store
    m msg* "  Setting up the $vcode store ... "
    lassign [m store add $vcs $name $url] \
	store duration commits size forks
    #   id    seconds  int     int  list(url)
    set x [expr {($commits == 1) ? "commit" : "commits"}]
    m msg "[color good OK] in [color note [m format interval $duration]] ($commits $x, $size KB)"
    
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

    # Update all stores under the project to the new name.
    foreach store [m project stores $project] {
	m store rename $store $newname
    }
    
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


proc ::m::glue::MergeR {target origin} {
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

proc ::m::glue::Merge {target origin} { error XXX	;#	XXX REWORK import! to fix
    debug.m/glue {[debug caller] | }

    # Target and origin are projects
    #
    # - Check that all the origin's repositories fit into the target.
    #   This is done by checking the backing stores of the vcs in use
    #   for compatibility.
    #
    # - When they do the stores are moved or merged, depending on
    # - presence of the associated vcs in the target.

    set vcss [m project used-vcs $origin]

    # Check that all the origin's repositories fit into the target.
    foreach vcs $vcss {
	# Ignore vcs which are not yet used by the target
	# Assumed to be compatible.
	if {![m store has $vcs $target]} continue

	# Get the two stores, and check for compatibility
	set tstore [m store id $vcs $target]
	set ostore [m store id $vcs $origin]
	if {[m store check $tstore $ostore]} continue

	m::cmdr::error \
	    "Merge rejected due to [m vcs name $vcs] mismatch" \
	    MISMATCH
    }

    # Move or merge the stores, depending presence in the target.
    foreach vcs $vcss {
	set ostore [m store id $vcs $origin]
	if {![m store has $vcs $target]} {
	    m store move $ostore $target
	} else {
	    m store merge [m store id $vcs $target] $ostore
	}
    }

    # Move the repositories, drop the origin set, empty after the move
    m repo move/project $origin $target
    m project remove $origin
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

# # ## ### ##### ######## ############# ######################
return
