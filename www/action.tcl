# /packages/intranet-helpdesk/www/action.tcl
#
# Copyright (C) 2003-2008 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_page_contract {
    Perform bulk actions on tickets
    
    @action_id	One of "Intranet Ticket Action" categories.
    		Determines what to do with the list of "tid"
		ticket ids.
		The "aux_string1" field of the category determines
		the page to be called for pluggable actions.

    @param return_url the url to return to
    @author frank.bergmann@project-open.com
} {
    { tid:multiple ""}
    action_id:integer
    return_url
}

set user_id [auth::require_login]
set user_is_admin_p [im_is_user_site_wide_or_intranet_admin $user_id]
set user_name [im_name_from_user_id [ad_conn user_id]]

# 30500, 'Close'
# 30510, 'Close &amp; notify'
# 30520, 'Duplicated'
# 30060, 'Resolved'
# 30590, 'Delete'
# 30599, 'Nuke'

# Deal with funky input parameter combinations
if {"" == $action_id} { ad_returnredirect $return_url }
if {0 == [llength $tid]} { ad_returnredirect $return_url }
if {1 == [llength $tid]} { set tid [lindex $tid 0] }

set action_name [im_category_from_id $action_id]
set action_forbidden_msg [lang::message::lookup "" intranet-helpdesk.Action_Forbidden "<b>Unable to execute action</b>:<br>You don't have the permissions to execute the action '%action_name%' on this ticket."]

# ------------------------------------------
# Check the TCL that determines the visibility of the action
set visible_tcl [util_memoize [list db_string visible_tcl "select visible_tcl from im_categories where category_id = $action_id"]]
set visible_p 0
set visible_explicite_permission_p 0
if {"" == $visible_tcl} {
    # Not specified - User is allowed to execute but normal permissions apply
    set visible_p 1
} else {
    # Explicitely specified: Check TCL
    if {[eval $visible_tcl]} {
	set visible_p 1
	set visible_explicite_permission_p 1
    }
}

# ------------------------------------------
# Perform the action on multiple tickets
switch $action_id {
	30500 - 30510 {
	    # Close and "Close & Notify"
	    foreach ticket_id $tid {
		im_ticket::audit			-ticket_id $ticket_id -action "before_update"
		if {!$visible_explicite_permission_p} {
		    im_ticket::check_permissions	-ticket_id $ticket_id -operation "write"
		}
		im_ticket::set_status_id		-ticket_id $ticket_id -ticket_status_id [im_ticket_status_closed]
		im_ticket::update_timestamp		-ticket_id $ticket_id -timestamp "done"
		im_ticket::close_workflow		-ticket_id $ticket_id
		im_ticket::close_forum			-ticket_id $ticket_id
		im_ticket::audit			-ticket_id $ticket_id -action "after_update"
	    }

	    if {$action_id == 30510} {
		# Close & Notify - Notify all stakeholders
		ad_returnredirect [export_vars -base "/intranet-helpdesk/notify-stakeholders" {tid action_id return_url}]
	    }
	}
	30530 - 30532 {
	    # Reopen
	    foreach ticket_id $tid {
		im_ticket::audit			-ticket_id $ticket_id -action "before_update"
		if {!$visible_explicite_permission_p} {
		    im_ticket::check_permissions	-ticket_id $ticket_id -operation "write"
		}
		im_ticket::set_status_id		-ticket_id $ticket_id -ticket_status_id [im_ticket_status_open]
		db_dml project_status_to_open "update im_projects set project_status_id = [im_project_status_open] where project_id = :ticket_id"
		im_ticket::audit			-ticket_id $ticket_id -action "after_update"
	    }

	    if {$action_id == 30532} {
		# Reopen & Notify - Notify all stakeholders
		ad_returnredirect [export_vars -base "/intranet-helpdesk/notify-stakeholders" {tid action_id return_url}]
	    }
	}
    	30534 {
            # Re-Assign
	    ad_returnredirect [export_vars -base "/intranet-helpdesk/action-reassign" {tid action_id return_url}]
        }
	30540 {
	    # Associate
	    ad_returnredirect [export_vars -base "/intranet-helpdesk/action-associate" {tid action_id return_url}]
	}
    	30545 {
            # Change Prio
	    ad_returnredirect [export_vars -base "/intranet-helpdesk/action-change-priority" {tid action_id return_url}]
        }
	30550 {
	    # Escalate
	    if {[llength $tid] > 1} { ad_return_complaint 1 [lang::message::lookup "" intranet-helpdesk.Can_excalate_only_one_ticket "We can escalate only one ticket at a time" ] }
	    ad_returnredirect [export_vars -base "/intranet-helpdesk/new" {{escalate_from_ticket_id $tid}}]
	}
	30552 {
	    # Close Escalated Tickets
	    set escalated_tickets [db_list escalated_tickets "
		select	t.ticket_id
		from	im_tickets t,
			acs_rels r,
			im_ticket_ticket_rels ttr
		where	r.rel_id = ttr.rel_id and
			r.object_id_one in ([join $tid ","]) and
			r.object_id_two = t.ticket_id
	    "]

	    # Redirect to this page, but with Action=Close (30500) to close the escalated tickets
	    ad_returnredirect [export_vars -base "/intranet-helpdesk/action" {{action_id 30500} {tid $escalated_tickets} return_url}]
	}
	30560 {
	    # Resolved
	    foreach ticket_id $tid {
		im_ticket::audit			-ticket_id $ticket_id -action "before_update"

		# Allow customers to mark a ticket as "resolved" even if they don't have write permissions normally
		db_1row ticket_info "
			select	coalesce(ticket_customer_contact_id,0) as ticket_customer_contact_id,
				(select	count(*)
				from	acs_rels r
				where	r.object_id_one = p.company_id and
					r.object_id_two = :user_id
				) as customer_company_member_p
			from	im_tickets t,
				im_projects p
			where	t.ticket_id = p.project_id and
				t.ticket_id = :ticket_id
		"
		set customer_p [expr {$ticket_customer_contact_id == $user_id || $customer_company_member_p > 0}]

		if {!$customer_p && !$visible_explicite_permission_p} {
		    im_ticket::check_permissions	-ticket_id $ticket_id -operation "write"
		}
		im_ticket::set_status_id		-ticket_id $ticket_id -ticket_status_id [im_ticket_status_resolved]
		im_ticket::update_timestamp		-ticket_id $ticket_id -timestamp "done"
		im_ticket::audit			-ticket_id $ticket_id -action "after_update"
	    }
	}
	30590 {
	    # Delete
	    foreach ticket_id $tid {
		im_ticket::audit			-ticket_id $ticket_id -action "before_update"
		if {!$visible_explicite_permission_p} {
		    im_ticket::check_permissions	-ticket_id $ticket_id -operation "write"
		}
		im_ticket::set_status_id		-ticket_id $ticket_id -ticket_status_id [im_ticket_status_deleted]
		im_ticket::close_workflow		-ticket_id $ticket_id
		im_ticket::close_forum			-ticket_id $ticket_id
		im_ticket::audit			-ticket_id $ticket_id -action "after_update"
	    }
	}
	30599 {
	    # Nuke
	    if {!$user_is_admin_p} { 
	        ad_return_complaint 1 "User needs to be SysAdmin in order to 'Nuke' tickets.<br>Please use 'Delete' otherwise." 
		ad_script_abort
	    }
	    foreach ticket_id $tid {
		im_ticket::audit			-ticket_id $ticket_id -action "before_nuke"
	        im_ticket::check_permissions		-ticket_id $ticket_id -operation "admin"
		im_project_nuke $ticket_id
	    }

	    # Ticket may not exist anymore, return to ticket list
	    if {[regexp {^\/intranet-helpdesk\/new} $return_url match]} {
		set return_url "/intranet-helpdesk/"
	    }
	}
	default {
	    # Check if we've got a custom action to perform
	    set redirect_base_url [db_string redir "select aux_string1 from im_categories where category_id = :action_id" -default ""]
	    if {"" != [string trim $redirect_base_url]} {
		# Redirect for custom action
		set redirect_url [export_vars -base $redirect_base_url {action_id return_url}]
		foreach ticket_id $tid { append redirect_url "&tid=$ticket_id"}
		ad_returnredirect $redirect_url
	    } else {
		ad_return_complaint 1 "Unknown Ticket action: $action_id='[im_category_from_id $action_id]'"
	    }
	}
    }


ad_returnredirect $return_url
