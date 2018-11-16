## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## Helpers for file processing. Simplified tcllib fileutil.

# @@ Meta Begin
# Package m::web::site 0 
# Meta author   {Andreas Kupries}
# Meta location https://core.tcl.tk/akupries/????
# Meta platform tcl
# Meta summary     Static assets of the web site
# Meta description Static assets of the web site
# Meta subject     {web site} {site assets}
# Meta require {Tcl 8.5-}
# @@ Meta End

package provide m::web::site 0

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require debug
package require debug::caller
package require m::asset
package require m::futil
package require m::state

# # ## ### ##### ######## ############# ######################

debug level  m/web/site
debug prefix m/web/site {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval ::m {
    namespace export web
    namespace ensemble create
}

namespace eval ::m::web {
    namespace export site
    namespace ensemble create
}

namespace eval ::m::web::site {
    namespace export init
    namespace ensemble create
}

# # ## ### ##### ######## ############# #####################

proc ::m::web::site::init {} {
    debug.m/web/site {}
    variable self

    set path [m state site-store]
    set dst  $path/web
    
    file delete -force $dst ${dst}_out
    SSG init           $dst ${dst}_out
    return
    
    file delete -force $dst/pages/blog

    dict for {child content} [m asset get $self] {
	set dstfile [file join $dst $child]
	file mkdir [file dirname $dstfile]
	W $dstfile $content
    }
    return
}

# # ## ### ##### ######## ############# #####################

proc ::m::web::site::W {path content} {
    m futil write $path [string map [M] $content]
    return
}

proc ::m::web::site::M {} {
    lappend map @-mail-@       [m state site-mgr-mail]
    lappend map @-management-@ [m state site-mgr-name]
    lappend map @-nav-@        {
	Home    $indexLink
	Contact $rootDirPath/contact.html
    }
    lappend map @-title-@      [m state site-title]
    lappend map @-url-@        [m state site-url]
    lappend map @-year-@       [clock format [clock seconds] -format %Y]
    proc ::m::web::site::M {} [list return $map]
    return $map
}

proc ::m::web::site::SSG {args} {
    debug.m/web/site {}
    m exec go ssg {*}$args
    return
}

# # ## ### ##### ######## ############# #####################
## State

namespace eval ::m::web::site {
    variable self [file normalize [info script]]
}

# # ## ### ##### ######## ############# #####################
return
## Site assets follow ...
website.confwebsiteTitle {@-title-@}
copyright    {<a href="$rootDirPath/disclaimer.html">Copyright &copy;</a> @-year-@ <a href='mailto:@-mail-@'>@-management-@</a>}
url          {@-url-@}
description  {@-title-@}

sitemap { enable 1 }
rss     { enable 1 tagFeeds 1 }
indexPage {index.md}
outputDir {../output}
blogPostsPerFile 0

pageSettings {
    navbarBrand {<div class="pull-left"> <img src="http://www.tclcommunityassociation.org/wub/imgs/tcla_logo2c-tiny.gif" style="height: 33px; margin-top: -10px;"> @-title-@</div>}
    favicon     images/favicon.png
    sidebarNote {}
    navbarItems {@-nav-@}
    gridClassPrefix col-md-
    contentColumns 8
    locale en_US
    hideUserComments 1
    hideSidebarNote 1
    sidebarPosition right
    bootstrapTheme {$rootDirPath/external/bootstrap-3.3.1-dist/css/bootstrap-theme.min.css}
    customCss {{$rootDirPath/tclssg.css}}
}
deployCustom {
    start {}
    file  {}
    end   {}
}
enableMacrosInPages 0
comments {
    engine none
    disqusShortname {}
}
pages/.placeholderstatic/tclssg.cssbody {
    font-size: 18px;
}

header > h1 {
    font-size: 30px;
}

.author {
    margin: 0;
}

.page_info {
    display: block;
    margin-bottom: 10px;
}

:target {
   background-color: #ffffaa;
}

.footer {
  padding-top: 19px;
  color: #777;
  border-top: 1px solid #e5e5e5;
  text-align: center;
}

nav.tags > ul {
    padding-left: 0;
    display: inline;
    list-style-type: none;
}

li.tag {
    display: inline-block;
}

li.tag:after {
    content: ', ';
}

li.tag:last-child:after {
    content: '.';
}
