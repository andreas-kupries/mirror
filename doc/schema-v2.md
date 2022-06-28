# V2 - Mirroring. Backing up Sources

As of 2019-10-03T21:20 (`lib/db/db.tcl`, `SETUP-201910032120` and all preceding).

Streamlined v1 to basics.

  - Removed VCS operation hooks.
    VCS support is fixed, no plugin system.
    Near-plugin system through extensible set of VCS specific packages

  - Removed tags. Not needed for an initial setup.

## Entities

### Overview

|Table                  |Description                                            |
|---                    |---                                                    |
|mirror_set             |Group of repositories, same logical project            |
|mset_pending           |Projects waiting for update in current cycle           |
|rejected               |Rejected repositories, for use by future submissions   |
|reply                  |Mail replies for submission handling                   |
|repository             |A set of versioned files to back up                    |
|rolodex                |Shorthand repository references, recently seen         |
|state                  |Global system state and config                         |
|store                  |Local holder of a repository backup                    |
|store_github_forks     |Number of forks per github store                       |
|store_times            |Cycle information per store                            |
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
|Mirror Set             |                                                               |
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

  1. A `repository` __is managed by a__ `version control system` (n:1)
  1. A `repository` __belongs to a__ `mirror set` (n:1)
  1. A `store` __is managed by a__ `version control system` (n:1)
  1. A `store` __belongs to a__ `mirror set` (n:1)
  1. A `repository` __has a_ (backing) `store` (1:n)

The above as a diagram, with some of the adjunct tables added, and the last relation __not__ shown.

```
 Mset Pending ----\
                   \-> /--> Mirror Set <--------------\
 Rolodex --> Repository                                Store <-- Store Times
                       \--> Version Control System <--/    \ <-- Store Github Forks

```

### Entity Attributes

|Entity                 |Field                  |Type   |Modifiers              |Comments       |
|---                    |---                    |---    |---                    |---            |
|schema                 |                       |       |                       |               |
|                       |key                    |text   |PK                     |fix: `version` |
|                       |version                |int    |                       |               |
|~                      |~                      |~      |~                      |~              |
|mirror_set             |                       |       |                       |               |
|                       |id                     |int    |PK                     |               |
|                       |name                   |text   |unique                 |               |
|mset_pending           |                       |       |                       |               |
|                       |id                     |int    |PK, FK mirror_set      |               |
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
|                       |url                    |text   |unique                 |Loction        |
|                       |vcs                    |int    |FK version_control_... | __index 1__   |
|                       |mset                   |int    |FK mirror_set          | __index 1__   |
|                       |active                 |bool   |                       |               |
|rolodex                |                       |       |                       |               |
|                       |id                     |int    |PK                     |               |
|                       |repository             |int    |unique, FK repository  |               |
|state                  |                       |       |                       |               |
|                       |name                   |text   |PK                     |               |
|                       |value                  |text   |                       |               |
|store                  |                       |       |                       |               |
|                       |id                     |int    |PK                     |               |
|                       |vcs                    |int    |FK version_control_... | __unique 1__  |
|                       |mset                   |int    |FK mirror_set          | __unique 1__  |
|                       |size_kb                |int    |                       |Kilobyte       |
|                       |size_previous          |int    |                       |ditto          |
|                       |commits_current        |int    |                       |               |
|                       |commits_previous       |int    |                       |               |
|store_github_forks     |                       |       |                       |               |
|                       |store                  |int    |PK, FK store           |               |
|                       |nforks                 |int    |                       |               |
|store_times            |                       |       |                       |               |
|                       |store                  |int    |PK, FK store           |               |
|                       |created                |int    |                       |Epoch          |
|                       |updated                |int    |                       |Epoch          |
|                       |changed                |int    |                       |Epoch          |
|                       |attend                 |bool   |                       |Has issues     |
|                       |min_seconds            |int    |                       |               |
|                       |max_seconds            |int    |                       |               |
|                       |window_seconds         |text   |                       |CSV, last N    |
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

## State keys and semantics

|Key                            |Meaning                                |
|---                            |---                                    |
|limit                          |State, #repos per `list` page          |
|start-of-current-cycle         |State, epoch when update cycle started |
|start-of-previous-cycle        |State, epoch, previous update cycle    |
|store                          |State, path to stores on disk          |
|store-window-size              |State, #of update durations to retain  |
|take                           |State, #mirror sets to update per run  |
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
