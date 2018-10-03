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
  		own mirror set. The command tries to auto-detect the
  		vcs managing the url if not specified. The command
  		derives a name for the mirror set from the url if not
  		specified. The new repository becomes current.

	remove ?repository?

	       Removes specified repository, or current. Previous
	       becomes current again.

	       Removing the last repository of a mirror set removes
	       the mirror set.

	       Removing the last repository for a specific vcs in the
	       mirror set removes the store for that vcs.

	rename ?repository? <name>

	       Change the name of the mirror set containing the
	       specified or current repository. The repository becomes
	       current. Existing stores attached the mirror set are
	       renamed to match.

	merge ?repository...?

	       Merges the mirror sets of the specified repositories
	       into a single mirror set. The first repository is the
	       merge target. If only a single repository is specified
	       the current repository is used the merge target, and
	       the specified is merged in. If no repository is
	       specified the current repository is the merge target,
	       and the previous is the repository to be merged in.

	       The merge target becomes current, and the last of the
	       merged repositories becomes previous.

	       If some of the repositories point to the same mirror
	       set the first specified repository for each mirror set
	       is considered the representative, in terms of becoming
	       current and previous.

	       If all repositories point to the same mirror set then
	       no merging takes place.

	       The name of the merge target is the name of the merge
	       result.

	split ?repository?

		Split the specified or current repository from its
		mirror set. Generates a new mirror set. Name derived
		from the original mirror set. The newly standalone
		repository becomes current. If the repository was
		standalone before the operation nothing is done.

	current
	@

		Show current and previous repository

	set-current <repository>
	go
	=>

		Makes specified repository current.

	update ?repository...?

	       Run an update cycle on the mirror sets associated with
	       the specified repositories. When none are specified
	       process `take` number of mirror sets from the list of
	       pending mirror sets. If no mirror sets are pending fill
	       the list with the entire set of mirror sets before
	       taking.

	list ?repository? ?n?

		Show a list of known repositories. The output is
		sorted lexicographically by mirror set (names), and
		urls in the mirror set.

	        If specified the listing starts from the specified
	        repository.

		Without repository the listing starts either from the
	        first repository per the sort order (s.a.), or from
	        the first repository just after the last repository
	        shown by the previous invokation of this command.

		Exception to that: If the last writer to the rolodex
		(see below) was `accept` then the rolodex is shown
		instead.

	        When the listing goes past the last possible
	        repository it is cut short at that repository, and
	        further resets the state to cause the command to start
	        the list at the first repository on the next
	        invokation.

		Note, this repository reference is separate from the
		current repository. The listing will contain ids which
		can be used in lieu of urls in all commands taking
		repository references.

		These ids are stored in the rolodex for use by the
		validation, and each invokation of `list` (and
		`rewind`) will update it. If the listing did not show
		the rolodex itself (see above) then any shorthands
		from previous invokations of `accept` are overwritten.

	        If specified the listing is limited to N entries.  If
	        not specified a default limit is applied.

	reset

		Reset the list state such that the next invokation of
		`list` wil lstart at the first repository.

	rewind

		Like `list`, going backward through the set of
		repositories.

	limit ?n?

		Query/change default limit for repository listing.

	submissions

		List the submissions waiting for moderation.
		Submissions are shown with a shorthand id for easier
		reference by accept or reject.

	accept <submission-id> ...

		Accept the specified submissions, with an implied
		`add`. Each will be placed into their own mirror
		set. The new repository will be entered into the
		rolodex, as if `list` had been invoked. (To make any
		upcoming merges easier).

		Note, multiple separate acceptances accumulate in the
		rolodex.

		Send mail to the email addresses specified in the
		submissions to notify them of the acceptance.

	reject ?-mail? <cause> <submission-id> ...

	       Reject the specified submissions. Does not send mail by
	       default. No need to give a valid mail address to
	       spammers.

	       Sending of mail can be forced, for example if the
	       rejection is due to reasons other than spam.
```
