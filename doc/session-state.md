# V2 Session state

This is new compared to V1.

V1 would have the same.

Mainly information for the CLI to make some operations easier by
having them work on a 'current' entity, which can be moved around in
the whole set like a cursor.

   1. Database Schema Version

   1. Current Repository

   1. Previous Current Repository

   1. Set of mirror sets waiting for update

   1. Number of mirror sets to process (take) per update cycle

   1. Base path for store paths

   1. Per store, epoch of last update.

   1. Per store, epoch of last actual change during an update.

   1. First repository to show in the next invokation of
      `list`. Indirectly implies the first repository to show on
      `rewind` (by taking the limit into account, see next item).

   1. Number of repositories to show per invokation of `list` or
      `rewind`.

   1. Set of Repositories shown in the last invokation of `list` or
      `rewind`, for shorthand addressing.


## Entities

   1. Schema

      Version, possibly other schema related information.

   1. State

      All state which is not per-mirror. Accessed by key (name).

   1. Mirror Set Pending

   1. Store Times

   1. Rolodex (Repository Shorthands)

## Entity Attributes

### schema

|Name	|Type	|Modifiers	|Comments	|
|---	|---	|---		|---		|
|id	|int	|PK		|		|
|name	|text	|unique		|		|
|value	|text	|		|		|

Predefined `name`s, and the associated value

|Name	   |Value     |Comments	|
|---	   |---	      |---	|
|version   |text      |timestamp (Format `yyyymmddHHMM`) of the latest applied migration	|

### state

|Name	|Type	|Modifiers	|Comments	|
|---	|---	|---		|---		|
|id	|int	|PK		|		|
|name	|text	|unique		|		|
|value	|text	|		|		|

Predefined `name`s, and the associated value

|Name			|Value	|Comments	|
|---	   		|---	|---		|
|current-repository	|int	|ref(repository), current				|
|previous-repository	|int	|ref(repository), previous current			|
|take			|int	|#mirror sets to process per `update` cycle		|
|store			|text	|path to directory to hold the internal stores		|
|limit			|int	|#repositories to show by `list` and `rewind`		|
|top			|int	|ref(repository), repository to show on next `list`	|
|			|	|if not present, or empty, show first repository	|
|rolodex-origin		|text	|last writer to the rolodex table, `list` or `accept`	|

### mset_pending

|Name	|Type	|Modifiers	|Comments	|
|---	|---	|---		|---		|
|id	|int	|PK		|		|
|mset	|int	|FK mirror_set	|		|

### store_times

|Name	|Type	|Modifiers	|Comments	|
|---	|---	|---		|---		|
|id	|int	|PK		|		|
|store	|int	|FK stor	|		|
|updated|int	|   		|epoch of last update		|
|changed|int	|		|epoch of last actual change	|

### rolodex

|Name	|Type	|Modifiers	|Comments	|
|---	|---	|---		|---		|
|id	|int	|PK		|		|
|repo	|int	|FK repository	|		|
|tag	|text	|unique		|Tag assigned by last `list`, `rewind`	|
