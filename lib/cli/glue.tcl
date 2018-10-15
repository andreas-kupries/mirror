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

package require Tcl 8.5
package require cmdr::color
package require cmdr::table 0.1 ;# API: headers, borders
package require debug
package require debug::caller

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
debug prefix m/glue {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::m::glue::gen_limit {p} {
    debug.m/glue {}
    package require m::state
    return [m state limit]
}

proc ::m::glue::gen_url {p} {
    debug.m/glue {}
    package require m::submission
    set details [m submission get [$p config @id]]
    dict with details {}
    # -> url
    #    email
    #    submitter
    #    when
    return $url
}

proc ::m::glue::gen_name {p} {
    debug.m/glue {}
    package require m::mset
    package require m::vcs

    # Derive a name from the url when no such was specified by the
    # user. Add a serial number if that name is already in use.
    set name [m vcs name-from-url [$p config @vcs-code] [$p config @url]]
    if {[m mset has $name]} {
	set name [MakeName $name]
    }
    return $name
}

proc ::m::glue::gen_vcs {p} {
    debug.m/glue {}
    # Auto detect vcs of url when not specified by the user.
    package require m::validate::vcs
    package require m::vcs
    #
    return [m validate vcs validate $p [m vcs detect [$p config @url]]]
}

proc ::m::glue::gen_vcs_code {p} {
    debug.m/glue {}
    # Determine vcs code from the database id.
    package require m::vcs
    #
    return [m vcs code [$p config @vcs]]
}

proc ::m::glue::gen_current {p} {
    debug.m/glue {}
    # Provide current as repository for operation when not specified
    # by the user. Fail if we have no current repository.
    package require m::rolodex
    #
    set r [m rolodex top]
    if {$r ne {}} { return $r }
    $p undefined!
    # Will not reach here
}

proc ::m::glue::gen_current_mset {p} {
    debug.m/glue {}
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
	    return $m
	}
    }
    $p undefined!
    # Will not reach here
}

# # ## ### ##### ######## ############# ######################

proc ::m::glue::cmd_reply_add {config} {
    debug.m/glue {}
    package require m::db
    package require m::reply
    
    m db transaction {
	set reply [$config @reply]
	set text  [$config @text]
	set mail  [$config @auto-mail]

	puts "New reason to reject a submission:"
	puts "  Name:      [color note $reply]"
	puts "  Text:      [color note $text]"
	puts "  auto-Mail: [expr {$mail ? "yes" : "no"}]"
	
	m reply add $reply $mail $text
    }
    OK
}

proc ::m::glue::cmd_reply_remove {config} {
    debug.m/glue {}
    package require m::db
    package require m::reply
    
    m db transaction {
	set reply [$config @reply]
	set name  [$config @reply string]

	puts "Remove [color note $name] as reason for rejecting a submission."
	if {[m reply default? $reply]} {
	    m::cmdr::error \
		"Cannot remove default reason" \
		UNREMOVABLE DEFAULT
	}

	m reply remove $reply
    }
    OK
}

proc ::m::glue::cmd_reply_change {config} {
    debug.m/glue {}
    package require m::db
    package require m::reply
    
    m db transaction {
	set reply [$config @reply]
	set name  [$config @reply string]
	set text  [$config @text]

	puts "Change reason [color note $name] to reject a submission:"
	puts "  New text: [color note $text]"
	
	m reply change $reply $text
    }
    OK
}

proc ::m::glue::cmd_reply_default {config} {
    debug.m/glue {}
    package require m::db
    package require m::reply
    
    m db transaction {
	set reply [$config @reply]
	set name [$config @reply string]
	puts "Set [color note $name] as default reason to reject a submission."

	m reply default! $reply
    }
    OK
}

proc ::m::glue::cmd_reply_show {config} {
    debug.m/glue {}
    package require m::db
    package require m::reply
    
    m db transaction {
	[table t {{} Name Mail Text} {
	    foreach {name default mail text} [m reply list] {
		set mail    [expr {$mail    ? "*" : ""}]
		set default [expr {$default ? "#" : ""}]
		
		$t add $default [color note $name] $mail $text
	    }
	}] show
    }
    OK
}

proc ::m::glue::cmd_mailconfig_show {config} {
    debug.m/glue {}
    package require m::state

    m db transaction {
	[table/d t {
	    $t add Host   [m state mail-host]
	    $t add Port   [m state mail-port]
	    $t add User   [m state mail-user]
	    $t add Pass   [m state mail-pass]
	    $t add TLS    [m state mail-tls]
	    $t add Sender [m state mail-sender]
	    $t add Header [m state mail-header]
	    $t add Footer [m state mail-footer]
	}] show
    }
    OK
}

proc ::m::glue::cmd_mailconfig {key desc config} {
    debug.m/glue {}
    package require m::state

    m db transaction {
	if {[$config @value set?]} {
	    m state $key [$config @value]
	}

	set value [m state $key]
    }

    puts "The $desc: [color note $value]"
    OK
}

proc ::m::glue::cmd_store {config} {
    debug.m/glue {}
    package require m::state

    m db transaction {
	if {[$config @path set?]} {
	    m state store [file normalize [$config @path]]
	    # TODO: copy/move all backing stores to the new location.
	    puts [color bad {TODO: Move backing store to new base}]
	}
    }

    puts "Stores at [color note [m state store]]"
    OK
}

proc ::m::glue::cmd_take {config} {
    debug.m/glue {}
    package require m::state

    m db transaction {
	if {[$config @take set?]} {
	    m state take [$config @take]
	}

	set n [m state take]
    }

    set g [expr {$n == 1 ? "mirror set" : "mirror sets"}]
    puts "Per update, take [color note $n] $g"
    OK
}

proc ::m::glue::cmd_vcs {config} {
    debug.m/glue {}
    package require m::vcs

    puts [color note {Supported VCS}]

    m db transaction {
	[table t {Code Name Version} {
	    foreach {code name} [m vcs list] {
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
    debug.m/glue {}
    package require m::mset
    package require m::repo
    package require m::rolodex
    package require m::store

    m db transaction {
	Add $config
    }	
    ShowCurrent
    OK
}

proc ::m::glue::cmd_remove {config} {
    debug.m/glue {}
    package require m::mset
    package require m::repo
    package require m::rolodex
    package require m::store

    m db transaction {
	set repo [$config @repository]
	puts "Removing [color note [m repo name $repo]] ..."

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
	    puts "- Removing $vcode store ..."
	    m store remove $store
	}

	# Remove mirror set if no repositories remain at all.
	if {![m mset size $mset]} {
	    puts "- Removing mirror set [color note $name] ..."
	    m mset remove $mset
	}

	m rolodex drop $repo
	m rolodex commit
    }

    ShowCurrent
    OK
}

proc ::m::glue::cmd_rename {config} {
    debug.m/glue {}
    package require m::mset
    package require m::store

    m db transaction {
	set mset    [$config @mirror-set] ; debug.m/glue {mset    : $mset}
	set newname [$config @name]       ; debug.m/glue {new name: $newname}
	set oldname [m mset name $mset]
	
	puts "Renaming [color note $oldname] ..."
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

	m mset rename $mset $newname

	# TODO MAYBE: stuff cascading logic into `mset rename` ?
	foreach store [m mset stores $mset] {
	    m store rename $store $newname
	}
    }

    ShowCurrent
    OK
}

proc ::m::glue::cmd_merge {config} {
    debug.m/glue {}
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
	puts "Target:  [color note [m mset name $primary]]"

	foreach secondary $secondaries {
	    puts "Merging: [color note [m mset name $secondary]]"
	    Merge $primary $secondary
	}
    }

    ShowCurrent
    OK
}

proc ::m::glue::cmd_split {config} {
    debug.m/glue {}
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

	puts "Attempting to separate"
	puts "  Repository [color note $url]"
	puts "  Managed by [color note [m vcs name $vcs]]"
	puts "From"
	puts "  Mirror set [color note $name]"

	if {[m mset size $mset] < 2} {
	    m::cmdr::error \
		"The mirror set is to small for splitting" \
		ATOMIC
	}

	set newname [MakeName $name]
	set msetnew [m mset add $newname]

	puts "New"
	puts "  Mirror set [color note $newname]"

	m repo move/1 $repo $msetnew

	if {![m mset has-vcs $mset $vcs]} {
	    # The moved repository was the last user of its vcs in the
	    # original mirror set. We can simply move its store over
	    # to the new holder to be ok.

	    puts "  Move store ..."

	    m store move $store $msetnew
	} else {
	    # The originating mset still has users for the store used
	    # by the moved repo. Need a new store for the moved repo.

	    puts "  Split store ..."

	    m store split $store $msetnew
	}
    }

    ShowCurrent
    OK
}

proc ::m::glue::cmd_current {config} {
    debug.m/glue {}

    ShowCurrent
    OK
}

proc ::m::glue::cmd_swap_current {config} {
    debug.m/glue {}
    package require m::repo
    package require m::rolodex

    m db transaction {
	m rolodex swap
	m rolodex commit
    }

    ShowCurrent
    OK
}

proc ::m::glue::cmd_set_current {config} {
    debug.m/glue {}
    package require m::repo
    package require m::rolodex

    m db transaction {
	m rolodex push [$config @repository]
	m rolodex commit
    }

    ShowCurrent
    OK
}

proc ::m::glue::cmd_update {config} {
    debug.m/glue {}
    package require m::mset
    package require m::state
    package require m::store

    m db transaction {
	set verbose  [$config @verbose]
	set nowcycle [clock seconds]
	set msets    [UpdateSets [$config @mirror-sets]]
	debug.m/glue {msets = ($msets)}

	foreach mset $msets {
	    set mname [m mset name $mset]
	    puts "Updating Mirror Set [color note $mname] ..."

	    set stores [m mset stores $mset]
	    debug.m/glue {stores = ($stores)}

	    foreach store $stores {
		set vname [m store vcs-name $store]
		if {$verbose} {
		    puts "  [color note $vname] store ... "
		} else {
		    puts -nonewline "  $vname store ... "
		    flush stdout
		}

		# TODO MAYBE: List the remotes we are pulling from ? => VCS layer, notification callback ...

		set counts [m store update $store $nowcycle [clock seconds]]
		lassign $counts before after
		if {$before != $after} {
		    set delta [expr {$after - $before}]
		    if {$delta < 0} {
			set mark bad
		    } else {
			set mark note
			set delta +$delta
		    }
		    puts "[color note Changed] $before $after ([color $mark $delta])"
		} elseif {$verbose} {
		    puts [color note "No changes"]
		} else {
		    puts "No changes"
		}
	    }
	}
    }

    OK
}

proc ::m::glue::cmd_updates {config} {
    debug.m/glue {}
    package require m::store
    
    m db transaction {
	set series [m store updates]
	[table t {{Mirror Set} VCS Changed Updated Created} {
	    foreach {mname vcode changed updated created} $series {
		if {$created eq "."} {
		    $t add - - - - -
		    continue
		}
		set changed [Date $changed]
		set updated [Date $updated]
		set created [Date $created]
		$t add $mname $vcode $changed $updated $created
	    }
	}] show
    }
    OK
}

proc ::m::glue::cmd_pending {config} {
    debug.m/glue {}
    package require m::mset
    package require m::state
    
    m db transaction {
	set series [m mset pending]
	set take   [m state take]

	[table t {{} {Mirror Set} #Repositories} {
	    foreach {mname numrepo} $series {
		if {$take} {
		    $t add * $mname $numrepo
		    incr take -1
		} else {
		    $t add {} $mname $numrepo
		}
	    }
	}] show
    }
    OK
}

proc ::m::glue::cmd_list {config} {
    debug.m/glue {}
    package require m::repo
    package require m::rolodex
    package require m::state

    m db transaction {
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

	lassign [m repo get-n $first $limit] next series
	# series = (mset url rid vcode ...)

	debug.m/glue {next   ($next)}
	debug.m/glue {series ($series)}

	m state top $next

	set n 0
	foreach {_ _ repo _} $series {
	    m rolodex push $repo
	    incr n
	}

	# See also ShowCurrent
	# TODO: extend list with store times ?
	[table t {Tag Repository Set VCS} {
	    set id -1
	    foreach {mname url repo vcode} $series {
		incr id
		set url [color note $url]
		set ix [m rolodex id $repo]
		set tag {}
		if {$ix ne {}} { lappend tag @$ix }
		if {$id == ($n-2)} { lappend tag @p }
		if {$id == ($n-1)} { lappend tag @c }
		$t add $tag $url $mname $vcode
	    }
	}] show
    }

    OK
}

proc ::m::glue::cmd_reset {config} {
    debug.m/glue {}
    package require m::state

    m state top {}

    puts "List paging reset to start from the top/bottom"
    OK
}

proc ::m::glue::cmd_rewind {config} {
    debug.m/glue {}
    puts [info level 0]		;# XXX TODO FILL-IN rewind
    return
}

proc ::m::glue::cmd_limit {config} {
    debug.m/glue {}
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
    
    set e [expr {$n == 1 ? "entry" : "entries"}]
    puts "Per list/rewind, show up to [color note $n] $e"
    OK
}

proc ::m::glue::cmd_submissions {config} {
    debug.m/glue {}
    package require m::submission

    m db transaction {
	[table t {{} When Url Email Submitter} {
	    foreach {id url email submitter when} [m submission list] {
		set id %$id
		set when [Date $when]

		$t add $id $when $url $email $submitter
	    }
	}] show
    }
    OK
}

proc ::m::glue::cmd_rejected {config} {
    debug.m/glue {}
    package require m::submission

    m db transaction {
	[table t {Url Reason} {
	    foreach {url reason} [m submission rejected] {
		$t add $url $reason
	    }
	}] show
    }
    OK
}

proc ::m::glue::cmd_submit {config} {
    debug.m/glue {}
    package require m::submission

    m db transaction {
	set url       [$config @url]
	set email     [$config @email]
	set submitter [$config @submitter]

	set name [color note $email]
	if {$submitter ne {}} {
	    append name " ([color note $submitter])"
	}
	puts "Submitted [color note $url]"
	puts "By        $name"
	
	m submission add $url $email $submitter
    }
    OK
}

proc ::m::glue::cmd_accept {config} {
    debug.m/glue {}
    package require m::mset
    package require m::repo
    package require m::rolodex
    package require m::store
    package require m::submission

    m db transaction {
	set submission [$config @id]
	set details    [m submission get $submission]
	dict with details {}
	# -> url
	#    email
	#    submitter
	#    when
	set name [color note $email]
	if {$submitter ne {}} {
	    append name " ([color note $submitter])"
	}
	    
	puts "Accepted $url"
	puts "By       $name"
	    
	m submission accept $submission
	Add $config

	puts "Sending mail ..."
	# TODO send mail
    }
    OK
}

proc ::m::glue::cmd_reject {config} {
    debug.m/glue {}
    package require m::submission
    # TODO: reply

    m db transaction {
	set submissions [$config @id]
	set mail        [$config @mail]
	set cause       [$config @cause]

	# TODO: get cause info
	# TODO: merge mail info

	puts "Cause: $cause"

	foreach submission $submissions {
	    set details [m submission get $submission]
	    dict with details {}
	    # -> url
	    #    email
	    #    submitter
	    #    when
	    set name [color note $email]
	    if {$submitter ne {}} {
		append name " ([color note $submitter])"
	    }
	    
	    puts "  Rejected $url"
	    puts "  By       $name"
	    
	    m submission reject $submission $cause

	    if {$mail} {
		puts "    Sending mail ..."
		# TODO send mail
	    }
	}
    }
    OK
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
    OK
}

proc ::m::glue::cmd_test_vt_mset {config} {
    debug.m/glue {}
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
    debug.m/glue {}
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
    debug.m/glue {}
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
    debug.m/glue {}
    puts [info level 0]		;# XXX TODO FILL-IN debug levels
    return
}

# # ## ### ##### ######## ############# ######################

proc ::m::glue::Add {config} {
    debug.m/glue {}
    set url   [$config @url]
    set vcs   [$config @vcs]
    set vcode [$config @vcs-code]
    set name  [$config @name]
    set url   [m vcs url-norm $vcode $url]
    # __Attention__: Cannot move the url normalization into a
    # when-set clause of the parameter. That generates a
    # dependency cycle:
    #
    #   url <- vcode <- vcs <- url

    puts "Attempting to add"
    puts "  Repository [color note $url]"
    puts "  Managed by [color note [m vcs name $vcs]]"
    puts "New"
    puts "  Mirror set [color note $name]"

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

    puts "  Setting up the $vcode store ..."

    m store add $vcs $mset $name $url

    m rolodex commit
    puts "  [color note Done]"
    return
}

proc ::m::glue::Date {epoch} {
    debug.m/glue {}
    if {$epoch eq {}} return
    return [clock format $epoch -format {%Y-%m-%d %H:%M:%S}]
}

proc ::m::glue::ShowCurrent {} {
    debug.m/glue {}
    package require m::repo
    package require m::rolodex

    m db transaction {
	set rolodex [m rolodex get]
	set n [llength $rolodex]
	if {$n} {
	    [table t {Tag Repository Set VCS} {
		$t borders 0
		$t headers 0
		set id -1
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

		    set url [color note $url]
		    lappend tag @$id
		    if {$id == ($n-2)} { lappend tag @p }
		    if {$id == ($n-1)} { lappend tag @c }
		    $t add $tag $url $name $vcode
		    unset tag
		}
	    }] show
	}
    }
}

proc ::m::glue::OK {} {
    debug.m/glue {}
    puts [color good OK]
    return -code return
}

proc ::m::glue::MakeName {prefix} {
    debug.m/glue {}
    set n 1
    while {[m mset has ${prefix}#$n]} { incr n }
    return "${prefix}#$n"
}

proc ::m::glue::UpdateSets {msets} {
    debug.m/glue {}

    set n [llength $msets]
    if {!$n} {
	# No repositories specified.
	# Pull mirror sets directly from pending
	return [m mset take-pending [m state take]]
    }

    return $msets
}

proc ::m::glue::Dedup {values} {
    debug.m/glue {}
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
    debug.m/glue {}
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

proc ::m::glue::Merge {target origin} {
    debug.m/glue {}

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

# # ## ### ##### ######## ############# ######################
package provide m::glue 0
return
