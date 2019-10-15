# V2 - Mirroring. Backing up Sources

Streamlined v1 to basics.

   - Removed VCS operation hooks.
     VCS support is coded fixed, no plugin system.

   - Removed tags. Not needed for an initial setup.

## Entities

   1. Repository.
      Examples:

      - https://core.tcl-lang.org/akupries/marpa/
      - github@github:andreas.kupries/marpa
      -	https://chiselapp.com/user/andreas-kupries/repository/marpa/

      A versioned collection of files.

   1. Mirror Set.
      Example:

      - First item.

      A group of repositories holding the same versioned collection of
      files.

   1. Version Control System (VCS).
      Examples:
      - git
      - fossil
      - bazaar
      - mercurial
      - monotone
      - svn
      - cvs
      - rcs
      - sccs

      An application (or collection thereof) to manage a repository.

   1. Store

      A repository, internal to the mirroring system. Each kind of VCS
      used by a sub-set of the repositories in a mirror set has an
      associated store, to hold the local mirror of the repositories
      in question.

   1. Name

      The name of a mirror set. This is an 1:1 relation.

      It is separate from the mirror set because this is also the hook
      where we can replace the link to the name with a link into a Tcl
      Package Pedia containing much more information.

## Entity Relations

```
Repository	has-a|is-managed-by-a	Version Control System
		n:1

Repository	belongs-to-a		Mirror Set
		n:1

Mirror Set	has-a			Name
		1:1

Store		has-a|is-managed-by-a	Version Control System
		n:1

Store		belongs-to-a		Mirror Set
		n:1
```

As a diagram

```
 Mset Pending ----\		     /-> Name
		   \-> /--> Mirror Set <--------------\
 Rolodex --> Repository				       Store <-- Store Times
		       \--> Version Control System <--/

```

## Entities & Attributes

### version_control_system

|Name	|Type	|Modifiers	|Comments	|
|---	|---	|---		|---		|
|id	|int	|PK		|		|
|code	|text	|unique		|Short tag	|
|name	|text	|unique		|Human Readable	|

### name

|Name	|Type	|Modifiers	|Comments	|
|---	|---	|---		|---		|
|id	|int	|PK		|		|
|name	|text	|unique		|		|

### mirror_set

|Name	|Type	|Modifiers	|Comments	|
|---	|---	|---		|---		|
|id	|int	|PK		|		|
|name	|int	|unique, FK name|1:1		|

### mset_pending

|Name	|Type	|Modifiers		|Comments	|
|---	|---	|---			|---		|
|id	|int	|PK, FK mirror_set	|		|

### repository

|Name	|Type	|Modifiers			|Comments	|
|---	|---	|---				|---		|
|id	|int	|PK				|		|
|url	|text	|unique				|Location	|
|vcs	|int	|FK version_control_system	| __index 1__	|
|mset	|int	|FK mirror_set			| __index 1__	|
|active	|bool	|				|		|

### rolodex

|Name		|Type	|Modifiers		|Comments	|
|---		|---	|---			|---		|
|id		|int	|PK			|		|
|repository	|int	|unique, FK repository	|		|

### store

|Name		|Type	|Modifiers			|Comments			|
|---		|---	|---				|---				|
|id		|int	|PK				|				|
|path		|text	|unique				|Relative to `state('store')`	|
|vcs		|int	|FK version_control_system	| __index 1__			|
|mset		|int	|FK mirror_set			| __index 1__			|
|size_kb	|int	|				|				|
|size_previous	|int	|				|				|
|commits_current|int	|				|				|
|commit_previous|int	|				|				|

### store_times

|Name		|Type	|Modifiers	|Comments			|
|---		|---	|---		|---				|
|store		|int	|PK, FK store	|				|
|created	|int	|		|epoch				|
|updated	|int	|		|epoch				|
|changed	|int	|		|epoch				|
|attend		|bool	|		|flag for issues		|
|min_seconds	|int	|		|min duration of updates	|
|max_seconds	|int	|		|max duration of update		|
|window_seconds	|text	|		|CSV line for durations		|

## Entities & Attributes around submission handling

### submission

|Name		|Type	|Modifiers	|Comments			|
|---		|---	|---		|---				|
|id		|int	|PK		|				|
|session	|text	|unique (+url)	|int. code for session ident	|
|url		|text	|unique (+sess)	|__index 1__, location		|
|vcode		|text	|nullable	|vcs				|
|description	|text	|nullable	|				|
|email		|text	|		|submitter email		|
|submitter	|text	|nullable	|				|
|sdate		|int	|		|__index 2__, epoch		|

### submission_handled

|Name	|Type	|Modifiers	|Comments	|
|---	|---	|---		|---		|
|session|text	|unique (+url)	|		|
|url	|text	|unique (+sess)	|		|

### rejected

|Name	|Type	|Modifiers	|Comments	|
|---	|---	|---		|---		|
|id	|int	|PK		|		|
|url	|text	|unique		|		|
|reason	|text	|		|		|

### reply

|Name		|Type	|Modifiers	|Comments			|
|---		|---	|---		|---				|
|id		|int	|PK		|				|
|name		|text	|unique		|				|
|automail	|bool	|		|Send mail by default when used	|
|isdefault	|bool	|		|Use this when no reason spec'd	|
|text		|text	|		|				|

## Entities & Attributes for Internal Management

### schema

|Name	|Type	|Modifiers	|Comments		|
|---	|---	|---		|---			|
|key	|text	|PK		|always 'version'	|
|version|int	|		|version number		|

### state

|Name	|Type	|Modifiers	|Comments		|
|---	|---	|---		|---			|
|name	|text	|PK		|			|
|value	|text	|		|			|

Known keys

|Key				|Meaning				|
|---				|---					|
|limit				|State, #repos per `list` page		|
|start-of-current-cycle		|State, epoch when update cycle started	|
|start-of-previous-cycle	|State, epoch, previous update cycle	|
|store				|State, path to stores on disk		|
|store-window-size		|State, #of update durations to retain	|
|take				|State, #mirror sets to update per run	|
|top				|State, repo shown at top of `list`	|
|~				|~					|
|mail-debug			|Mail transport, debug flag		|
|mail-host			|Mail transport, smtpd host		|
|mail-pass			|Mail transport, smtp password		|
|mail-port			|Mail transport, smtpd port		|
|mail-sender			|Mail transport, smtp sender		|
|mail-tls			|Mail transport, tls flag		|
|mail-user			|Mail transport, smtp user		|
|~				|~					|
|mail-width			|Mail config, table width limit		|
|mail-footer			|Mail config, footer text		|
|mail-header			|Mail config, header text		|
|report-mail-destination	|Mail config, destination		|
|~				|~					|
|site-active			|Site config, flag of use		|
|site-logo			|Site config, url to logo		|
|site-mgr-mail			|Site config, email of manager		|
|site-mgr-name			|Site config, name of manager		|
|site-store			|Site config, path to site on disk	|
|site-title			|Site config, general title		|
|site-url			|Site config, url of site		|
