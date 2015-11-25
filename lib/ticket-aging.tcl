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
if {![info exists diagram_width] || "" == $diagram_width} { set diagram_width 250 }
if {![info exists diagram_height] || "" == $diagram_height } { set diagram_height 250 }
if {![info exists diagram_font] || "" == $diagram_font} { set diagram_font "10px Helvetica, sans-serif" }
if {![info exists diagram_theme] || "" == $diagram_theme} { set diagram_theme "Custom" }
if {![info exists diagram_limit] || "" == $diagram_limit} { set diagram_limit 40 }
if {![info exists diagram_inset_padding] || "" == $diagram_inset_padding} { set diagram_inset_padding 5 }
if {![info exists diagram_tooltip_width] || "" == $diagram_tooltip_width} { set diagram_tooltip_width 230 }
if {![info exists diagram_tooltip_height] || "" == $diagram_tooltip_height} { set diagram_tooltip_height 20 }
if {![info exists diagram_legend_width] || "" == $diagram_legend_width} { set diagram_legend_width 83 }
if {![info exists diagram_title] || "" == $diagram_title} { set diagram_title [lang::message::lookup "" intranet-helpdesk.Ticket_Aging "Ticket Aging"] }


set ticket_customer_contact_dept_code ""
if {[info exists ticket_customer_contact_dept_id] && [string is integer $ticket_customer_contact_dept_id]} { 
    set ticket_customer_contact_dept_code [db_string dept_code "select im_cost_center_code_from_id(:ticket_customer_contact_dept_id)" -default ""]
}

set ticket_assignee_dept_code ""
if {[info exists ticket_assignee_dept_id] && [string is integer $ticket_assignee_dept_id]} { 
    set ticket_assignee_dept_code [db_string dept_code "select im_cost_center_code_from_id(:ticket_assignee_dept_id)" -default ""]
}

set prio_id 0
if {[info exists ticket_prio_id]} { set prio_id $ticket_prio_id }
set ticket_prio_id $prio_id

set type_id 0
if {[info exists ticket_type_id]} { set type_id $ticket_type_id }
set ticket_type_id $type_id

set status_id 0
if {[info exists ticket_status_id]} { set status_id $ticket_status_id }
set ticket_status_id $status_id

set sla_id 0
if {[info exists ticket_sla_id]} { set sla_id $ticket_sla_id }
set ticket_sla_id $sla_id

set customer_contact_id 0
if {[info exists ticket_customer_contact_id]} { set customer_contact_id $ticket_customer_contact_id }
set ticket_customer_contact_id $customer_contact_id



set prio1_l10n [lang::message::lookup "" intranet-helpdesk.Ticket_Aging_Prio1 "Prio 1"]
set prio2_l10n [lang::message::lookup "" intranet-helpdesk.Ticket_Aging_Prio23 "Prio 2-3"]
set prio3_l10n [lang::message::lookup "" intranet-helpdesk.Ticket_Aging_Prio46 "Prio 4-6"]
set prio4_l10n [lang::message::lookup "" intranet-helpdesk.Ticket_Aging_Prio7 "Prio 7-..."]

set day_l10n [lang::message::lookup "" intranet-core.day_age "day age"]
set days_l10n [lang::message::lookup "" intranet-core.days_age "days age"]

set ticket_l10n [lang::message::lookup "" intranet-core.Ticket "Ticket"]
set tickets_l10n [lang::message::lookup "" intranet-core.Tickets "Tickets"]

set of_l10n [lang::message::lookup "" intranet-core.Ticket_Aging_of "of"]


# ----------------------------------------------------
# Diagram Setup
# ----------------------------------------------------

# Create a random ID for the diagram
set diagram_rand [expr {round(rand() * 100000000.0)}]
set diagram_id "ticket_aging_$diagram_rand"

