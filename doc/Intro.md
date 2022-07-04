
This tool is a manager for the local backup of remote source __repositories__. It is able
to expose such backups through a web interface, and to accept (moderated) submissions of
repositories to backup through the same.

The repositories to be added, removed, relocated, etc. are identified by their remote
location, i.e. url.

Managed repositories can be placed into and taken from larger groups, named __projects__.
Projects are identified by their name, Their purpose is to group repositories handling the
same, or just similar sources together.

As a dependent concept projects cannot exist without at least one repository held in
them. Removal of the last repository in a project, wether by moving it to a different
project, or deletion, means deletion of the project.

A further consequence is that projects can also be identified by the urls the contained
repositories.

Going back to these, newly added repositories always reside in their own project, either
named after the repository, or named by the user.

Another concept is that of __stores__. A store contains the data of one or more
repositories. Stores are automatically maintained, like projects. In contrast to them
stores however have no user-identifiable information, and are never accessed
directly. They are only accessed through operations on repositories.

Each new repository is given its own store. Multiple repositories are made to share a
store by __merging__ them. This is however also dependent on the __version control
system__ a repository and its store are managed by. To contrast, mercurial and git(hub) do
not care at all, thus always allow merging. Subversion does not support any kind of
merging. And fossil is in the middle, allowing merging if and only if the stores have the
same fossil project code (which has nothing to do with this tool's projects).

The converse operation of __splitting__ gives repositories with a shared store their own
stores again. This is always possible.

As repositories are added, removed, merged, split, and listed the manager maintains a
rolodex of the last N repositories touched by an operation. This is a stack where the last
used repository is always pulled to the top if it is in the rolodex already, and called
the __current__ repository. The respository which was current before that is the
__previous__ repository.

Where commands take repository references these can be addressed using the tags `@c`,
`@p`, and `@XXX` where XXX is the number of the slot in the rolodex. `@0` for example
refers to the bottom entry of the rolodex.

Several commands automatically use the current and/or previous repository when no
repository is specified.

For commands taking project references remember that a project can also be identified by
any of the repositories it contains.

Commands exist to list the known repositories. To avoid overflowing the terminal only a
limited number of repositories is shown, and multiple invokations of the main `list`
command can be used to page through the entire list. The `rewind` command provides
backward paging.

The exact limit can be configured, it defaults to 20. It is possible to set a limit
causing automatic adaption to the terminal's number of rows.

Note that whenever `list` and `rewind` are used to show part of the set of known
repositories the shown repositories are entered into the __rolodex__.
