# /packages/intranet-helpdesk/www/action-accepted.tcl
#
# Copyright (C) 2003-2008 ]project-open[
#
# All rights reserved. Please check
# https://www.project-open.com/license/ for details.

ad_page_contract {
    Mark tickets as "accepted"

    @author frank.bergmann@project-open.com
} {
    { tid:multiple ""}
    { ticket_ids {} }
    { return_url "/intranet-helpdesk/index" }
}

# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------

set current_user_id [auth::require_login]
if { {} == $ticket_ids} {
    set ticket_ids $tid
}


# Deal with funky input parameter combinations
if {![info exists tid]} { set tid {} }
if {0 == [llength $tid]} { ad_returnredirect $return_url }

# ---------------------------------------------------------------
# Perform the action
# ---------------------------------------------------------------

foreach ticket_id $tid {
    
    # Write Audit Trail
    im_audit -object_id $ticket_id -action before_update

    db_transaction {
	# Accept the ticket
	db_dml accept_ticket "
		update	im_tickets set	
			ticket_status_id = [im_ticket_status_accepted]
		where	ticket_id = :ticket_id
	"

	db_dml accept_ticket "
		update	im_tickets set	
			ticket_reaction_date = now()
		where	ticket_id = :ticket_id and
			ticket_reaction_date is null
	"



    }

    # Write Audit Trail
    im_audit -object_id $ticket_id -action after_update

}

ad_returnredirect $return_url
