# V3 - Mirroring. Backing up Sources

In planning, to address the [issues of V2](schema-v2-issues.md)

## Changes

  1. Renamed `mirror_set` to `project`.
  1. Renamed `mset_pending` to `repo_pending`.
  1. Moved `store_times.created` to `store`.
  1. Moved `store_times.updated` to `store`.
  1. Moved `store_times.changed` to `store`.
  1. Moved `store_times.attend` to `repository.has_issues`.
  1. Moved `store_times.min_seconds` to `repository.min_duration`.
  1. Moved `store_times.max_seconds` to `repository.max_duration`.
  1. Moved `store_times.window_seconds` to `repository`.
  1. Dropped table `store_times`.
  1. Dropped table `store_github_forks`.
  1. Redid the core relations.
  1. Made the fork handling explicit in the schema.
  1. Removed `store.mset`.
  1. Renamed `repository.mset` to `repository.project`.
  1. Added `repository.store`.
  1. Added `repository.checked`.

Redesign of the fork handling:

  1. A VCS driver may report forks on `setup` and `update` operations.

  1. The reported forks are automatically added to the project of the
     primary (aka fork_origin), as their own repositories, and activated.

     Unreported known forks are deactivated. __Not__ removed.

  1. Forks get their own store. While this blows up the disk space
     needed to handle the project it also makes handling much easier,
     as there is no need to fiddle with git(hub) tags and origins.

     If desired it is always possible to manually merge stores. Not
     recommended for git.

## Entities

### Overview

|Table                  |Description                                            |
|---                    |---                                                    |
|project                |Group of repositories, same logical project            |
|rejected               |Rejected repositories, for use by future submissions   |
|reply                  |Mail replies for submission handling                   |
|repo_pending           |Repositories waiting for update in current cycle       |
|repository             |A set of versioned files to back up                    |
|rolodex                |Shorthand repository references, recently seen         |
|state                  |Global system state and config                         |
|store                  |Local holder of a repository backup                    |
|submission             |Submitted repositories waiting for handling            |
|submission_handled     |Handled submissions for next sync with site database   |
|version_control_system |Information about supported VCS                        |

### Examples

|Entity                 |Example                                                        |
|---                    |---                                                            |
|Repository             |                                                               |
|                       |github@github:andreas.kupries/marpa                            |
|                       |https://chiselapp.com/user/andreas-kupries/repository/marpa    |
|                       |https://core.tcl-lang.org/akupries/marpa                       |
|Project                |                                                               |
|                       |Tcl Marpa                                                      |
|Version Control System |                                                               |
|                       |bazaar                                                         |
|                       |cvs                                                            |
|                       |fossil (__+__)                                                 |
|                       |git, github (__+__)                                            |
|                       |mercurial (hg) (__+__)                                         |
|                       |monotone                                                       |
|                       |rcs                                                            |
|                       |sccs                                                           |
|                       |svn (__+__)                                                    |

### Core Relations

  1. A `project` __has__ zero or more `repositories` (1:n).
  1. __(x)__ A `repository` __belongs to__ a single `project` (n:1).
  1. __(x)__ A `repository` __is managed by__ a single `version control system` (n:1).
  1. A `version control system` __manages__ zero or more `repositories` (1:n).
  1. __(x)__ A `repository` __has_ a single (backing) `store` (1:n).
  1. A `store` __contains the data__ of one or more __repositories (1:n).
  1. __(x)__ A `store` __is managed by__ a single `version control system` (n:1).
  1. A `version control system` __manages__ zero or more `stores` (1:n).
  1. __(x)__ A `repository` may __have__ a parent `repository` it is forked from (n:1).
  1. A `repository` __has__ zero or more forked `repositories` (1:n).

A checking contraint:

  1. A `repository` and its backing `store` are managed by the same `version control system`.

     IOW `repository.store.vcs == repository.vcs`.

Below we see the above as diagram, with the relations marked __(x)__
as the shown arrows / foreign key references, and some adjunct tables added.

```
rolodex ------>\
repo_pending -->\
     project <-- repository ------------------->\
                           \--> store ---------> version_control_system
```

### Entity Attributes

|Entity                 |Field                  |Type   |Modifiers              |Comments       |
|---                    |---                    |---    |---                    |---            |
|schema                 |                       |       |                       |               |
|                       |key                    |text   |PK                     |fix: `version` |
|                       |version                |int    |                       |               |
|~                      |~                      |~      |~                      |~              |
|__Main Database__      |                       |       |                       |               |
|~                      |~                      |~      |~                      |~              |
|project                |                       |       |                       |               |
|                       |id                     |int    |PK                     |               |
|                       |name                   |text   |unique                 |               |
|repo_pending           |                       |       |                       |               |
|                       |id                     |int    |PK, FK repository      |               |
|rejected               |                       |       |                       |               |
|                       |id                     |int    |PK                     |               |
|                       |url                    |text   |unique                 |               |
|                       |reason                 |text   |                       |               |
|reply                  |                       |       |                       |               |
|                       |id                     |int    |PK                     |               |
|                       |name                   |text   |unique                 |               |
|                       |automail               |bool   |       |Send mail by default           |
|                       |isdefault              |bool   |       |Use when no reason given       |
|                       |text                   |text   |                       |               |
|repository             |                       |       |                       |               |
|                       |id                     |int    |PK                     |               |
|                       |url                    |text   |unique                 |Location       |
|                       |project                |int    |FK project             | __index 1__   |
|                       |vcs                    |int    |FK version_control_... | __index 1__   |
|                       |store                  |int    |FK store               | __index 2__   |
|                       |fork_origin            |int    |FK repository, nullable| __index 3__   |
|                       |is_active              |bool   |                       |               |
|                       |has_issues             |bool   |                       |Has issues     |
|                       |min_duration           |int    |                       |               |
|                       |max_duration           |int    |                       |               |
|                       |window_duration        |text   |                       |CSV, last N    |
|                       |checked                |int    |                       |epoch          |
|rolodex                |                       |       |                       |               |
|                       |id                     |int    |PK                     |               |
|                       |repository             |int    |unique, FK repository  |               |
|state                  |                       |       |                       |               |
|                       |name                   |text   |PK                     |               |
|                       |value                  |text   |                       |               |
|store                  |                       |       |                       |               |
|                       |id                     |int    |PK                     |               |
|                       |vcs                    |int    |FK version_control_... |               |
|                       |size_kb                |int    |                       |Kilobyte       |
|                       |size_previous          |int    |                       |ditto          |
|                       |commits_current        |int    |                       |               |
|                       |commits_previous       |int    |                       |               |
|                       |created                |int    |                       |Epoch          |
|                       |updated                |int    |                       |Epoch          |
|                       |changed                |int    |                       |Epoch          |
|submission             |                       |       |                       |               |
|                       |id                     |int    |PK                     |               |
|                       |session                |text   | __unique 1__          |               |
|                       |url                    |text   | __unique 1__          | index 1       |
|                       |vcode                  |text   |nullable               | VCS.code      |
|                       |description            |text   |nullable               |               |
|                       |email                  |text   |                       |subm. email    |
|                       |submitter              |text   |nullable               |subm. name     |
|                       |sdate                  |int    |                       |epoch, index 2 |
|submission_handled     |                       |       |                       |               |
|                       |session                |text   | __unique 1__          |               |
|                       |url                    |text   | __unique 1__          |               |
|version_control_system |                       |       |                       |               |
|                       |id                     |int    |PK                     |               |
|                       |code                   |text   |unique                 |Short tag      |
|                       |name                   |text   |unique                 |Human Readable |
|~                      |~                      |~      |~                      |~              |
|__Site Database__      |                       |       |                       |               |
|~                      |~                      |~      |~                      |~              |
|cache_desc             |                       |       |                       |               |
|                       |expiry                 |int    |                       |epoch          |
|                       |url                    |text   |unique                 |               |
|                       |desc                   |text   |                       |               |
|cache_url              |                       |       |                       |               |
|                       |expiry                 |int    |                       |epoch          |
|                       |url                    |text   |unique                 |               |
|                       |ok                     |int    |                       |               |
|                       |resolved               |text   |                       |               |
|rejected               |                       |       |                       |               |
|                       |main.rejected          |       |                       |               |
|store_index            |                       |       |                       |               |
|                       |id                     |int    |PK                     |               |
|                       |name                   |text   | __unique 1__          |index 1        |
|                       |vcode                  |text   | __unique 1__          |               |
|                       |page                   |text   |                       |               |
|                       |remotes                |text   |                       |index 2        |
|                       |status                 |text   |                       |               |
|                       |size_kb                |int    |                       |               |
|                       |changed                |int    |                       |epoch          |
|                       |updated                |int    |                       |epoch          |
|                       |created                |int    |                       |epoch          |
|submission             |                       |       |                       |               |
|                       |main.submission        |       |                       |               |
|vcs                    |                       |       |                       |               |
|                       |main.version_control_system|   |                       |               |

## State keys and semantics

|Key                            |Meaning                                |
|---                            |---                                    |
|limit                          |State, #repos per `list` page          |
|start-of-current-cycle         |State, epoch when update cycle started |
|start-of-previous-cycle        |State, epoch, previous update cycle    |
|store                          |State, path to stores on disk          |
|store-window-size              |State, #of update durations to retain  |
|take                           |State, #repositories to update per run |
|top                            |State, repo shown at top of `list`     |
|~                              |~                                      |
|mail-debug                     |Mail transport, debug flag             |
|mail-host                      |Mail transport, smtpd host             |
|mail-pass                      |Mail transport, smtp password          |
|mail-port                      |Mail transport, smtpd port             |
|mail-sender                    |Mail transport, smtp sender            |
|mail-tls                       |Mail transport, tls flag               |
|mail-user                      |Mail transport, smtp user              |
|~                              |~                                      |
|mail-footer                    |Mail config, footer text               |
|mail-header                    |Mail config, header text               |
|mail-width                     |Mail config, table width limit         |
|report-mail-destination        |Mail config, destination               |
|~                              |~                                      |
|site-active                    |Site config, flag of use               |
|site-logo                      |Site config, url to logo               |
|site-mgr-mail                  |Site config, email of manager          |
|site-mgr-name                  |Site config, name of manager           |
|site-store                     |Site config, path to site on disk      |
|site-title                     |Site config, general title             |
|site-url                       |Site config, url of site               |
