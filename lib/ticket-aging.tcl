# /packages/intranet-reporting-dashboard/lib/ticket-aging.tcl
#
# Copyright (C) 2012 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

# ----------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------

# The following variables are expected in the environment
# defined by the calling /tcl/*.tcl libary:
if {![info exists diagram_width]} { set diagram_width 500 }
if {![info exists diagram_height]} { set diagram_height 300 }
if {![info exists diagram_title]} { set diagram_title [lang::message::lookup "" intranet-helpdesk.Ticket_Aging "Ticket Aging"] }

# ----------------------------------------------------
# Diagram Setup
# ----------------------------------------------------

# Create a random ID for the diagram
set diagram_rand [expr round(rand() * 100000000.0)]
set diagram_id "ticket_aging_$diagram_rand"

