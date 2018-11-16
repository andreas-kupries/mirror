# -*- tcl -*-
##
# (c) 2015-2018 Andreas Kupries http://wiki.tcl.tk/andreas%20kupries
#                               http://core.tcl.tk/akupries/
#
## Access to attached assets.
## Originated in Marpa. Reduced to the asset commands.
##
# This code is BSD-licensed.

## This package uses the fact that Tcl's "source" command uses the ^Z
## character as -eofchar by default. This allows us to attach anything
## after the code without breaking the interpreter.  Basic interpreter
## introspection and shenanigans with -eofchar enable us to access and
## load the attached data when needed.

package provide m::asset 0

# # ## ### ##### ######## #############
## Requisites

package require Tcl 8.5
package require debug
package require debug::caller

debug define m/asset
debug prefix m/asset {[debug caller] | }

# # ## ### ##### ######## #############

namespace eval m {
    namespace export asset
    namespace ensemble create
}

namespace eval m::asset {
    namespace export get add main
    namespace ensemble create
}

# # ## ### ##### ######## #############

proc m::asset::add {path name content} {
    debug.m/asset {}
    # Add an asset to the file at the specified path.
    set c [open $path a]
    puts -nonewline $c \x1A${name}\x1E${content}
    close $c
    return
}

proc m::asset::main {path} {
    debug.m/asset {}
    # This command reads the main segment of the file at path and
    # return its contents. It ignores any attached assets.

    set ch [open $path r]
    # Stop at end of the main file using EOF handling analogous to `source`.
    fconfigure $ch -eofchar \x1A
    set contents [read $ch]
    close $ch
    return $contents
}

proc m::asset::get {path} {
    debug.m/asset {}
    # This command reads all assets attached to the file at path and
    # returns a dictionary of names and content.

    # The attached assets are separated from the main file and each
    # other by ^Z, 0x1a, \032, SUB, substitute.  Each asset consists
    # of name and content, seaprated by ^^, 0x1e, \036, RS, record
    # separator.

    set ch [open $path r]
    # Skip over the main file using EOF handling analogous to `source`.
    fconfigure $ch -eofchar \x1A
    read $ch

    # Switch to regular EOF handling and skip the separator character
    fconfigure $ch -eofchar {}
    read $ch 1

    # Read all the assets into memory, split into a list, split the
    # elements into pairs, and return the resulting dict.
    set content [read $ch]
    close $ch
    set r {}
    foreach asset [split $content \x1A] {
	lassign [split $asset \x1E] name content
	dict set r $name $content
    }

    return $r
}

# # ## ### ##### ######## #############
return
