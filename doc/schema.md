# V2 - Mirroring. Backing up Sources

Streamlined v1 to basics.

   - Removed VCS operation hooks. VCS support is coded fixed, no
     plugin system.

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
                    / <-- Repository --> \
Name <--> Mirror Set                      Version Control System
                    \ <-- Store      --> /
```

## Entity Attributes

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

### repository

|Name	|Type	|Modifiers	|Comments	|
|---	|---	|---		|---		|
|id	|int	|PK		|		|
|url	|text	|unique		|Location	|
|vcs	|int	|FK version_control_system	|	|
|mset	|int	|FK mirror_set	|		|

### store

|Name	|Type	|Modifiers	|Comments	|
|---	|---	|---		|---		|
|id	|int	|PK		|		|
|path	|text	|unique		|Relative to a base	|
|vcs	|int	|FK version_control_system	|	|
|mset	|int	|FK mirror_set	|		|

### version_control_system

|Name	|Type	|Modifiers	|Comments	|
|---	|---	|---		|---		|
|id	|int	|PK		|		|
|code	|text	|unique		|Short tag	|
|name	|text	|unique		|Human Readable	|
