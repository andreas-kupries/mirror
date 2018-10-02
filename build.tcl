#!/bin/sh
# -*- tcl -*- \
exec kettle -f "$0" "${1+$@}"
kettle tcl
kettle tclapp bin/mirror-migrate
kettle tclapp bin/mirror
