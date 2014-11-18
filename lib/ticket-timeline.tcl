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
db_1row ticket_info "
	select	*
	from	im_tickets t,
		im_projects p,
		acs_objects o
	where	t.ticket_id = :org_ticket_id and
		p.project_id = t.ticket_id and
		o.object_id = t.ticket_id
"

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

multirow create timeline event date time comment

multirow append timeline $ticket_creation_l10n [string range $ticket_creation_date 0 10] [string range $ticket_creation_date 11 15] ""
multirow append timeline $ticket_reaction_l10n [string range $ticket_reaction_date 0 10] [string range $ticket_reaction_date 11 15] ""
multirow append timeline $ticket_confirmation_l10n [string range $ticket_confirmation_date 0 10] [string range $ticket_confirmation_date 11 15] ""
multirow append timeline $ticket_done_l10n [string range $ticket_done_date 0 10] [string range $ticket_done_date 11 15] ""
multirow append timeline $ticket_signoff_l10n [string range $ticket_signoff_date 0 10] [string range $ticket_signoff_date 11 15] ""

template::list::create \
    -name timeline \
    -elements {
	event {
	    label "[lang::message::lookup {} intranet-helpdesk.Event Event]"
	}
	date {
	    label "[lang::message::lookup {} intranet-helpdesk.Date Date]"
	}
	time {
	    label "[lang::message::lookup {} intranet-helpdesk.Time Time]"
	}
    }

