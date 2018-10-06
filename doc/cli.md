# V2 CLI interface

Streamlined v1 to basics.

   - Removed VCS operation hooks. VCS support is coded fixed, no
     plugin system.

   - Removed tags. Not needed for an initial setup.

## Command hierarchy

```
mirror
	store ?path?

		Query/change base store path. Change implies copying
	      	all existing stores to the new location. Removes all
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
  		specified. The new repository becomes top of rolodex
  		(i.e. current).

	remove ?repository?

	       Removes specified repository, or current. The
	       repository is removed from the rolodex as well.

	       Removing the last repository of a mirror set removes
	       the mirror set.

	       Removing the last repository for a specific vcs in the
	       mirror set removes the store for that vcs.

	rename ?repository? <name>

	       Change the name of the mirror set containing the
	       specified or current repository. The changed repository
	       becomes top of rolodex.

	merge ?repository...?

	       Merges the mirror sets of the specified repositories
	       into a single mirror set. The first repository is the
	       merge target. If only a single repository is specified
	       the current repository is used the merge target, and
	       the specified is merged in. If no repository is
	       specified the current repository is the merge target,
	       and the previous is the repository to be merged in.

	       The referenced repositories are all pushed to the
	       rolodex, from last to first. This makes the merge
	       target the new current repository, and the first of the
	       merge origins the previous.

	       If all repositories point to the same mirror set then
	       no merging takes place.

	       The name of the merge target is the name of the merge
	       result.

	split ?repository?

		Split the specified or current repository from its
		mirror set. Generates a new mirror set. Name derived
		from the original mirror set. The newly standalone
		repository becomes current. If the repository was
		standalone before the operation then nothing is done.

	current
	@

		Show the rolodex, with current at the bottom.

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

		Show a (partial) list of known repositories.

		The known repositories are sorted lexicographically by
		mirror set (names), and urls in the mirror set.

	        The listing starts from the specified repository, or
		from just after the last repository shown by the
		previous invokation of this command. If the previous
		invokation showed the last known repository the
		listing will (re)start with the first known
		repository.
		
		Per invokation at most `limit` repositories are shown,
		or, if specified `n`. 

		All repositories shown are added to the rolodex, with
		the bottom-most shown becoming the new top (current).

		The listing will show the assigned rolodex handles.

	reset

		Reset the list state such that the next invokation of
		`list` will start at the first repository.

	rewind

		Like `list`, going backward through the set of
		repositories instead.

	limit ?n?

		Query/change default limit for repository listing.
		This limit is also the size of the rolodex.  In other
		words, when the rolodex hits this limit the oldest
		entry is removed to keep it at the specified size.

	submissions

		List the submissions waiting for moderation.
		Submissions are shown with a shorthand id for easier
		reference by accept or reject.

	accept <submission-id> ...

		Accept the specified submissions. This comes with an
		implied `add`.

		Send mail to the email addresses specified in the
		submissions to notify them of the acceptance.

	reject ?-mail? <cause> <submission-id> ...

	       Reject the specified submissions. Does not send mail by
	       default. No need to give a valid mail address to
	       spammers.

	       Sending of mail can be forced, for example if the
	       rejection is due to reasons other than spam.
```
