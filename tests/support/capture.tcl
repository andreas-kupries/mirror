## -*- tcl -*- (c) 2018
# # ## ### ##### ######## ############# #####################
## Test support - stdout/err capture


proc capture-get {} {
    variable stdout
    return [string trim $stdout]
}

proc capture-reset {} {
    variable stdout {}
    return
}

proc capture {args} {
    set nonewline 0
    set oargs $args
    if {[lindex $args 0] eq "-nonewline"} {
	set nonewline 1
	incr base
	set args [lrange $args 1 end]
    }

    switch -exact -- [llength $args] {
	1 {
	    set chan stdout
	    set text [lindex $args 0]
	}
	2 {
	    lassign $args chan text
	}
	default {
	    error "Bad syntax: [info level 0]"
	}
    }

    if {$chan in {stdout stderr}} {
	# capture std
	variable stdout
	append   stdout $text
	if {$nonewline} return
	append stdout \n
	return
    }

    # All other channels, punt to original
    ::puts_orig {*}$oargs
    return
}

proc capture-on {} {
    rename ::puts    ::puts_orig
    rename ::capture ::puts
    capture-reset
}

proc capture-done {} {
    rename ::puts      ::capture
    rename ::puts_orig ::puts
}
