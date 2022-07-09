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
    return "[string map $map $header] <h1> $title </h1>"
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
    regexp {(<head>.*</header>).*(<footer.*)</html>} $c -> header footer

    set self [wapp-param SELF_URL]
    set base [wapp-param BASE_URL]
    lappend map  https:/ https://
    lappend map  http:/  http://
    set app [string map $map [file dirname $base]]

    # Rewrite the canonical link to current page
    regsub \
	"<link ref=\"canonical\" href=\"\[^\"]*\">" $header \
	"<link ref='canonical' href='$self'>" header

    # Regenerate the parts of the document stripped by the extraction.
    set header "<!DOCTYPE html><html>$header"
    set footer "</section><div></div></div>$footer</html>"

    # Replace title with place holder to fill in by caller.
    unset   map
    lappend map "title>Contact"   "title>%%%"
    lappend map "title\">Contact" "title\">%%%"

    # Rewrite relative links to site assets to absolute.
    lappend map "./" "${app}/"

    # Rewrite navbar index reference to absolute
    lappend map \
	"navbar-brand\" href=\"" \
	"navbar-brand\" href=\"${app}/"

    set header [string map $map $header]
    set footer [string map $map $footer]
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
