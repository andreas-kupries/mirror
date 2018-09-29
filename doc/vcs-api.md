# V2 API to version control systems

This is basically the V1 API, except not as a user-visible plugin
system. Internally it shall still be pluggable tough.

Six operations

   - setup
   - cleanup
   - update
   - check
   - split
   - merge

## setup

Signature: `setup PATH URL ...`

Create a new store at the specified PATH and initialize it from the
specified remote locations.

## cleanup

Signature: `cleanup PATH ...`

Destroy the stores at the specified paths.

## update

Signature: `update PATH URL ...`

Update the store at the specified PATH from the specified remote
locations.

Return a boolean result. True if the store received new commits, and
false otherwise.

## check

Signature: `check PATH URL`

Check if the specified remote location is compatible with the store at
the specified path.

Return a boolean result. True if the two are compatible, and false
otherwise.

## split

Signature: `split PATH-ORIGIN PATH-DST`

Create a new store at the specified destination path as a copy of the
store at the specified origin path.

## merge

Signature: `merge PATH1 PATH2`

Merge the two stores at the specified paths into a single store. The
store at the second path is destroyed afterward.
