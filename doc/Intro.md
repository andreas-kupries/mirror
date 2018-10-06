
This tool is a manager for the local backup of remote source
repositories. It is able to expose such backups through a web
interface, and to accept (moderated) submissions of repositories to
backup through the same.

The user can add and remove __repositories__, identified by their
remote location, i.e. url.

Known repositories can be placed (merged) into and removed (split)
from larger groups, called __mirror sets__, which are named. The
purpose of mirror sets is to group repositories all handling the same
sources together.

In the case of fossil repositories the manager is able to verify that
the remotes are indeed for the same project, via the project code they
contain, and will prevent the grouping of unrelated repositories.  Git
unfortunately does not have such features. This is actually important,
because each group will have only one backing store per subset of
repositories managed by the same (D)VCS. Grouping unrelated git
repositories together means that their backing store will contain a
union of them all. For fossil repositories this is automatically
prevented.

Newly added repositories always reside in their own mirror set, either
named after the repository, or named by the user.

As repositories are added, removed, merged, and split the manager
maintains a 2-level stack containing the __current__ repository, and
the __previous__(ly current) repository.

Where commands take repository references these can be addressed using
`current` (`curr`, `@`) and `prev`. Several commands automatically use
the current and/or previous repository when no repository is
specified.

Commands exist to list the known repositories. To avoid overflowing
the terminal only a limited number of repositories is shown, and
multiple invokations of the main `list` command can be used to page
through the entire list. The `rewind` command provides backward paging.

The exact limit can be configured, it defaults to 20.

Whenever `list` and `rewind` are used to show part of the set of known
repositories the shown repositories are entered into the __rolodex__.

Where commands take repository references the repositories in this
structure can be referenced using shorthands of the form `#N`.

[[ Digression

   I am currently wondering if I should get rid of the
   current/previous stack and simply use the rolodex for the same
   purpose.

   I already use the rolodex as the target for `accept`ed submissions,
   with accumulation, so using it for regular `add`ed repositories
   should be no trouble. It would internally run through the same
   code.

   At that point instead of having to add/add/merge/add/merge/...
   I can also do add/add/.../merge/merge/...

   And there is less state for the user to keep track of.  I.e. a
   single rolodex instead of rolodex plus limited stack.

   Note: It is currently specified that `list` and `rewind` replace
   the current rolodex with their output, i.e. overwriting whatever
   was `accept`ed (or, with the change `add`ed. In the same vein, the
   moment we start `accept`ing the list rolodex is gone ...

   Although this latter, could be changed, to extend instead (push).

]]
