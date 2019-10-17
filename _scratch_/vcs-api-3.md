# V3 api

## Overview

Generally, all operations on stores and remotes are delegated to an
external command. This command can be VCS-specific. For all VCS
without a custom command specified the command is constructed as

       %self% vcs %operation% %vcs% %log% ...

where `...` are the operation-specific arguments, and the placeholders are

|Placeholder	|Replacement					|
|---		|---						|
|`%self%`	|Path to the mirror executable			|
|`%operation%`	|Code of the operation to perform		|
|`%vcs%`	|Code of the VCS controlling the store(s)	|
|`%log%`	|Path to the full operation log			|
|`%%`		|`%` itself  	  	    			|

Progress reporting is expected on stdout, as line separated Tcl
commands. Each Tcl command is limited to a single line. Multi-line
commands are not allowed. The commands represent tags indicating the
priority of the text arguments following it.

A full operation log is expected in the file pointed to by the %log%
argument. This log has the same format as the progress report on
stdout, albeit with more commands. The additional commands are used to
return information about the store and remotes back to the core/caller.

This is used to reduce the set of required operations to the
essentials and keep the non-essentials hidden in the command
implementation.

The exit code of the command indicates overall ok/fail status. A
failed command can still provide information (details about the
problem) in its operation log.

## Progress reporting

The reporting commands, i.e. tags are

  - info
  - note
  - warn
  - error
  - fatal

In regular mode only messages with warning and higher are reported.
In verbose mode all levels are shown.

## Result reporting

The additional result commands are

|Command	|Meaning			|Notes		|
|---		|---				|---		|
|commits N	|Commits found in the store	|		|
|size N		|Size of the store on disk	|		|
|fork URL	|Automagic remote to track	|github specific|
|ok		|Positive status     		|		|
|fail		|Negative status		|		|
|result VAL	|A result value (status s.a)	|		|
|duration S	|Time spent in the operation	|		|

## Operations

|Operation		|Meaning						|State	|
|---			|---							|---	|
|setup STORE URL	|Create store, with initial remote			|	|
|cleanup STORE		|Remove store	      	  	 			|ok	|
|update STORE URL 1st	|Update store from specified remote, flag primary	|	|
|mergable? STORA STORB	|Are the two stores mergable ?				|	|
|merge DST SRC	 	|Merge SRC store into DST store, remove SRC		|	|
|split SRC DST		|Make store DST a copy of store SRC			|	|
|export STORE		|Return path to CGI script for web access to store	|	|
|version		|Version of the installed VCS client	     		|ok	|
|url-to-name		|Generate a name from a remote				|	|

The VCS-specific code should only check primary remotes for forks,
i.e. automagic remotes. Assuming that the VCS supports this.
