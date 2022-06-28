
# V2 Schema Issues

  1. Nit: `Mirror set` is not a good name for the concept. `Project` is better.

  2. The `Mirror set`, `Repository`, and `Store` relations are not
     nicely modeled in the tables. Using the indirect coupling of the
     last through the `Mirror set`/`VCS` combination is messy.

     The relation that a `repository` __has a_ (backing) `store` (1:n)
     is the core, and not modeled.

  3. The various fields of the `store_times` table belong to `store`,
     and `repository`. It is unclear and not remembered anymore why an
     adjunct table was added to the system, instead of the entity
     properly extended.

  4. Nit: The `store_times.attend` field should be named `has_issues`.

  5. Do we truly need current and previous values for size and commits ?

  6. Table `store_github_forks` is IMHO superfluous with the ideas
     around changing the fork handling currently hidden in the github
     driver. See next point.

  7. The github driver, with its complex internal handling of forks in
     a single store is messy and fragile. The fragility is mainly
     around the handling of tags per fork, and having to
     add/remove/rename/readd origins.

     The other issue is that various git/hub operations are linear in
     the number of forks. This becomes problematic above a 100 or so forks.

     It definitely prevents using some kind of timeout to break out of
     stuck processes. It cannot be decided if the process is truly
     stuck, or simply crawling through the pile of forks.
