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
if {![info exists diagram_report_code] || "" == $diagram_report_code} { set diagram_report_code "rest_ticket_aging_histogram" }
if {![info exists diagram_width] || "" == $diagram_width} { set diagram_width 200 }
if {![info exists diagram_height] || "" == $diagram_height } { set diagram_height 250 }
if {![info exists diagram_font] || "" == $diagram_font} { set diagram_font "10px Helvetica, sans-serif" }
if {![info exists diagram_theme] || "" == $diagram_theme} { set diagram_theme "Blue" }
if {![info exists diagram_limit] || "" == $diagram_limit} { set diagram_limit 40 }
if {![info exists diagram_inset_padding] || "" == $diagram_inset_padding} { set diagram_inset_padding 5 }
if {![info exists diagram_tooltip_width] || "" == $diagram_tooltip_width} { set diagram_tooltip_width 200 }
if {![info exists diagram_tooltip_height] || "" == $diagram_tooltip_height} { set diagram_tooltip_height 20 }
if {![info exists diagram_legend_width] || "" == $diagram_legend_width} { set diagram_legend_width 83 }
if {![info exists diagram_title] || "" == $diagram_title} { set diagram_title [lang::message::lookup "" intranet-helpdesk.Ticket_Aging "Ticket Aging"] }


set prio1_l10n [lang::message::lookup "" intranet-helpdesk.Ticket_Aging_Prio1 "Prio 1"]
set prio2_l10n [lang::message::lookup "" intranet-helpdesk.Ticket_Aging_Prio23 "Prio 2-3"]
set prio3_l10n [lang::message::lookup "" intranet-helpdesk.Ticket_Aging_Prio46 "Prio 4-6"]
set prio4_l10n [lang::message::lookup "" intranet-helpdesk.Ticket_Aging_Prio46 "Prio 7-..."]

set day_l10n [lang::message::lookup "" intranet-core.day "day"]
set days_l10n [lang::message::lookup "" intranet-core.days "days"]

set ticket_l10n [lang::message::lookup "" intranet-core.Ticket "Ticket"]
set tickets_l10n [lang::message::lookup "" intranet-core.Tickets "Tickets"]

set of_l10n [lang::message::lookup "" intranet-core.Ticket_Aging_of "of"]

# ----------------------------------------------------
# Diagram Setup
# ----------------------------------------------------

# Create a random ID for the diagram
set diagram_rand [expr round(rand() * 100000000.0)]
set diagram_id "ticket_aging_$diagram_rand"

