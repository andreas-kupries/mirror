## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## Bootstrap generation

# @@ Meta Begin
# Package m::web::bootstrap 0
# Meta author   {Andreas Kupries}
# Meta location https://core.tcl.tk/akupries/????
# Meta platform tcl
# Meta summary     Pull bootstrap.js information out of the site itself
# Meta description Pull bootstrap.js information out of the site itself
# Meta subject     {web bootstrap} {bootstrap assets}
# Meta require {Tcl 8.5-}
# @@ Meta End

package provide m::web::bootstrap 0

# # ## ### ##### ######## ############# #####################
## Requirements

package require Tcl 8.5
package require debug
package require debug::caller
package require m::futil

# # ## ### ##### ######## ############# ######################

debug level  m/web/bootstrap
debug prefix m/web/bootstrap {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval ::m {
    namespace export web
    namespace ensemble create
}

namespace eval ::m::web {
    namespace export bootstrap
    namespace ensemble create
}

namespace eval ::m::web::bootstrap {
    namespace export header footer
    namespace ensemble create
}

# # ## ### ##### ######## ############# #####################

proc ::m::web::bootstrap::header {title} {
    debug.m/web/bootstrap {}
    variable header
    if {$header eq {}} { GET }
    lappend map %%% $title
    return "[string map $map $header] <hr class='page-title'>$title</h1> </header> <h1> $title </h1>"
}

proc ::m::web::bootstrap::footer {} {
    debug.m/web/bootstrap {}
    variable footer
    if {$footer eq {}} { GET }
    return $footer
}

# # ## ### ##### ######## ############# #####################

proc ::m::web::bootstrap::GET {} {
    debug.m/web/bootstrap {}
    global argv0
    variable header
    variable footer

    #puts stderr $argv0
    #puts stderr [pwd]
    
    set c [m futil cat [file join [pwd] contact.html]]

    # Extract the bootstrap header and footer for our use.
    regexp {(<head>.*<header>).*(<footer.*)</html>} $c -> header footer
    set header [string map [list "title>Contact" "title>%%%"] $header]
    return
}

# # ## ### ##### ######## ############# #####################
## State

namespace eval ::m::web::bootstrap {
    variable header {}
    variable footer {}
}

# # ## ### ##### ######## ############# #####################
return
