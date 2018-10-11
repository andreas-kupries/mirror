#!/usr/bin/env tclsh
## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package m::cmdr 0
# Meta author      {Andreas Kupries}
# Meta category    Cli command definitions
# Meta description Cli command definitions
# Meta location    https://core.tcl-lang.org/akupries/????
# Meta platform    tcl
# Meta require     cmdr
# Meta require     cmdr::color
# Meta require     cmdr::history
# Meta require     cmdr::help::tcl
# Meta require     cmdr::actor
# Meta require     {Tcl 8.5-}
# Meta require     lambda
# Meta require     debug
# Meta require     debug::caller
# Meta subject     ?
# Meta summary     ?
# @@ Meta End

package provide m::cmdr 0

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require cmdr::color ; # color activation
package require cmdr::history
package require cmdr::pager
package require cmdr::table
package require cmdr::validate::posint
package require cmdr::help::tcl
package require cmdr::actor 1.3 ;# Need -extend support for common/use blocks.
package require cmdr
package require debug
package require debug::caller
package require lambda

cmdr color define heading =bold ;# Table header color.
cmdr table show ::cmdr pager

# # ## ### ##### ######## ############# ######################

debug level  m/cmdr
debug prefix m/cmdr {[debug caller] | }

# # ## ### ##### ######## ############# ######################

namespace eval ::m {
    namespace export cmdr
    namespace ensemble create
}
namespace eval ::m::cmdr {
    namespace export main
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################

proc ::m::cmdr::main {argv} {
    debug.m/cmdr {}
    try {
	m::cmdr::dispatch do {*}$argv
    } trap {CMDR CONFIG WRONG-ARGS} {e o} - \
      trap {CMDR CONFIG BAD OPTION} {e o} - \
      trap {CMDR VALIDATE} {e o} - \
      trap {CMDR ACTION UNKNOWN} {e o} - \
      trap {CMDR ACTION BAD} {e o} - \
      trap {CMDR VALIDATE} {e o} - \
      trap {CMDR PARAMETER LOCKED} {e o} - \
      trap {CMDR PARAMETER UNDEFINED} {e o} - \
      trap {CMDR DO UNKNOWN} {e o} {
	debug.m/cmdr {trap - cmdline user error}
	puts stderr "$::argv0 cmdr: [cmdr color error $e]"
	return 1

    } trap {CMDR QUIT} {e o} {
	# Forced early return.
	# But not an error, nor even a warning.
	# This is a regular exit.

    } trap {M::CMDR} {e o} {
	debug.m/cmdr {trap - other user error}
	puts stderr "$::argv0 general: [cmdr color error $e]"
	return 1
	
    } on error {e o} {
	debug.m/cmdr {trap - general, internal error}
	debug.m/cmdr {[debug pdict $o]}
	# TODO: nicer formatting of internal errors.
	puts stderr [cmdr color error $::errorInfo]
	return 1
    }

    debug.m/cmdr {done, ok}
    return 0
}

# # ## ### ##### ######## ############# ######################
## Support commands constructing glue for various callbacks.

# NOTE: call, vt - Possible convenience cmds for Cmdr.
proc ::m::cmdr::call {pkg args} {
    lambda {pkg args} {
	package require m::$pkg
	m $pkg {*}$args
    } $pkg $args
}

proc ::m::cmdr::vt {p args} {
    lambda {p args} {
	package require m::validate::$p
	m::validate::$p {*}$args
    } $p {*}$args
}

proc ::m::cmdr::error {msg args} {
    return -code error \
	-errorcode [list M::CMDR {*}$args] \
	$msg
}

# # ## ### ##### ######## ############# ######################

cmdr history initial-limit 20
cmdr history save-to       ~/.mirror_history

cmdr create m::cmdr::dispatch [file tail $::argv0] {
    ##
    # # ## ### ##### ######## ############# #####################

    description {
	The mirror command line client
    }

    shandler ::cmdr::history::attach

    # # ## ### ##### ######## ############# #####################
    ## Bespoke category ordering for help
    ## Values are priorities. Final order is by decreasing priority.
    ## I.e. Highest priority is printed first, at the top, beginning.

    common *category-order* {
	Convenience -8900
	Advanced    -9000
    }

    # # ## ### ##### ######## ############# ######################
    ## Common pieces across the various commands.

    common *all* {
	option debug {
	    Placeholder. Processed before reaching cmdr.
	} {
	    undocumented
	    validate str
	}
	option color {
	    Force the (non-)use of colors in the output. The default
	    depends on the environment, active when talking to a tty,
	    and otherwise not.
	} {
	    when-set [lambda {p x} {
		cmdr color activate $x
	    }]
	}

	option database {
	    Use an alternate database instead of the default.
	} {
	    alias D
	    validate rwfile
	    when-set [lambda {p x} {
		package require m::db::location
		m::db::location set $x
	    }]
	}

	option verbose {
	    Activate more chatter.
	} { alias v
	    presence
	    when-set [lambda {p x} {
		package require m::exec
		m exec verbose on
	    }]
	}
    }

    common .optional-mirror-set {
	input mirror-set {
	    The mirror set to operate on.
	} { optional
	    validate [m::cmdr::vt mset]
	    generate [m::cmdr::call glue gen_current_mset]
	}
    }

    common .list-optional-mirror-set {
	input mirror-sets {
	    Repositories to operate on.
	} { list ; optional ; validate [m::cmdr::vt mset] }
    }

    common .optional-repository {
	input repository {
	    Repository to operate on.
	} { optional
	    validate [m::cmdr::vt repository]
	    generate [m::cmdr::call glue gen_current]
	}
    }

    common .list-optional-repository {
	input repositories {
	    Repositories to operate on.
	} { list ; optional ; validate [m::cmdr::vt repository] }
    }

    common .repository {
	input repository {
	    Repository to operate on.
	} { validate [m::cmdr::vt repository] }
    }

    # # ## ### ##### ######## ############# ######################

    private version {
	section Introspection
	description {
	    Print version and revision of the application.
	}
    } [lambda config {
	puts "[file tail $::argv0] [package present m::cmdr]"
    }]

    private store {
	description {
	    Query/change store path. Change implies copying all
	    existing stores to the new location. Removes all
	    pre-existing stores in the new location.
	}
	input path {
	    New location of the store
	} { optional ; validate rwpath }
    } [m::cmdr::call glue cmd_store]

    private take {
	description {
	    Query/change the number of mirror sets processed per
	    update cycle.
	}
	input take {
	    New number of mirror set to process in one update.
	} { optional ; validate cmdr::validate::posint }
    } [m::cmdr::call glue cmd_take]

    private vcs {
	description {
	    List supported version control systems
	}
    } [m::cmdr::call glue cmd_vcs]

    private remove {
	description {
	    Removes specified repository, or current.
	}
	use .optional-repository
    } [m::cmdr::call glue cmd_remove]

    private add {
	description {
	    Add repository. The new repository is placed into its own
	    mirror set. Command tries to auto-detect vcs type if not
	    specified. Command derives a name from the url if not
	    specified. New repository becomes current.
	}
	option vcs {
	    Version control system handling the repository.
	} {
	    validate [m::cmdr::vt vcs]
	    generate [m::cmdr::call glue gen_vcs]
	}
	state vcs-code {
	    Version control system handling the repository.
	    Internal code, derived from the option value (database id).
	} {
	    generate [m::cmdr::call glue gen_vcs_code]
	}
	input url {
	    Location of the repository to add.
	} { validate str }
	option name {
	    Name for the mirror set to hold the repository.
	} {
	    alias N
	    validate str
	    generate [m::cmdr::call glue gen_name]
	}
    } [m::cmdr::call glue cmd_add]

    private rename {
	description {
	    Change the name of the specified mirror set, or the mirror
	    set indicated by the current repository.

	    The rolodex does not change.
	}
	use .optional-mirror-set
	input name {
	    New name for the mirror set.
	} { validate str }
    } [m::cmdr::call glue cmd_rename]

    private merge {
	description {
	    Merges the specified mirror sets into a single mirror
	    set. When only one mirror set is specified the set of the
	    current repository is used as the merge target. When no
	    mirror sets are specified at all the mirror sets of
	    current and previous repositories are merged, using
	    the mirror set of current as merge target

	    The name of the primary mirror set becomes the name of the
	    merge.

	    The rolodex does not change.
	}
	use .list-optional-mirror-set
    } [m::cmdr::call glue cmd_merge]

    private split {
	description {
	    Split the specified or current repository from its mirror
	    set. Generates a new mirror set for the repository. The
	    name will be derived from the original name. The
	    referenced repository becomes current.

	    If the referenced repository is a standalone already then
	    nothing is done.
	}
	use .optional-repository
    } [m::cmdr::call glue cmd_split]

    private current {
	description {
	    Shows the rolodex.
	}
    } [m::cmdr::call glue cmd_current]
    alias @

    private set-current {
	description {
	    Makes the specified repository current.
	}
	use .repository
    } [m::cmdr::call glue cmd_set_current]
    alias =>
    alias go

    private swap {
	description {
	    Swap current and previous repository
	}
    } [m::cmdr::call glue cmd_swap_current]
    
    private update {
	description {
	    Runs an update cycle on the specified mirror sets. When no
	    mirror sets are specified use the next `take` number of
	    mirror sets from the list of pending mirror sets. If no
	    mirror sets are pending refill the list with the entire
	    set of mirror sets and then take from the list.
	}
	use .list-optional-mirror-set
    } [m::cmdr::call glue cmd_update]

    private updates {
	description {
	    Show compressed history of past updates.
	    Sorted by last changed, updated, created.
	    Empty lines between update cycles
	}
    } [m::cmdr::call glue cmd_updates]

    private pending {
	description {
	    Show list of currently pending mirror sets. I.e mirror
	    sets waiting for an update.  Order shown is the order they
	    are taken, from the top down.
	}
    } [m::cmdr::call glue cmd_pending]

    private list {
	description {
	    Show (partial) list of the known repositories.
	}
	option repository {
	    Repository to start the listing with.
	} {
	    alias R
	    validate [m::cmdr::vt repository]
	}
	option limit {
	    Number of repositories to show.
	    Defaults to the `limit`.
	} {
	    alias L
	    validate cmdr::validate::posint
	    generate [m::cmdr::call glue gen_limit]
	}
    } [m::cmdr::call glue cmd_list]

    private reset {
	description {
	    Reset list state to first entry.
	}
    } [m::cmdr::call glue cmd_reset]

    private rewind {
	description {
	    Like list, going backward through the set of repositories.
	}
    } [m::cmdr::call glue cmd_rewind]

    private limit {
	description {
	    Query/change default limit for repository listing.
	}
	input limit {
	    New number of repositories to show by list and rewind.
	} { optional ; validate cmdr::validate::posint }
    } [m::cmdr::call glue cmd_limit]

    private submissions {
	description {
	    List the submissions waiting for moderation.  Submissions
	    are shown with a shorthand id for easier reference by accept
	    or reject.
	}
    } [m::cmdr::call glue cmd_submissions]

    private accept {
	description {
	    Accept the specified submissions. Each will placed into
	    their own mirror set. The new repository will be entered
	    into the table of shorthands, as if `list` had been
	    invoked. (To any make upcoming merges easier).

	    Note, multiple separate acceptances accumulate.

	    Send mail to the specified email addresses to notify them
	    of the acceptance.
	}
	input id {
	    Submissions to accept
	} { list ; validate cmdr::validate::posint }
    } [m::cmdr::call glue cmd_accept]

    private reject {
	description {
	    Reject the specified submissions.
	    Do not send mail by default.
	    (No need to give my own mail address to spammers)

	    Mail can be forced, for example if the rejection is due to
	    reasons other than spam.
	}
	option mail {
	    Trigger generation and sending of rejection mail
	} { presence }
	input cause {
	    Cause of rejection
	} { validate str }
	input id {
	    Submissions to accept
	} { list ; validate cmdr::validate::posint }
    } [m::cmdr::call glue cmd_reject]

    # # ## ### ##### ######## ############# ######################
    ## Developer support, debugging.

    officer debug {
	description {
	    Various commands to help debugging the system itself
	    and its configuration.
	}
	common *all* -extend {
	    section Advanced Debugging
	}

	private test-vt-repo {
	    description {
		Show the knowledge map used by the repository validator.
	    }
	} [m::cmdr::call glue cmd_test_vt_repository]

	private levels {
	    description {
		List all the debug levels known to the system,
		which we can enable to gain a (partial) narrative
		of the application-internal actions.
	    }
	} [m::cmdr::call glue cmd_debug_levels]
    }

    # # ## ### ##### ######## ############# ######################
}

# # ## ### ##### ######## ############# ######################
return
