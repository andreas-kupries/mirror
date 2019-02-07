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
    package require m::mset
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

proc ::m::glue::gen_current_mset {p} {
    debug.m/glue {[debug caller] | }
    # Provide current as mirror set for operation when not specified
    # by the user. Fail if we have no current repository to trace
    # from.
    package require m::repo
    package require m::rolodex
    #
    set r [m rolodex top]
    if {$r ne {}} {
	set m [m repo mset $r]
	if {$m ne {}} {
	    debug.m/glue {[debug caller] | --> $m }
	    return $m
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
    package require m::mset
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
    package require m::mset
    package require m::repo

    m msg [m mset spec]
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
    package require m::state

    set all [$config @all]

    m db transaction {
	[table/d t {
	    $t add Store         [m state store]
	    $t add Limit         [m state limit]
	    $t add Take          [m state take]
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

    set g [expr {$n == 1 ? "mirror set" : "mirror sets"}]
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

    m msg [color note {Supported VCS}]

    m db transaction {
	[table t {Code Name Version} {
	    foreach {code name} [m vcs all] {
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
		$t add $code $name [join $vmsg \n]
	    }
	}] show
    }
    OK
}

proc ::m::glue::cmd_add {config} {
    debug.m/glue {[debug caller] | }
    package require m::mset
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
    package require m::mset
    package require m::repo
    package require m::rolodex
    package require m::store

    m db transaction {
	set repo [$config @repository]
	m msg "Removing [color note [m repo name $repo]] ..."

	set rinfo [m repo get $repo]
	dict with rinfo {}
	# -> url	: repo url
	#    vcs	: vcs id
	#    vcode	: vcs code
	#    mset	: mirror set id
	#    name	: mirror set name
	#    store      : store id, of backing store for the repo

	m repo remove $repo

	# TODO MAYBE: stuff how much of the cascading remove logic
	# TODO MAYBE: into `repo remove` ?

	# Remove store for the repo's vcs if no repositories for that
	# vcs remain in the mirror set.
	if {![m mset has-vcs $mset $vcs]} {
	    m msg "- Removing $vcode store ..."
	    m store remove $store
	}

	# Remove mirror set if no repositories remain at all.
	if {![m mset size $mset]} {
	    m msg "- Removing mirror set [color note $name] ..."
	    m mset remove $mset
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

proc ::m::glue::cmd_details {config} {
    debug.m/glue {[debug caller] | }
    package require m::mset
    package require m::repo
    package require m::rolodex
    package require m::state
    package require m::store
    package require linenoise

    set w [$config @tw] ;#linenoise columns
    # table/d -> 2 columns, 7 overhead, 1st col 14 wide =>
    set w [expr {$w - 21}] ;# max width for col 2.
    
    m db transaction {
	set full [$config @full]
	set repo [$config @repository]
	m msg "Details of [color note [m repo name $repo]] ..."

	set rinfo [m repo get $repo]
	dict with rinfo {}
	# -> url	: repo url
	#    vcs	: vcs id
	#    vcode	: vcs code
	# *  mset	: mirror set id
	# *  name	: mirror set name
	# *  store      : store id, of backing store for the repo

	# Get pieces ...
	
	lassign [m store remotes $store] remotes plugin
	lappend r Remotes $remotes
	if {[llength $plugin]} {
	    lappend r {*}$plugin
	}

	set path [m store path $store]
	set sd   [m store get $store]
	dict with sd {}
	# -> size, sizep
	#    commits, commitp
	#    vcs
	#    vcsname
	#    created
	#    changed
	#    updated
	#    min_sec, max_sec, win_sec

	set spent [StatsTime $min_sec $max_sec $win_sec]
	
	lassign [m vcs caps $store] stdout stderr
	set stdout [string trim $stdout]
	set stderr [string trim $stderr]

	set status  [SI $stderr]
	set export  [m vcs export $vcs $store]
	set dcommit [DeltaCommitFull $commits $commitp]
	set dsize   [DeltaSizeFull $size $sizep]
	set changed [color note [m format epoch $changed]]
	set updated [m format epoch $updated]
	set created [m format epoch $created]
	
	[table/d t {
	    $t add Status        $status
	    $t add {Mirror Set}  $name
	    $t add VCS           $vcsname
	    $t add {Local Store} $path
	    $t add Size          $dsize
	    $t add Commits       $dcommit
	    if {$export ne {}} {
		$t add Export $export
	    }
	    $t add {Update Stats} $spent
	    $t add {Last Change}  $changed
	    $t add {Last Check}   $updated
	    $t add Created        $created

	    set active 1
	    foreach {label urls} $r {
		$t add $label "\#[llength $urls]"
		# TODO: options to show all, part, none
		if {$label eq "Forks"} break
		foreach url [lsort -dict $urls] {
		    incr id
		    set a "    "
		    if {$active} {
			set a [dict get	[m repo get [m repo id $url]] active]
			if {$a} {
			    set a "    "
			} else {
			    set a "off "
			}
		    }
		    $t add $id [L "$a$url"]
		}
		unset -nocomplain id
		incr active -1
	    }

	    if {!$full} {
		set nelines #[llength [split $stderr \n]]
		set nllines #[llength [split $stdout \n]]

		$t add Operation $nllines
		if {$stderr ne {}} {
		    $t add "Notes & Errors" [color bad $nelines]
		} else {
		    $t add "Notes & Errors" $nelines
		}
	    } else {
		if {$stdout ne {}} { $t add Operation        [L $stdout] }
		if {$stderr ne {}} { $t add "Notes & Errors" [L $stderr] }
	    }
	}] show
    }
    OK
}

proc ::m::glue::SI {stderr} {
    if {$stderr eq {}} {
	return [color good OK]
    } else {
	set status images/bad.svg
	return [color bad ATTEND]
    }
}

proc ::m::glue::cmd_enable {flag config} {
    debug.m/glue {[debug caller] | }
    package require m::mset
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
	    #    mset	: mirror set id
	    #    name	: mirror set name
	    #    store  : store id, of backing store for the repo
	    
	    m repo enable $repo $flag

	    # Note: We do not manipulate `mset_pending`. An existing
	    # mirror set is always in `mset_pending`, even if all its
	    # remotes are inactive. The commands to retrieve the
	    # pending msets (all, or taken for update) is where we do
	    # the filtering, i.e. exclusion of those without active
	    # remotes.
	}
    }

    ShowCurrent $config
    SiteRegen
    OK
}

proc ::m::glue::cmd_rename {config} {
    debug.m/glue {[debug caller] | }
    package require m::mset
    package require m::store

    m db transaction {
	set mset    [$config @mirror-set] ; debug.m/glue {mset    : $mset}
	set newname [$config @name]       ; debug.m/glue {new name: $newname}
	set oldname [m mset name $mset]

	m msg "Renaming [color note $oldname] ..."
	if {$newname eq $oldname} {
	    m::cmdr::error \
		"The new name is the same as the current name." \
		NOP
	}
	if {[m mset has $newname]} {
	    m::cmdr::error \
		"New name [color note $newname] already present" \
		HAVE_ALREADY NAME
	}

	Rename $mset $newname
    }

    ShowCurrent $config
    SiteRegen
    OK
}

proc ::m::glue::cmd_merge {config} {
    debug.m/glue {[debug caller] | }
    package require m::mset
    package require m::repo
    package require m::rolodex
    package require m::store
    package require m::vcs

    m db transaction {
	set msets [Dedup [MergeFill [$config @mirror-sets]]]
	# __Attention__: Cannot place the mergefill into a generate
	# clause, the parameter logic is too simple (set / not set) to
	# handle the case of `set only one`.
	debug.m/glue {msets = ($msets)}

	if {[llength $msets] < 2} {
	    m::cmdr::error \
		"All repositories are already in the same mirror set." \
		NOP
	}

	set secondaries [lassign $msets primary]
	m msg "Target:  [color note [m mset name $primary]]"

	foreach secondary $secondaries {
	    m msg "Merging: [color note [m mset name $secondary]]"
	    Merge $primary $secondary
	}
    }

    ShowCurrent $config
    SiteRegen
    OK
}

proc ::m::glue::cmd_split {config} {
    debug.m/glue {[debug caller] | }
    package require m::mset
    package require m::repo
    package require m::rolodex
    package require m::store
    package require m::vcs

    m db transaction {
	set repo [$config @repository]
	set rinfo [m repo get $repo]
	dict with rinfo {}
	# -> url	: repo url
	#    vcs	: vcs id
	#    vcode	: vcs code
	#    mset	: mirror set id
	#    name	: mirror set name
	#    store      : store id, of backing store for the repo

	m msg "Attempting to separate"
	m msg "  Repository [color note $url]"
	m msg "  Managed by [color note [m vcs name $vcs]]"
	m msg "From"
	m msg "  Mirror set [color note $name]"

	if {[m mset size $mset] < 2} {
	    m::cmdr::error \
		"The mirror set is to small for splitting" \
		ATOMIC
	}

	set newname [MakeName $name]
	set msetnew [m mset add $newname]

	m msg "New"
	m msg "  Mirror set [color note $newname]"

	m repo move/1 $repo $msetnew

	if {![m mset has-vcs $mset $vcs]} {
	    # The moved repository was the last user of its vcs in the
	    # original mirror set. We can simply move its store over
	    # to the new holder to be ok.

	    m msg "  Move store ..."

	    m store move $store $msetnew
	} else {
	    # The originating mset still has users for the store used
	    # by the moved repo. Need a new store for the moved repo.

	    m msg "  Split store ..."

	    m store split $store $msetnew
	}
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
    package require m::mset
    package require m::state
    package require m::store

    set nowcycle [clock seconds]

    m db transaction {
	set verbose  [$config @verbose]
	set msets    [UpdateSets $nowcycle [$config @mirror-sets]]
	debug.m/glue {msets = ($msets)}

	foreach mset $msets {
	    set mname [m mset name $mset]
	    m msg "Updating Mirror Set [color note $mname] ..."

	    set stores [m mset stores $mset]
	    debug.m/glue {stores = ($stores)}

	    foreach store $stores {
		set vname [m store vcs-name $store]
		if {$verbose} {
		    m msg "  [color note $vname] store ... "
		} else {
		    m msg* "  $vname store ... "
		}

		# TODO MAYBE: List the remotes we are pulling from ?
		# => VCS layer, notification callback ...
		set counts [m store update $store $nowcycle [clock seconds]]
		lassign $counts before after forks remotes spent
		debug.m/glue {update = ($counts)}
		
		set    suffix ""
		append suffix ", in " [color note [m format interval $spent]]
		append suffix " ("    [color note [lindex $remotes 0]] ")"
		if {$forks ne {}} {
		    append suffix \n "  Github: Currently tracking [color note [llength $forks]] additional forks"
		}

		if {$before < 0} {
		    # Highlevel VCS url check failed for this store.
		    # Results in the stderr log.
		    lassign [m vcs caps $store] _ e
		    m msg "[color bad Fail]$suffix"
		    m msg $e

		} elseif {$before != $after} {
		    set delta [expr {$after - $before}]
		    if {$delta < 0} {
			set mark bad
		    } else {
			set mark note
			set delta +$delta
		    }
		    m msg "[color note Changed] $before $after ([color $mark $delta])$suffix"
		} elseif {$verbose} {
		    m msg "[color note "No changes"]$suffix"
		} else {
		    m msg "No changes$suffix"
		}
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
	# TODO: get status (stderr), show - store id
	set series {}
	foreach row [TruncH [m store updates] [expr {[$config @th]-1}]] {
	    if {[lindex $row 0] eq "..."} {
		lappend series [list ... {} {} {} {} {} {}]
		continue
	    }
	    # store mname vcode changed updated created size active remote
	    # sizep commits commitp mins maxs lastn
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

	    lappend series [list $mname $vcode $dsize $dcommit $lastn $changed $updated $created]
	}
    }
    lassign [TruncW \
		 {{Mirror Set} VCS Size Commits Time Changed Updated Created} \
		 {1 0 0 0 0 0 0 0} \
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
    package require m::mset
    package require m::state

    m db transaction {
	set series {}
	set take   [m state take]
	foreach {mname numrepo} [m mset pending] {
	    if {$take} {
		lappend series [list * $mname $numrepo]
		incr take -1
	    } else {
		lappend series [list {} $mname $numrepo]
	    }
	}
    }
    lassign [TruncW \
		 {{} {Mirror Set} #Repositories} \
		 {0 1 0} \
		 [TruncH $series [$config @th]] [$config @tw]] \
	titles series
    [table t $titles {
	foreach row $series {
	    $t add {*}$row
	}
    }] show
    OK
}

proc ::m::glue::cmd_issues {config} {
    debug.m/glue {[debug caller] | }
    package require m::mset
    package require m::repo
    package require m::rolodex
    package require m::store

    m db transaction {
	set series {}
	foreach row [m store issues] {
	    dict with row {}
	    # store mname vcode changed updated created size active remote
	    set size [m format size $size]

	    # urls of repos associated with the store
	    set urls [lindex [m store remotes $store] 0]
		
	    foreach url $urls {
		set rid [m repo id $url]
		lappend series [list $rid $url $mname $vcode $size]
		m rolodex push $rid
	    }
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
		 {Tag Repository Set VCS Size} \
		 {0 1 3 0 0} \
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
    package require m::mset
    package require m::repo
    package require m::rolodex
    package require m::store

    m db transaction {
	set series {}
	foreach row [m store disabled] {
	    dict with row {}
	    # store mname vcode changed updated created size active remote attend rid url
	    set size [m format size $size]

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
		 {Tag Repository Set VCS Size} \
		 {0 1 3 0 0} \
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
		set first [list $name $url]
		debug.m/glue {from request: $first}
		unset name url vcs vcode store ri
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
	# series = list (dict (mset url rid vcode sizekb active sizep commits commitp mins maxs lastn))

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
	    # name url id vcode sizekb active sizep commits commitp mins maxs lastn
	    incr idx
	    #set url [color note $url]
	    set ix  [m rolodex id $id]
	    set tag {}
	    if {$ix  ne {}}     { lappend tag @$ix }
	    if {$idx == ($n-2)} { lappend tag @p }
	    if {$idx == ($n-1)} { lappend tag @c }
	    set a [expr {$active ? "A" : "-"}]

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
		 {Tag {} Repository Set VCS Size Commits Time} \
		 {0 0 1 2 0 -1 -1 0} \
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
		 {0 0 2 0 3 0 1} \
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
		 {1 0} \
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
    package require m::mset
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

	    MailHeader mail Accepted $desc
	    lappend mail "Your submission has been accepted."
	    lappend mail "The repository should appear on our web-pages soon."
	    MailFooter mail
	    
	    m mailer to $email \
		[m mail generator reply [join $mail \n] $details]
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

	    MailHeader themail Declined $desc
	    lappend    themail "We are sorry to tell you that we are declining it."
	    lappend    themail $text ;# cause
	    MailFooter themail

	    m mailer to $email \
		[m mail generator reply [join $themail \n] $details]
	    unset themail
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

    m db transaction {
	m msg [ComeAroundMail [m state start-of-current-cycle] [clock seconds]]
    }
    OK    
}

proc ::m::glue::cmd_test_mail_config {config} {
    debug.m/glue {[debug caller] | }
    package require m::mailer
    package require m::mail::generator

    m mailer to [$config @destination] \
	[m mail generator test]
    OK    
}

proc ::m::glue::cmd_test_vt_repository {config} {
    debug.m/glue {[debug caller] | }
    package require m::repo

    set map [m repo known]
    [table/d t {
	foreach k [lsort -dict [dict keys $map]] {
	    set v [dict get $map $k]
	    $t add $k $v
	}
    }] show
    OK
}

proc ::m::glue::cmd_test_vt_mset {config} {
    debug.m/glue {[debug caller] | }
    package require m::mset

    set map [m mset known]
    [table/d t {
	foreach k [lsort -dict [dict keys $map]] {
	    set v [dict get $map $k]
	    $t add $k $v
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
	    $t add $k $v
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
	    $t add $k $v
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
    # command :: list ('M' name)
    #          | list ('R' vcode url)
}

proc ::m::glue::ImportVerify {commands} {
    debug.m/glue {}
    # commands :: list (command)
    # command  :: list ('M' name)
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
	    M {
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
		    m msg "Line $lno: [color warning Skip] empty mirror set [color note $vcs]"
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

    m msg "Handling [color note $mname] ..."

    if {[llength $repos] == 2} {
	lassign $repos vcode url
	# The mirror set contains only a single repository.
	# We might be able to skip the merge
	if {![m mset has $mname]} {
	    # No mirror set of the given name exists.
	    # Create directly in final form. Skip merge.
	    try {
		ImportMake1 $vcode $url $mname
	    } trap {M VCS CHILD} {e o} {
		# Revert creation of mset and repository
		set repo [m rolodex top]
		set mset [m repo mset $repo]
		m repo remove  $repo
		m rolodex drop $repo
		m mset remove  $mset

		m msg "[color bad {Unable to import}] [color note $mname]: $e"
		# No rethrow, the error in the child is not an error
		# for the whole command. Continue importing the remainder.
	    }
	    return
	}
    }

    # More than a single repository in this set, or the destination
    # mirror set exists. Merging is needed. And the untrusted nature
    # of the input means that we cannot be sure that merging is even
    # allowed.

    # Two phases:
    # - Create the repositories. Each in its own mirror set, like for `add`.
    #   Set names are of the form `import_<date>`, plus a serial number.
    #   Comes with associated store.
    #
    # - Go over the repositories again and merge them.  If a
    #   repository is rejected by the merge keep it separate. Retry
    #   merging using the rejections. The number of retries is finite
    #   because each round finalizes at least one mirror set and its
    #   repositories of the finite supply. At the end of this phase we
    #   have one or more mirror sets each with maximally merged
    #   repositories. Each finalized mirror set is renamed to final
    #   form, based on the incoming mname and date.

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
	    set mset [m repo mset $repo]
	    m repo remove  $repo
	    m rolodex drop $repo
	    m mset remove  $mset

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
    if {[m mset has $mname]} {
	# Targeted mirror set exists. Make it first in the merge list.
	set mset [m mset id $mname]
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
	# finalizes at least one mirror set, ensuring termination of
	# the loop.
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
    set mset    [m mset add $tmpname]
    set url     [m vcs url-norm $vcode $url]

    m rolodex push [m repo add $vcs $mset $url]

    m msg "  Setting up the $vcode store for [color note $url] ..."
    lassign [m store add $vcs $mset $tmpname $url] store spent forks
    m msg "  [color note Done] in [color note [m format interval $spent]]"
    if {$forks ne {}} {
	m msg "  Github: Currently tracking [color note [llength $forks]] additional forks"
	foreach f $forks {
	    m msg "  - [color note $f]"
	}
    }

    return [list $vcs $mset $store]
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
    m msg "  Mirror set [color note $name]"

    if {[m repo has $url]} {
	m::cmdr::error \
	    "Repository already present" \
	    HAVE_ALREADY REPOSITORY
    }
    if {[m mset has $name]} {
	m::cmdr::error \
	    "Name already present" \
	    HAVE_ALREADY NAME
    }

    # TODO MAYBE: stuff how much of this logic into `repo add` ?

    set mset [m mset add $name]

    m rolodex push [m repo add $vcs $mset $url]

    m msg "  Setting up the $vcode store ..."
    lassign [m store add $vcs $mset $name $url] _ spent forks
    
    m rolodex commit
    m msg "  [color note Done] in [color note [m format interval $spent]]"
    if {$forks ne {}} {
	m msg "  Github: Currently tracking [color note [llength $forks]] additional forks"
	foreach f $forks {
	    m msg "  - [color note $f]"
	}
    }
    return
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
		# -> url	: repo url
		#    vcs	: vcs id
		#    vcode	: vcs code
		#    mset	: mirror set id
		#    name	: mirror set name
		#    store  : store id, of backing store for the repo
		
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
		     {0 1 3 0} \
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

proc ::m::glue::MakeName {prefix} {
    debug.m/glue {[debug caller] | }
    if {![m mset has $prefix]} { return $prefix }
    set n 1
    while {[m mset has ${prefix}#$n]} { incr n }
    return "${prefix}#$n"
}

proc ::m::glue::ComeAroundMail {current newcycle} {
    debug.m/glue {[debug caller] | }
    package require m::db
    package require m::state
    package require m::store
    package require m::format

    lappend mail "\[[info hostname]\] Cycle Report."
    lappend mail "The cycle\nfrom [clock format $current]\nto   [clock format $newcycle]"

    set n 0
    table t {Changed Time Size Commits VCS {Mirror Set}} {
	foreach row [m store updates] {
	    dict with row {}
	    # store mname vcode changed updated created size active remote
	    # sizep commits commitp mins maxs lastn
	    if {$created eq "."} continue ;# ignore separations
	    if {$changed < $current} continue ;# older cycle

	    # This row is for the cycle which justed ended. Put into the mail.
	
	    if {!$n} {
		lappend mail "found @/n/@ changed repositories:\n"
	    }
	    incr n

	    set dcommit [DeltaCommitFull $commits $commitp]
	    set dsize   [DeltaSizeFull $size $sizep]
	    set changed [m format epoch $changed]
	    set spent   [StatsTime $mins $maxs $lastn]

	    $t add $changed $spent $dsize $dcommit $vcode $mname
	}
    }

    if {!$n} {
	# No changes found
	lappend mail "found no changes."
    } else {
	# Add the table ito the mail
	lappend mail [$t show return]
	# Note: The `return` prempts the show from destroying the table.
    }
    $t destroy
    MailFooter mail

    return [string map [list @/n/@ $n] [join $mail \n]]
}

proc ::m::glue::ComeAround {newcycle} {
    debug.m/glue {[debug caller] | }
    # Called when the update cycle comes around back to the start.
    # Creates a mail reporting on all the mirror sets which where
    # changed in the previous cycle.

    set current [m state start-of-current-cycle]
    m state start-of-previous-cycle $current
    m state start-of-current-cycle  $newcycle
    
    set email [m state report-mail-destination]

    if {$email eq {}} {
	debug.m/glue {[debug caller] | Skipping report without destination}
	# Nobody to report to, skipping report
	return
    }

    m mailer to $email \
	[m mail generator reply [ComeAroundMail $current $newcycle] {}]
    return
}

proc ::m::glue::UpdateSets {now msets} {
    debug.m/glue {[debug caller] | }

    set n [llength $msets]
    if {!$n} {
	# No repositories specified.
	# Pull mirror sets directly from pending
	return [m mset take-pending [m state take] \
		    ::m::glue::ComeAround $now]
    }

    return $msets
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

proc ::m::glue::MergeFill {msets} {
    debug.m/glue {[debug caller] | }
    set n [llength $msets]

    if {!$n} {
	# No mirror sets. Use the mirror sets for current and previous
	# repository as merge target and source

	set target [m rolodex top]
	if {$target eq {}} {
	    m::cmdr::error \
		"No current repository to indicate merge target" \
		MISSING CURRENT
	}
	set origin [m rolodex next]
	if {$origin eq {}} {
	    m::cmdr::error \
		"No previously current repository to indicate merge source" \
		MISSING PREVIOUS
	}
	lappend msets [m repo mset $target] [m repo mset $origin]
	return $msets
    }
    if {$n == 1} {
	# A single mirror set is the merge origin. Use the mirror set
	# of the current repository as merge target.
	set target [m rolodex top]
	if {$target eq {}} {
	    m::cmdr::error \
		"No current repository to indicate merge target" \
		MISSING CURRENT
	}
	return [linsert $msets 0 [m repo mset $target]]
    }
    return $msets
}

proc ::m::glue::Rename {mset newname} {
    debug.m/glue {[debug caller] | }
    m mset rename $mset $newname

    # TODO MAYBE: stuff cascading logic into `mset rename` ?
    foreach store [m mset stores $mset] {
	m store rename $store $newname
    }
    return
}

proc ::m::glue::Merge {target origin} {
    debug.m/glue {[debug caller] | }

    # Target and origin are mirror sets.
    #
    # - Check that all the origin's repositories fit into the target.
    #   This is done by checking the backing stores of the vcs in use
    #   for compatibility.
    #
    # - When they do the stores are moved or merged, depending on
    # - presence of the associated vcs in the target.

    set vcss [m mset used-vcs $origin]

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

    # Move or merge the stores, dependong presence in the target.
    foreach vcs $vcss {
	set ostore [m store id $vcs $origin]
	if {![m store has $vcs $target]} {
	    m store move $ostore $target
	} else {
	    m store merge [m store id $vcs $target] $ostore
	}
    }

    # Move the repositories, drop the origin set, empty after the move
    m repo move/mset $origin $target
    m mset remove    $origin
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
    $t add {*}[InvalE ${prefix}Url       site-url]
    $t add ${prefix}Logo       [m state  site-logo]
    $t add {*}[InvalE ${prefix}Title     site-title]
    $t add ${prefix}Manager  {}
    $t add {*}[InvalE "${prefix}- Name"  site-mgr-name]
    $t add {*}[InvalE "${prefix}- Mail"  site-mgr-mail]
    $t add {*}[InvalE ${prefix}Location  site-store]
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
    
    # compute series column widths (max len) for all columns.  If the
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
	if {$w <= 0} continue
	set drop [format %.0f [expr {double($over * $w)/$tw}]]
	incr removed $drop
	incr wc($c) -$drop
    }
    # --assert: removed >= over
    debug.m/glue { removed      : $removed }
    # Rounding may cause removed < over, leaving too much chracters behind.
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

    append text "$mins ... $maxs"

    set lastn [split [string trim $lastn ,] ,]
    set n     [llength $lastn]

    if {!$n} { return $text }
    
    set maxn [m state store-window-size]
    if {$n > $maxn} {
	set over    [expr {$n - $maxn}]
	set lastn [lreplace $lastn 0 ${over}-1]
    }
    set n       [llength $lastn]
    set total   [expr [join $lastn +]]
    set avg     [m format interval [format %.0f [expr {double($total)/$n}]]]
    
    append text " ($avg * $n)"
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
