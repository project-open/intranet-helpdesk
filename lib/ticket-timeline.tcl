# /packages/intranet-helpdesk/lib/ticket-timeline.tcl
#
# Copyright (C) 2014 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.


# ----------------------------------------------------------------------
# Variables and Parameters
# ---------------------------------------------------------------------

# The following variables are expected in the environment
# defined by the calling /tcl/*.tcl libary:

# ticket_id:required
set org_ticket_id $ticket_id



# ----------------------------------------------------------------------
# Ticket info
# ---------------------------------------------------------------------

# Get everything about the ticket
db_1row ticket_info {
	select	*,
		trunc(extract(epoch from (now() - t.ticket_creation_date))/60) as ticket_creation_minutes,
		trunc(extract(epoch from (t.ticket_reaction_date - t.ticket_creation_date))/60) as ticket_reaction_minutes,
		trunc(extract(epoch from (t.ticket_confirmation_date - t.ticket_creation_date))/60) as ticket_confirmation_minutes,
		trunc(extract(epoch from (t.ticket_done_date - t.ticket_creation_date))/60) as ticket_done_minutes,
		trunc(extract(epoch from (t.ticket_signoff_date - t.ticket_creation_date))/60) as ticket_signoff_minutes
	from	im_tickets t,
		im_projects p,
		acs_objects o
	where	t.ticket_id = :org_ticket_id and
		p.project_id = t.ticket_id and
		o.object_id = t.ticket_id
}

set ticket_creation_hours [expr int($ticket_creation_minutes / 60.0)]
set ticket_creation_minutes [expr $ticket_creation_minutes - 60*$ticket_creation_hours]
if {[string length $ticket_creation_minutes] < 2} { set ticket_creation_minutes "0$ticket_creation_minutes" }
set ticket_creation_time "$ticket_creation_hours:$ticket_creation_minutes ago"


if {"" ne $ticket_reaction_minutes} {
    set ticket_reaction_hours [expr int($ticket_reaction_minutes / 60.0)]
    set ticket_reaction_minutes [expr $ticket_reaction_minutes - 60*$ticket_reaction_hours]
    if {[string length $ticket_reaction_minutes] < 2} { set ticket_reaction_minutes "0$ticket_reaction_minutes" }
    set ticket_reaction_time "$ticket_reaction_hours:$ticket_reaction_minutes since creation"
} else {
    set ticket_reaction_time ""
}

if {"" ne $ticket_confirmation_minutes} {
    set ticket_confirmation_hours [expr int($ticket_confirmation_minutes / 60.0)]
    set ticket_confirmation_minutes [expr $ticket_confirmation_minutes - 60*$ticket_confirmation_hours]
    if {[string length $ticket_confirmation_minutes] < 2} { set ticket_confirmation_minutes "0$ticket_confirmation_minutes" }
    set ticket_confirmation_time "$ticket_confirmation_hours:$ticket_confirmation_minutes since creation"
} else {
    set ticket_confirmation_time ""
}

if {"" ne $ticket_done_minutes} {
    set ticket_done_hours [expr int($ticket_done_minutes / 60.0)]
    set ticket_done_minutes [expr $ticket_done_minutes - 60*$ticket_done_hours]
    if {[string length $ticket_done_minutes] < 2} { set ticket_done_minutes "0$ticket_done_minutes" }
    set ticket_done_time "$ticket_done_hours:$ticket_done_minutes since creation"
} else {
    set ticket_done_time ""
}

if {"" ne $ticket_signoff_minutes} {
    set ticket_signoff_hours [expr int($ticket_signoff_minutes / 60.0)]
    set ticket_signoff_minutes [expr $ticket_signoff_minutes - 60*$ticket_signoff_hours]
    if {[string length $ticket_signoff_minutes] < 2} { set ticket_signoff_minutes "0$ticket_signoff_minutes" }
    set ticket_signoff_time "$ticket_signoff_hours:$ticket_signoff_minutes since creation"
} else {
    set ticket_signoff_time ""
}



db_0or1row forum_topic_info "
	select	f.*
	from	im_forum_topics f
	where 	f.topic_id in (
			select	min(topic_id)
			from	im_forum_topics
			where	object_id = :org_ticket_id
		)
"

# ----------------------------------------------------------------------
# Select out several types of related tickets
# ---------------------------------------------------------------------

set ticket_creation_l10n [lang::message::lookup "" intranet-helpdesk.Creation_date "Creation date"]
set ticket_reaction_l10n [lang::message::lookup "" intranet-helpdesk.Reaction_date "Reaction date"]
set ticket_confirmation_l10n [lang::message::lookup "" intranet-helpdesk.Confirmation_date "Confirmation date"]
set ticket_done_l10n [lang::message::lookup "" intranet-helpdesk.Done_date "Done date"]
set ticket_signoff_l10n [lang::message::lookup "" intranet-helpdesk.Signoff_date "Signoff date"]

multirow create timeline event date time diff comment

multirow append timeline $ticket_creation_l10n [string range $ticket_creation_date 0 10] [string range $ticket_creation_date 11 15] "$ticket_creation_time" ""
multirow append timeline $ticket_reaction_l10n [string range $ticket_reaction_date 0 10] [string range $ticket_reaction_date 11 15] "$ticket_reaction_time" ""
multirow append timeline $ticket_confirmation_l10n [string range $ticket_confirmation_date 0 10] [string range $ticket_confirmation_date 11 15] "$ticket_confirmation_time" ""
multirow append timeline $ticket_done_l10n [string range $ticket_done_date 0 10] [string range $ticket_done_date 11 15] "$ticket_done_time" ""
multirow append timeline $ticket_signoff_l10n [string range $ticket_signoff_date 0 10] [string range $ticket_signoff_date 11 15] "$ticket_signoff_time" ""

template::list::create \
    -name timeline \
    -elements {
	event {
	    label "[lang::message::lookup {} intranet-helpdesk.Event Event]"
	}
	date {
	    label "[lang::message::lookup {} intranet-helpdesk.Absolute_Date {Absolute Date}]"
            display_template {
                @timeline.date@ @timeline.time@
            }
	}
	diff {
	    label "[lang::message::lookup {} intranet-helpdesk.Relative_Time {Relative Time}]"
	}
    }

