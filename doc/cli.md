# V2 CLI interface

Streamlined v1 to basics.

   - Removed VCS operation hooks. VCS support is coded fixed, no
     plugin system.

   - Removed tags. Not needed for an initial setup.

## Command hierarchy

```
mirror
	store ?path?

		Query/change store path. Change implies copying all
	      	existing stores to the new location. Removes all
	      	pre-existing stores in the new location.

	take ?int?

		Query/change the number of mirror sets processed per
		update cycle.

	vcs
		List supported version control systems

	add ?--vcs vcs? <url> ?name?

		Add repository. The new repository is placed into its
  		own mirror set. Command tries to auto-detect vcs type
  		if not specified. Command derives a name from the url
  		if not specified New repository and mirror become
  		current.

	remove ?url?

	       Removes specified repository, or current. Previous
	       current becomes current.

	rename ?url? <name>

	       Change the name of the specified or current
	       repository. Specified repository becomes current.

	merge ?url? ?url?

	       Merges the specified repositories into a single mirror
	       set. When only one repository is specified the other is
	       the current repository. When no repository is specified
	       the two repositories merged are current and previous
	       current.

	       The user chooses the name of the merge.

	       The merge result becomes the current mirror set. The
	       two current repositories in the involved mirrors set
	       become current and previous for the merge result.

	split ?url?

		Split the specified or current url from its mirror
		set. Generates a new mirror set. Name derived from the
		original mirror set. The split url becomes current.


	current <url> 

		Makes specified repository current. Makes mirror set
		of repository current.

	update ?url...?

	       Run an update cycle on the mirror sets associated with
	       the specified urls. When none are specified process
	       `take` number of mirror sets from the list of pending
	       mirror sets. If no mirror sets are pending fill the
	       list with the entire set of mirror sets before taking.

	list ?url? ?n?

		Show list of known urls. Sorted lexicographically by
		mirror set (names), and urls in the mirror set.

	        If specified listing starts from the specified url.

		Without url the listing starts either from the first
	        entry, or after the last entry shown by the previous
	        invokation of this command.

		Exception to that: If the last writer to the
		shorthands (see below) was `accept` then the shorthand
		table is shown.

	        Listing past the end resets this to list from the
	        first entry on the next invokation.

		Note, this state is separate from the current mirror
		set and repository. The listing will contain shorthand
		ids which can be used in lieu of urls in all commands
		taking urls.

		If the listing did not show the shorthand table (see
		above) then any shorthands from previous `accept`s are
		overwritten.

	        If specified limited to N entries.  If not specified a
	        default limit is applied.

	reset

		Reset list state to first entry.

	rewind

		Like list, going backward through the set of
		repositories.

	limit ?n?

		Query/change default limit for repository listing.

	submissions

		List the submissions waiting for moderation.
		Submissions are shown with a shorthand id for easier
		reference by accept or reject.

	accept <submission-id> ...

		Accept the specified submissions. Each will placed
		into their own mirror set. The new repository will be
		entered into the table of shorthands, as if `list` had
		been invoked. (To any make upcoming merges easier).

		Note, multiple separate acceptances accumulate.

		Send mail to the specified email addresses to notify
		them of the acceptance.

	reject ?-mail? <cause> <submission-id> ...

	       Reject the specified submissions.
	       Do not send mail by default.
	       (No need to give my own mail address to spammers)

	       Mail can be forced, for example if the rejection is due
	       to reasons other than spam.

```
