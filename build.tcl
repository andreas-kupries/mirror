#!/bin/sh
# -*- tcl -*- \
exec kettle -f "$0" "${1+$@}"
kettle tcl
kettle tclapp bin/mirror-migrate
kettle tclapp bin/mirror-search
#kettle tclapp bin/mirror-submit
kettle tclapp bin/mirror
#
# Helpers for working with github
#
kettle tclapp bin/gh-pull
#kettle tclapp bin/gh-follow
