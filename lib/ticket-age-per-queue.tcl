# /packages/intranet-reporting-dashboard/lib/ticket-age-per-queue.tcl
#
# Copyright (C) 2015 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

# ----------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------

set current_user_id [ad_conn user_id]

# The following variables are expected in the environment
# defined by the calling /tcl/*.tcl libary:
if {![info exists diagram_report_code] || "" == $diagram_report_code} { set diagram_report_code "rest_open_ticket_age_per_queue_type" }
if {![info exists diagram_width] || "" == $diagram_width} { set diagram_width 250 }
if {![info exists diagram_height] || "" == $diagram_height } { set diagram_height 350 }
if {![info exists diagram_font] || "" == $diagram_font} { set diagram_font "10px Helvetica, sans-serif" }
if {![info exists diagram_theme] || "" == $diagram_theme} { set diagram_theme "Custom" }
if {![info exists diagram_limit] || "" == $diagram_limit} { set diagram_limit 40 }
if {![info exists diagram_inset_padding] || "" == $diagram_inset_padding} { set diagram_inset_padding 5 }
if {![info exists diagram_tooltip_width] || "" == $diagram_tooltip_width} { set diagram_tooltip_width 160 }
if {![info exists diagram_tooltip_height] || "" == $diagram_tooltip_height} { set diagram_tooltip_height 40 }
if {![info exists diagram_legend_width] || "" == $diagram_legend_width} { set diagram_legend_width 150 }
if {![info exists diagram_title] || "" == $diagram_title} { set diagram_title [lang::message::lookup "" intranet-helpdesk.Ticket_Aging "Ticket Aging"] }

# Default customer: 0 means no customer contact specified
if {![info exists ticket_customer_contact_id] || "" == $ticket_customer_contact_id} { set ticket_customer_contact_id 0 }

set day_l10n [lang::message::lookup "" intranet-helpdesk.day_age "day age"]
set days_l10n [lang::message::lookup "" intranet-helpdesk.days_age "days age"]

set ticket_l10n [lang::message::lookup "" intranet-helpdesk.Ticket "Ticket"]
set tickets_l10n [lang::message::lookup "" intranet-helpdesk.Tickets "Tickets"]

set of_l10n [lang::message::lookup "" intranet-helpdesk.Ticket_Aging_of "of"]

set not_assigned_l10n [lang::message::lookup "" intranet-helpdesk.Not_assigned "Not assigned"]
set show_or_hide_legend_l10n [lang::message::lookup "" intranet-helpdesk.Show_or_hide_legend "Show or hide legend"]
set show_or_hide_help_l10n [lang::message::lookup "" intranet-helpdesk.Show_or_hide_help_window "Show or hide help window"]

set number_l10n [lang::message::lookup "" intranet-helpdesk.Number "Number"]
set age_l10n [lang::message::lookup "" intranet-helpdesk.Age "Age"]
set queue_l10n [lang::message::lookup "" intranet-helpdesk.Queue "Queue"]
set dept_l10n [lang::message::lookup "" intranet-helpdesk.Dept "Department"]


# Select out ticket types from all open tickets
set ticket_types_sql "
	select	distinct im_category_from_id(ticket_type_id) as ticket_type
	from 	im_tickets
	where	ticket_status_id in (select * from im_sub_categories(30000))
	order by ticket_type
"
set ticket_types_list {}
db_foreach ticket_types $ticket_types_sql {
    lappend ticket_types_list "'$ticket_type'"
}
set ticket_types_json "\[[join $ticket_types_list ","]\]"


# ----------------------------------------------------
# Diagram Setup
# ----------------------------------------------------

# Create a random ID for the diagram
set diagram_rand [expr {round(rand() * 100000000.0)}]
set diagram_id "ticket_aging_$diagram_rand"

