# Web Interface

## Submissions

The backup system is controlled by a single person or group, with
access to the host (and account) running it.

External submissions of repository locations however are something we
want.

For this we need a single dialog / form page.

Data to enter are

   - location of the repository (required)
   - name of the mirror set ? -- no, will choose my own anyway
   - email of the submitter to be able to ask questions (required)
   - submitter name (optional)
   - date+time of entry (required, automatic)

The form backend can read the table of existing repositories and
auto-reject (nicely) anything which is already known.

The same for duplicate submissions.

All submissions go into a separate table for curation.

Cli commands will be added to list submissions, and accept or reject them.

A rejection table should be kept, with reason of rejection. The form
backend can use that to recognize duplicates and auto-reject them
(nicely).

A basic bayesian spam filter could be added, in the future
(3-grams to 5-grams ? variant length chunks (words))

## Display

The display portion could be similar to what I currently have at

https://akupries.tclers.tk/r/index.html

   - List of mirror sets ordered by last change
   - Pages per mirror set listing and linking the repositories inside.

     Also exposing the backend store(s) for mirroring it, where
     possible.

## Schema

### submission

|Name	|Type	|Modifiers	|Comments			|
|---	|---	|---		|---				|
|id	|int	|PK		|				|
|when	|int	|		|epoch of submission time	|
|email	|text	|		|		     		|
|name	|text	|nullable	|				|
|url	|text	|unique		|				|

### rejection

|Name	|Type	|Modifiers	|Comments	|
|---	|---	|---		|---		|
|id	|int	|PK		|		|
|url	|text	|unique		|		|
|cause	|text	|		|web info	|
