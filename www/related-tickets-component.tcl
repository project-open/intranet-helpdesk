# /packages/intranet-helpdesk/www/related-tickets-component.tcl
#
# Copyright (c) 2003-2008 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

# Shows the list of tickets related to the current ticket

# ---------------------------------------------------------------
# Variables
# ---------------------------------------------------------------

#    { ticket_id:integer "" }
#    return_url 

# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------

set current_user_id [ad_maybe_redirect_for_registration]

# ---------------------------------------------------------------
# Referenced Tickets - Problem tickets referenced by THIS ticket
# ---------------------------------------------------------------

set bulk_action_list {}
lappend bulk_actions_list "[lang::message::lookup "" intranet-helpdesk.Delete "Delete"]" "ticket-ticket-rel-del" "[lang::message::lookup "" intranet-helpdesk.Remove_checked_items "Remove Checked Items"]"

set assoc_incident_ticket [lang::message::lookup {} intranet-helpdesk.Assoc_to_new_incident_ticket {Associate with a new incident ticket}]

list::create \
    -name tickets \
    -multirow tickets_multirow \
    -key rel_id \
    -row_pretty_plural "[lang::message::lookup {} intranet-helpdesk.Tickets "Associated Tickets"]" \
    -has_checkboxes \
    -bulk_actions $bulk_actions_list \
    -bulk_action_export_vars { return_url } \
    -actions [list \
	"$assoc_incident_ticket" \
	"/intranet-helpdesk/new?ticket_id=$ticket_id" \
	"" \
    ] \
    -elements {
	ticket_chk {
	    label "<input type=\"checkbox\" 
                          name=\"_dummy\" 
                          onclick=\"acs_ListCheckAll('tickets_list', this.checked)\" 
                          title=\"Check/uncheck all rows\">"
	    display_template {
		@tickets_multirow.ticket_chk;noquote@
	    }
	}
	project_nr {
	    label "[lang::message::lookup {} intranet-helpdesk.Ticket_Nr {Nr}]"
	    link_url_eval {[export_vars -base "/intranet-helpdesk/new" {ticket_id}]}
	}
	project_name {
	    label "[lang::message::lookup {} intranet-helpdesk.Ticket_Name {Ticket Name}]"
	    link_url_eval {[export_vars -base "/intranet-helpdesk/new" {ticket_id}]}
	}
    }


set tickets_sql "
	select
		t.*,
		p.*,
		r.rel_id
	from	im_tickets t,
		im_projects p,
		acs_rels r
	where
		t.ticket_id = p.project_id and
		(
			r.object_id_one = :ticket_id and
			r.object_id_two = t.ticket_id
		OR
			r.object_id_one = t.ticket_id and
			r.object_id_two = :ticket_id
		)
		
"

db_multirow -extend { ticket_chk ticket_url } tickets_multirow tickets $tickets_sql {
    set ticket_url ""
    set ticket_chk "<input type=\"checkbox\" 
				name=\"rel_id\" 
				value=\"$rel_id\" 
				id=\"tickets_list,$rel_id\">"
}

