
repository == remote

|Attribute	|Type	|Notes							|
|---		|---	|---							|
|url		|string	|External location					|
|store		|int	|Id of internal store					|
|active		|bool	|Indicator if remote in use				|
|check_pending	|bool	|Indicator if not yet checked in cycle			|
|check_active	|bool	|Indicator if check is running (bg job)			|
|attend		|bool	|Indicator if remote has issues to attend		|
|checked	|int	|Epoch of last check					|
|min_duration	|int	|Min duration (seconds) over all checks			|
|max_duration	|int	|Max duration (seconds) over all checks			|
|primary	|int	|Id of primary remote, set (only) for magic remotes	|

# Update behaviour

## Primary remote

### Success (setup, update)

Read current set of forks from operation log.
Add missing forks as magic remotes.
Remove magic remotes for unknown forks.
Reactivate inactive magic remotes.

### Failure

Flag for attend.

Note: Need a command to re-parent|elect-new-primary
      Query github to determine parent of a repo.

## Magic remote

### Success

Store is updated, nothing more.

### Failure

Flag for attend. Flag to inactive.
Will be removed on the next round of handling the primary.
Or reactivated if still/again found.

At store level peers for the magic remote are renamed / moved around
(Do not wish to lose the references)
