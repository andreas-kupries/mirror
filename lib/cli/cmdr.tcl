#!/usr/bin/env tclsh
# -*- mode: tcl; fill-column: 90 -*-
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
package require cmdr::validate
package require cmdr::validate::posint
package require cmdr::help::tcl
package require cmdr::actor 1.3 ;# Need -extend support for common/use blocks.
package require cmdr
package require debug
package require debug::caller
package require lambda

package require m::msg

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
	m emsg "$::argv0 cmdr: [cmdr color error $e]"
	return 1

    } trap {CMDR QUIT} {e o} {
	# Forced early return.
	# But not an error, nor even a warning.
	# This is a regular exit.

    } trap {M VCS CHILD} {e o} - \
      trap {M::CMDR} {e o} {
	debug.m/cmdr {trap - other user error}
	m emsg "$::argv0 general: [cmdr color error $e]"
	return 1

    } on error {e o} {
	debug.m/cmdr {trap - general, internal error}
	debug.m/cmdr {[debug pdict $o]}
	# TODO: nicer formatting of internal errors.
	m emsg [cmdr color error $::errorInfo]
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
	m {*}[string map {:: { }} $pkg] {*}$args
    } $pkg {*}$args
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
    ## Global options

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

    state tw {
	Terminal Width. Auto supplied to all commands.
    } { generate [lambda {args} {
	linenoise columns
    }] }

    state th {
	Terminal Height. Auto supplied to all commands.
    } { generate [lambda {args} {
	linenoise lines
    }] }

    common .optional-project {
	input project {
	    The project to operate on.
	} { optional
	    validate [m::cmdr::vt project]
	    generate [m::cmdr::call glue gen_current_project]
	}
    }

    common .list-optional-project {
	input projects {
	    Projects to operate on.
	} { list ; optional ; validate [m::cmdr::vt project] }
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
	m msg "[file tail $::argv0] [package present m::cmdr]"
    }]

    # # ## ### ##### ######## ############# ######################

    officer config {
	description {
	    Management of the instance configuration.
	}
	common *all* -extend {
	    section Configuration
	}

	private show {
	    description {
		Show the instance configuration (default)
	    }
	    option all {
		Show site and mail configuration as well
	    } { presence }
	} [m::cmdr::call glue cmd_show]
	default

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
		Query/change the number of repositories processed per
		update cycle.
	    }
	    input take {
		New number of projects to process in one update.
	    } { optional ; validate cmdr::validate::posint }
	} [m::cmdr::call glue cmd_take]

	private report {
	    description {
		Query/change the email address to send reports to.
	    }
	    input mail {
		Address to send report emails to.
		An empty address disables reporting.
	    } { optional ; validate cmdr::validate::str }
	} [m::cmdr::call glue cmd_report]

	private window {
	    description {
		Query/change the size of the window for the moving
		average of time spent on updates of a repository.
	    }
	    input window {
		New size of the window
	    } { optional ; validate cmdr::validate::posint }
	} [m::cmdr::call glue cmd_window]

	private limit {
	    description {
		Query/change default limit for repository listing.
	    }
	    input limit {
		New number of repositories to show by list and rewind.
		"auto" by default, adjusting itself to the terminal height.
	    } { optional ; validate [m::cmdr::vt limit] }
	} [m::cmdr::call glue cmd_limit]

	private block {
	    description {
		Query/change default threshold for automatic lockout of phantoms
		which fail to complete
	    }
	    input threshold {
		Number of times a phantom has to fail to complete to be blocked.
		This means that the next time the phantom is created again it will be
		immediately put into a state where the system will not even try to
		complete it anymore (disabled and private).
	    } { optional ; validate cmdr::validate::posint }
	} [m::cmdr::call glue cmd_block]
    }

    # # ## ### ##### ######## ############# ######################
    common .cms {
	section Content
    }
    common .cms.in {
	section Content Inspection
    }
    common .cms.nav {
	section Content Navigation
    }
    common .cms.ex {
	section Content Exchange
    }

    private vcs {
	use .cms.in
	description {
	    List supported version control systems
	}
    } [m::cmdr::call glue cmd_vcs]

    private details {
	use .cms.in
	description {
	    Show details of the specified repository, or current.
	}
	use .optional-repository
	option full {
	    Show the recorded logs, not just their length
	} { presence }
    } [m::cmdr::call glue cmd_details]

    private disable {
	use .cms
	description {
	    Disable the specified repositories, or current.
	}
	use .list-optional-repository
    } [m::cmdr::call glue cmd_enable 0]

    private enable {
	use .cms
	description {
	    Enable the specified repositories, or current.
	}
	use .list-optional-repository
    } [m::cmdr::call glue cmd_enable 1]

    private track {
	use .cms
	description {
	    Enable fork tracking for the specified repositories, or current.
	}
	use .list-optional-repository
    } [m::cmdr::call glue cmd_track 1]

    private untrack {
	use .cms
	description {
	    Disable fork tracking for the specified repositories, or current.
	}
	use .list-optional-repository
    } [m::cmdr::call glue cmd_track 0]

    private hide {
	use .cms
	description {
	    Mark the specified repositories, or current as private.
	}
	use .list-optional-repository
    } [m::cmdr::call glue cmd_private 1]

    private publish {
	use .cms
	description {
	    Mark the specified repositories, or current, as public.
	}
	use .list-optional-repository
    } [m::cmdr::call glue cmd_private 0]

    private remove {
	use .cms
	description {
	    Removes specified repository, or current.
	}
	use .list-optional-repository
    } [m::cmdr::call glue cmd_remove]

    private archive {
	use .cms
	description {
	    Archive the specified repositories into the given destination directory. If no
	    repositories are specified archive the current repository.
	}
	state mode {
	    Mode chosen by --remove, --phantom
	} { default keep }
	option remove {
	    Remove the repositories after their stores are archived.
	    Remove any store left without a using repository.
	} { alias R ; presence ; when-set [touch @mode remove] }
	option phantom {
	    Remove the referenced stores and leave the repositories as phantoms.
	} { undocumented ; alias P ; presence ; when-set [touch @mode phantom] }
	input destination {
	    Destination directory for the archived stores.
	    Created if it does not exist.
	} { validate cmdr::validate::rwdirectory }
	use .list-optional-repository
    } [m::cmdr::call glue cmd_archive]

    private add {
	use .cms
	description {
	    Add repository. The new repository is placed into its own project. The command
	    tries to auto-detect vcs type if not specified. The command derives a name
	    from the url if not specified. The new repository becomes current.
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
	} { validate [m::cmdr::vt url] }
	option name {
	    Name for the project to hold the repository.
	} {
	    alias N
	    validate str
	    generate [m::cmdr::call glue gen_name]
	}
	option extend {
	    Repository whose store the new repository has to use.
	} {
	    alias E
	    validate [m::cmdr::vt repository]
	    default {} ;# prevent rolodex top
	}
    } [m::cmdr::call glue cmd_add]

    private rename {
	use .cms
	description {
	    Change the name of the specified project, or
	    the project containing the current repository.

	    The rolodex does not change.

	    The change is rejected if the new name exists as a project.
	    Except if option --merge is provided. In that case the
	    repositories of the source project are bulk moved into the
	    destination, and the source project removed.
	}
	use .optional-project
	input name {
	    New name for the project.
	} { validate str }
	option merge {
	    Merge the source project into the destination.
	} { alias M ; presence }
    } [m::cmdr::call glue cmd_rename]

    private move {
	use .cms
	description {
	    Move the specified repositories to the named project.
	    If no repository is specified the current repository is moved.
	    If the project does not exist it is created.

	    The rolodex does not change.
	}
	input name {
	    Name of the destination project.
	} { validate str }
	use .list-optional-repository
    } [m::cmdr::call glue cmd_move]

    private merge {
	use .cms
	description {
	    Merges the specified repositories into a single store.
	    When only one repository is specified the current
	    repository is used as the merge target. When no
	    repositories are specified at all the current and previous
	    repositories are merged, using current as merge target

	    The rolodex does not change.
	}
	use .list-optional-repository
    } [m::cmdr::call glue cmd_merge]

    private split {
	use .cms
	description {
	    Split the store of the specified or current repository
	    from any other repositories it currently shares the store
	    with.

	    The referenced repository becomes current.

	    If the referenced repository does not share its store
	    already then nothing is done.
	}
	use .optional-repository
    } [m::cmdr::call glue cmd_split]

    private current {
	use .cms.nav
	description {
	    Shows the rolodex.
	}
    } [m::cmdr::call glue cmd_current]
    alias @

    private export {
	use .cms.ex
	description {
	    Write the known set of repositories and projects to
	    stdout, in a form suitable for (re)import.
	}
    } [m::cmdr::call glue cmd_export]

    private import {
	use .cms.ex
	description {
	    Read a set of repositories and projects from the
	    specified file, or stdin, and add them here.

	    Processes the format generated by export.
	    Ignores known repositories.
	    Ignores projects with no repositories (or just ignored repositories).

	    Makes projects on name conflicts.
	}
	option dated {
	    Add datestamp to the generated projects.
	} { presence }
	input spec {
	    Path to the file to read the import specification from.
	    Falls back to stdin when no file is specified.
	} { optional ; validate rchan ; default stdin }

    } [m::cmdr::call glue cmd_import]

    private set-current {
	use .cms.nav
	description {
	    Makes the specified repository current.
	}
	use .repository
    } [m::cmdr::call glue cmd_set_current]
    alias =>
    alias go

    private swap {
	use .cms.nav
	description {
	    Swap current and previous repository
	}
    } [m::cmdr::call glue cmd_swap_current]

    private update {
	use .cms
	description {
	    Runs an update cycle on the specified repositories. When no
	    repositories are specified use the next `take` number of
	    repositories from the list of pending repositories. If no
	    repositories are pending refill the list with the entire
	    set of repositories and then take from the list.
	}
	use .list-optional-repository
    } [m::cmdr::call glue cmd_update]

    private updates {
	use .cms.in
	description {
	    Show compressed history of past updates.
	    Sorted by last changed, updated, created.
	    Empty lines between update cycles
	}
    } [m::cmdr::call glue cmd_updates]

    private pending {
	use .cms.in
	description {
	    Show list of currently pending repositories. I.e repositories
	    waiting for an update.  Order shown is the order they are taken,
	    from the top down.
	}
    } [m::cmdr::call glue cmd_pending]

    private list {
	use .cms.nav
	description {
	    Show (partial) list of the known repositories.
	}
	option offset {
	    Number of entries to skip before starting display.
	    Advanced option. Normally managed automatically.
	} {
	    alias O
	    validate cmdr::validate::posint
	}
	option limit {
	    Number of repositories to show.
	    Defaults to the `limit`.
	} {
	    alias L
	    validate [m::cmdr::vt limit]
	    generate [m::cmdr::call glue gen_limit]
	}

	# constraint options - repository usage status

	option disabled {
	    Limit output to disabled repositories
	} {  alias D ; presence ; when-set [touch @use disabled] }
	option active {
	    Limit output to active repositories
	} { alias A ; presence ; when-set [touch @use active] }
	option any-use {
	    Clear limit on repository usage (--active, --disabled)
	} { presence ; when-set [touch @use {}] }
	state use {
	    Constraint chosen by --disabled, --active, --any-use
	} { default {} }

	# constraint options - repository fork status

	option primary {
	    Limit output to primary repositories
	} {  alias D ; presence ; when-set [touch @fork primary] }
	option forks {
	    Limit output to forks of primary repositories
	} { alias A ; presence ; when-set [touch @fork fork] }
	option any-origin {
	    Clear limit on repository fork status (--primary, --fork)
	} { presence ; when-set [touch @fork {}] }
	state fork {
	    Constraint chosen by --primary, --forks, --any-
	} { default {} }

	# constraint options - repository visibility

	option private {
	    Limit output to private repositories. These are hidden from the generated web site.
	} { alias P ; alias hidden ; presence ; when-set [touch @visibility private] }
	option public {
	    Limit output to public repositories. These are visible on the generated web site.
	} { alias p ; alias visible ; alias hidden ; presence ; when-set [touch @visibility public] }
	option any-visibility {
	    Clear limit on repository visibility (--private, --public)
	} { presence ; when-set [touch @visibility {}] }
	state visibility {
	    Constraint chosen by --public, --private, --any-visibility
	} { default {} }

	# constraint options - repository trouble status

	option issues {
	    Limit output to repositories with issues
	} { alias I ; presence ; when-set [touch @troubled yes] }
	option no-issues {
	    Limit output to repositories without issues
	} { presence; when-set [touch @troubled no] }
	option dont-care {
	    Clear limit on repository troubles (--issues, --no-issues)
	} { presence ; when-set [touch @visibility {}] }
	state troubled {
	    Constraint chosen by --issues, --no-issues, --dont-care
	} { default {} }

	# constraint options - store presence

	option phantoms {
	    Limit output to repositories without a store
	} { alias G ; presence ; when-set [touch @phantom yes] }
	option no-phantoms {
	    Limit output to repositories with a store
	} { presence ; when-set [touch @phantom no] }
	option any-store {
	    Clear limit on repository storage status
	} { presence ; when-set [touch @phantom {}] }
	state phantom {
	    Constraint chosen by --phantoms, --no-phantoms, --any-store
	} { default {} }

	# constraint options - repository vcs

	option vcs {
	    Limit output to the named VCS
	} { validate [m::cmdr::vt vcs] }

	# ordering options

	option by-name {
	    Order result by project name, url, vcs, and size (default)
	} {  alias N ; presence ; when-set [touch @ordering name] }
	option by-forks {
	    Order result by fork number, project name, url, vcs, and size
	} {  alias F ; presence ; when-set [touch @ordering nforks] }
	option by-url {
	    Order result by url, project name, vcs, and size
	} {  alias N ; presence ; when-set [touch @ordering url] }
	option by-vcs {
	    Order result by vcs, project name, url, and size
	} {  alias V ; presence ; when-set [touch @ordering vcs] }
	option by-size {
	    Order result by size, project name, url, and vcs
	} {  alias S ; presence ; when-set [touch @ordering size] }
	state ordering {
	    Constraint chosen by --by-name, --by-url, --by-vcs, --by-size, --by-fork
	} { default name }

	option up {
	    Return results in increasing order (default)
	} { presence ; when-set [touch @orderdir up] }
	option down {
	    Return results in decreasing order.
	} {  presence ; when-set [touch @orderdir down] }
	state orderdir {
	    Order direction
	} { default up }

	# constraint options - substring search

	input pattern {
	    When specified, search for repositories matching the pattern.  This is a
	    case-insensitive substring search on repository urls and project names.  When
	    multiple patterns are specified all of them have to match (and, intersection).
	    Cursor and rolodex are managed as normal.
	} { list ; optional ; validate str }
    } [m::cmdr::call glue cmd_list]

    private reset {
	use .cms.nav
	description {
	    Reset list state to first entry.
	}
    } [m::cmdr::call glue cmd_reset]

    private rewind {
	use .cms.nav
	description {
	    Like list, going backward through the set of repositories.
	}
    } [m::cmdr::call glue cmd_rewind]

    private projects {
	use .cms.in
	description {
	    Show (partial) list of the known projects.
	}

	option offset {
	    Number of entries to skip before starting display.
	    Advanced option. Normally managed automatically.
	} {
	    alias O
	    validate cmdr::validate::posint
	}
	option limit {
	    Number of projects to show.
	    Defaults to the `limit`.
	} {
	    alias L
	    validate [m::cmdr::vt limit]
	    generate [m::cmdr::call glue gen_limit]
	}

	# ordering options
	option by-name {
	    Order result by name, #repos, and #stores
	} {  alias N ; presence ; when-set [touch @ordering name] }
	option by-repos {
	    Order result by #repos, name, and #stores
	} {  alias R ; presence ; when-set [touch @ordering nrepos] }
	option by-stores {
	    Order result by #stores, name, and #repos
	} {  alias S ; presence ; when-set [touch @ordering nstores] }
	state ordering {
	    Constraint chosen by --by-name, --by-repos, --by-stores
	} { default name }

	input pattern {
	    When specified, search for projects matching the
	    pattern.  This is a case-insensitive substring search on
	    project names. For search on repository urls use `list` instead.
	} { optional ; validate str }
    } [m::cmdr::call glue cmd_projects]

    private project {
	use .cms.in
	description {
	    Show details of the specified project, or the project
	    containing the current repository.
	}
	use .optional-project
    } [m::cmdr::call glue cmd_project]

    private statistics {
	use .cms.in
	option blocks {
	    Show the url block list.
	} { presence }
	description {
	    Show system statistics.
	}
    } [m::cmdr::call glue cmd_statistics]

    # # ## ### ##### ######## ############# ######################

    officer submission {
	description {
	    Management of submissions, that is repositories
	    proposed for mirroring.
	}
	common .cms.sub {
	    section Submissions
	}
	common .cms.sub.in {
	    section Submissions Inspection
	}

	private list {
	    use .cms.sub.in
	    description {
		List the submissions waiting for moderation.  Submissions
		are shown with a shorthand id for easier reference by accept
		or reject.
	    }
	} [m::cmdr::call glue cmd_submissions]

	private enter {
	    use .cms.sub
	    description {
		Manual submission of url to moderate.
	    }
	    input url       {Url to track}    { validate [m::cmdr::vt url] }
	    input email     {Submitter, mail} { validate str }
	    input submitter {Submitter, name} { optional ; validate str }
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
	    option name {
		Name for the future project to hold the submitted repository.
	    } {
		alias N
		validate str
		generate [m::cmdr::call glue gen_name]
	    }
	} [m::cmdr::call glue cmd_submit]

	private accept {
	    use .cms.sub
	    description {
		Accept the specified submissions.
		Executes `add`, with all that entails.
		Sends mail to the specified email addresses to notify them
		of the acceptance.
	    }
	    input id {
		Submission to accept
	    } { validate [m::cmdr::vt submission] }
	    option vcs {
		Version control system handling the repository.
		Override the vcs from the submission.
	    } {
		alias V
		validate [m::cmdr::vt vcs]
		generate [m::cmdr::call glue gen_submit_vcs]
	    }
	    option nomail {
		Disable generation and sending of acceptance mail.
	    } { presence }
	    state vcs-code {
		Version control system handling the repository.
		Internal code, derived from the option value (database id).
	    } {
		generate [m::cmdr::call glue gen_vcs_code]
	    }
	    option url {
		Location of the repository.
		Overrides the url from the submission.
	    } {
		alias U
		validate str
		generate [m::cmdr::call glue gen_submit_url]
	    }
	    option name {
		Name for the project to hold the repository.
		Overrides the name from the submission.
	    } {
		alias N
		validate str
		generate [m::cmdr::call glue gen_submit_name]
	    }
	} [m::cmdr::call glue cmd_accept]

	private reject {
	    use .cms.sub
	    description {
		Reject the specified submissions.
		Do (not) send mail as directed by the cause.
		No need to give your mail address to spammers.
		Sending mail can be forced
	    }
	    option mail {
		Trigger generation and sending of rejection mail
	    } { alias M }
	    option cause {
		Cause of rejection
	    } { alias C ; validate [m::cmdr::vt reply]
		generate [m::cmdr::call validate::reply default]
	    }
	    input id {
		Submissions to reject
	    } { list ; validate [m::cmdr::vt submission] }
	} [m::cmdr::call glue cmd_reject]
	alias decline

	private drop {
	    use .cms.sub
	    description {
		Remove the specified urls from the table of rejections.
	    }
	    input rejections {
		Rejections to drop
	    } { list ; validate [m::cmdr::vt rejection] }
	} [m::cmdr::call glue cmd_drop]

	private rejected {
	    use .cms.sub.in
	    description {
		Show the table of rejected submissions, with associated
		reasons.
	    }
	} [m::cmdr::call glue cmd_rejected]
	alias declined
    }
    alias submissions = submission list
    alias rejections  = submission rejected
    alias submit      = submission enter

    # # ## ### ##### ######## ############# ######################

    officer site {
	description {
	    Access to the site configuration, and site management
	}

	common .site {
	    section Website
	}

	private show {
	    description {
		Show the entire site configuration (default).
	    }
	    section Website Configuration
	} [m::cmdr::call glue cmd_siteconfig_show]
	default

	foreach {cmd k v d} {
	    location      site-store         rwpath {location of web site}
	    mail          site-mgr-mail      str    {mail address of site manager}
	    manager       site-mgr-name      str    {name of site manager}
	    title         site-title         str    {title of site itself}
	    url           site-url           str    {publication url of site}
	    logo          site-logo          str    {path or url to site logo image}
	    related-url   site-related-url   str    {url of related site}
	    related-label site-related-label str    {label of related site}
	} {
     	    private $cmd [string map [list V $v K $k D $d] {
		section Website Configuration
		description { Set or query D }
		input value { The D } { optional ; validate V }
	    }] [m::cmdr::call glue cmd_siteconfig $k $d]
	}

	private make {
	    use .site
	    description {
		(Re)Generate site. This actions fails if the site configuration is
		incomplete. On success it performs a full (re)build of the site.
	    }
	    option silent {
		Reduce verbosity of the generation process.
	    } { presence }
	} [m::cmdr::call glue cmd_site_make 0]

	private on {
	    use .site
	    description {
		Like `make` it (re)generates the site. This actions fails if the site
		configuration is incomplete. On success it performs a full (re)build of
		the site. Beyond make it also activates automatic site generation after
		many operations on projects and repositories.
	    }
	    option silent {
		Reduce verbosity of the generation process.
	    } { presence }
	} [m::cmdr::call glue cmd_site_make 1]

	private off {
	    use .site
	    description {
		Disable automatic site generation and update
	    }
	} [m::cmdr::call glue cmd_site_off]

	private sync {
	    use .site
	    description {
		Sync main and site databases
	    }
	} [m::cmdr::call glue cmd_site_sync]

	# TODO: change description
	# TODO: change vcs
    }

    # # ## ### ##### ######## ############# ######################

    officer mail {
	description {
	    Access to the mail configuration
	}

	private show {
	    description {
		Show the entire mail configuration (default).
	    }
	    section Submissions Mail Configuration
	} [m::cmdr::call glue cmd_mailconfig_show]
	default

	foreach {k v d} {
	    host   str                    {name of mail relay host}
	    port   cmdr::validate::posint {port for SMTP on the mail relay host}
	    user   str                    {account on the mail relay host}
	    pass   str                    {credentials for the mail account}
	    tls    boolean                {TLS use to secure SMTP}
	    debug  boolean                {SMTP narrative tracing}
	    sender str                    {nominal sender of all mail}
	    header str                    {header text placed before generated content}
	    footer str                    {footer text placed after generated content}
	    width  cmdr::validate::posint {width of tables placed into generated content}
	} {
     	    private $k [string map [list V $v K $k D $d] {
		description { Set or query D }
		section Submissions Mail Configuration
		input value { The D } { optional ; validate V }
	    }] [m::cmdr::call glue cmd_mailconfig mail-$k $d]
	}

	officer reply {
	    description {
		Manage the templates used in mail replies.
		This is all about the different reasons for
		rejecting a submission.
	    }

	    common *all* -extend {
		section Submissions Mail Responses
	    }

	    common .reply {
		input reply {
		    The reply template to work with.
		} { validate [m::cmdr::vt reply] }
	    }

	    common .notreply {
		input reply {
		    The name for a not-yet-known reply template.
		} { validate [m::cmdr::vt notreply] }
	    }
	    common .text {
		input text {
		    The text of the template
		} { validate str }
	    }

	    private list {
		description {
		    Show the known reply templates.
		}
	    } [m::cmdr::call glue cmd_reply_show]

	    private add {
		description {
		    Add a new reply template.
		    By default the template will not
		    cause mail to be sent.
		}
		option auto-mail {
		    Automatically send mail when this
		    reply is used.
		} { presence ; alias M }
		use .notreply
		use .text
	    } [m::cmdr::call glue cmd_reply_add]

	    private remove {
		description {
		    Remove a known template.
		}
		use .reply
	    } [m::cmdr::call glue cmd_reply_remove]

	    private change {
		description {
		    Change the text for known reply template
		}
		use .reply
		use .text
	    } [m::cmdr::call glue cmd_reply_change]

	    private default {
		description {
		    Make reply the default
		}
		use .reply
	    } [m::cmdr::call glue cmd_reply_default]
	}
	alias replies = reply list
    }

    # # ## ### ##### ######## ############# ######################
    ## Developer support, debugging.

    officer chirurgy {
	description {
	    Advanced commands for low-level operations on the database, without belts,
	    suspenders, or any other kind of safety in place. Use at own risk. Make
	    backups before use.
	}
	common *all* -extend {
	    section Advanced Chirurgy
	}

	private vcs {
	    description {
		Change the VCS linked to a repository. This breaks the system if
		chosen VCS and store do not match. github to git are safe.
		git to github *only* if the repository is indeed on github.
		For anything else `archive --phantom` the store before making the
		change, so that the system operates on a clear state.
	    }
	    input vcs {
		The new version control system to handle the repository.
	    } {
		validate [m::cmdr::vt vcs]
	    }
	    use .list-optional-repository
	} [m::cmdr::call glue cmd_hack_vcs]
    }

    officer debug {
	description {
	    Various commands to help debugging the system itself
	    and its configuration.
	}
	common *all* -extend {
	    section Advanced Debugging
	}

	private url-ok {
	    description {
		Test if url is ok to mirror.
	    }
	    input url {
		The urls to check
	    } { list ; validate str }
	} [m::cmdr::call glue cmd_test_url_ok]

	private colors {
	    description {
		Show a table of the available text colors
	    }
	} [m::cmdr::call glue cmd_test_colors]

	private cycle-mail {
	    description {
		Show the mail which would be generated if the update
		cycle turned around now.
	    }
	    option mail {
		Actually send the mail. Use the configured destination,
		if not overridden by --destination.
	    } { alias M ; presence }
	    option destination {
		The destination address to send the mail to.
	    } { alias D
		generate [m::cmdr::call glue gen_report_destination]
	    }
	} [m::cmdr::call glue cmd_test_cycle_mail]

	private mail-setup {
	    description {
		Generate a test mail and send it using the current
		mail configuration.
	    }
	    input destination {
		The destination address to send the test mail to.
	    } { }
	} [m::cmdr::call glue cmd_test_mail_config]

	private test-vt-repo {
	    description {
		Show the knowledge map used by the repository validator.
	    }
	} [m::cmdr::call glue cmd_test_vt_repository]

	private test-vt-project {
	    description {
		Show the knowledge map used by the project validator.
	    }
	} [m::cmdr::call glue cmd_test_vt_project]

	private test-vt-submission {
	    description {
		Show the knowledge map used by the submission validator.
	    }
	} [m::cmdr::call glue cmd_test_vt_submission]

	private test-vt-reply {
	    description {
		Show the knowledge map used by the reply validator.
	    }
	} [m::cmdr::call glue cmd_test_vt_reply]

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
