
---

1. Check and fix merge
1. Check and fix split
1. Website - want more pages - statistics, project index/details
1. Test add/update handling of network/server issues, i.e. disconnects, timeouts, ...

---

1. merge - logic still based on projects -- rework to place repos at center
1. projects - list projects
1. projects - show project details
1. need stats command - summary of projects, repos, stores
1. repos - need commands to move repos between projects
1. repos - need commands to remove projects

   note: currently auto-removing a project when last repo removed
     - extend this to moves ?

1. note! forks and their origin can all be in different projects
1. new list - show only primary repos, exclude forks
1. log information saved at stores - should be at repos

     - issues happen when acessing a repo
     
   alternate: keep with store (on disk), but separate logs per repo.

1. refresh stores ? - old github stores can be big, containing shared data from all forks ... kill and recreate store to reduce it ?

   better:
     - rename old github repo projects, then re-add => new stores
     - disable old stores - hide from web indices ? (another repo flag)
     - more disk space
     - but keeps old state until new setup has initialized

     - Save old database, and pull the `store_github_forks` data for assessment of repos and their forks => handle the small ones first

1. export command (`dump`?) to save a store with associated metadata to external directory

   => save old github stores before removing from management

1. more various internal commands between packages - support for various list commands should be in repo now, instead of store

1. mirror config store - changes - broken
