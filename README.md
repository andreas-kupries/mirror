# Mirror Management

## Intro

MM is a tool to ease backing up a large number of repositories.

It currently supports fossil, git(hub) and mercurial (hg)
repositories.

Its operation is made easier by these DVCS all having replication and
synchronization protocols baked into them and their clients. Because
of that MM did not have to invent anything new, it gets by just by
invoking the existing tools (`fossil`, `hg`, `git`, `git hub`).

All management is done through a command line application with
integrated help, called `mirror`.

Beyond management MM is also capable of exposing the pool of backups
to the web. This is done by `mirror` generating a static website which
can then be served by a web engine of the user's choice. This
functionality requires `TclSSG` to be installed, expecting its main
application to be accessible under the name `ssg`.

It should be noted MM does not automatically perform repository
updates on its own. It expects to be invoked by some external
scheduler, for example `cron`, for this.

## Basics of operation

### Adding repositories

The basic command to add a single __repository__ to the system is

    mirror add <url>

MM will try to figure out the type of __repository__ to mirror from
the specified url, and further derive a name for the __mirror set__ to
hold the repository as well.

If it guesses wrong the options `--vcs` and `--name` can be used to
explicitly specify the correct values.

    mirror add <url> --name <name> --vcs <vcs>

The set of version control systems supported by the installed `mirror`
can be queried with

    mirror vcs

Going back to `add` and its auto-detection of vcs type, the currently
employed heuristics (.i.e url patterns), are, in order:

|Pattern			|VCS	|Notes				|
|---				|---	|---				|
|`*github*`			|github	|Requires `git hub` & `git`	|
|`*git*`			|git	|Requires `git`	       		|
|`*hg.code.sf.net*`		|hg	|Requires `hg`			|
|`*hg.code.sourceforge.net*`	|hg	|S.a.				|
|`*`				|fossil	|Requires `fossil`		|

As can be seen, the order does matter, and `fossil` is the catch-all
fallback.

The two main concepts here are the __repository__, identified by its
url, and the __mirror set__, identified by its name.

While `mirror add` always places the specified repository into its own
__mirror set__ the latter can contain more than one repository, while
each repository always belongs to only one mirror set.

Mirror sets are there to group related repositories together. The
command to coalesce mirror sets into one after adding repositories is
`mirror merge`.

The action comes at a price, and with restrictions. All repositories
in a mirror set for the same type VCS will share the local backing
store.

For fossil repositories MM can and does use the asociated
`projectcode` to detect attempts at merging unrelated repositories,
and rejects such. For git(hub) no such information exists, and the
only warning will be the message `no common ancestors found` when
updating such a mirror set. For mercurial the situation is similar.

On the positive side placing related repositories together reduces the
amount of disk space required.

### Quick access to content

An important structure maintained by MM is the __rolodex__.

It is a stack which is updated whenever repositories are added or
removed, and mirror sets merged and split. This makes it easy to
quickly reference repositories which were recently worked on.

The last and previously used repositories are accessible through the
`@c` and `@p` short hands. The repositories further down the history
are accessible via `@num`.

The new rolodex's contents are always shown after a command changing
it completes, and can be explicitly queried with `mirror current`.

Search operations like `mirror list <substring>` write their results
to the rolodex as well.

Note, the rolodex is of limited size. The initial default is __20__
entries. This configuration can be queried and changed with the
`mirror limit` command.

The same limit `L` also applies to the output of the `mirror list`
command when not used to search for content. In that case it shows
only `L` entries per invokation, and a series of invokations cycles
through the entire list of repositories.

### Updating the mirror

The command to update the mirror is `mirror update` (sic!).

To prevent overloading both the local machine and the remote locations
each invokation of this command will only update a subset of the known
mirror sets. To this end MM manages an internal queue new mirror sets
are added to, and mirror sets to update are taken from from the
front. When the queue runs empty it is simply refilled again with all
the mirror sets known at that time.

The current state of the queue is accessible via `mirror pending`,
with the mirror sets to be taken by the next invokation of `mirror
update` at the top and marked.

The default is to update _5_ mirror sets per invokation. This
configuration can be queried and changed with the `mirror take`
command.

Together with being driven by the liks of `cron` this keeps the local
load low, and distributes the remote load over a larger time interval
as well, with cron interval and number of sets taken per cycle the
main knobs to regulate this.

### Bulk operations

While `add` and `merge` are the only operations needed to add new
repositories, and manage their mirror sets, using them still will be
tedious when having to add a large batch.

To simply this case we have the command `mirror import`. It takes a
simple text specifying repositories and their mirror sets in simple
markup and imports them all in one batch, performing all the necessary
`add` and `merge` operations.

The file format is line-oriented, with each non-comment line
specifying either a repository, or a mirror set. Comments start with a
hash-character (`#`, U+0023) and run to the end of their line. Empty
lines are ignored.

The simplest possible import file looks like

    R <vcs> <url>
    M <name>

and is equivalent to 

    mirror add <url> --name <name> --vcs <vcs>

to place more repositories into the the mirror set <name> simply place
more repository specification before it, like

    R <vcs1> <url1>
    R <vcs2> <url2>
    ...
    M <name>

Any number of repositories and mirror sets can be specified.

On the converse side of the above is `mirror export`, which writes the
current state of repositories and mirror sets to `stdout`, in a format
directly usable to `mirror import`.

### 404 - No contact at this number

Given that MM is for the backup of remote repositories to protect
against their loss, it is only right to handle the possibility of
remote locations vanishing.

Such a sitation will actually not disturb the operation of `mirror
update`, and if the loss is temporary the situation will resolve
itself when update comes back to the repository in question, and
simply pull more data from the other side.

However when the situation appears to be permanent then the manager
might not wish to spend cycles and bandwidth on querying a repository
which is gone. Yet the local backup should not be deleted either.

Thus we have `mirror disable` and `mirror enable` with which we can
take a repository out of the update rotation, or put it back in. A
repository in the rotation is called `active`, and `inactive`
otherwise.

### Web site

... TODO ...
