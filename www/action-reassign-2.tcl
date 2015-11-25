# /packages/intranet-helpdesk/www/action-reassign-2.tcl
#
# Copyright (C) 2003-2008 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_page_contract {

    @param tid The list of ticket_id's 
    @author klaus.hofeditz@project-open.com
} {
    { tid:integer,multiple {}}
    { ticket_ids "" }
    { ticket_assignee_id "" }
    { return_url "/intranet-helpdesk/index" }
}

# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------

set current_user_id [auth::require_login]
set page_title [lang::message::lookup "" intranet-helpdesk.Title_Reassign_Ticket "Reassign Ticket"]

if {"" == $ticket_assignee_id} {
    ad_return_complaint 1  [lang::message::lookup "" intranet-helpdesk.Please_Provide_Ticket_Assignee "Please Select Ticket Assignee"]
}

set err_msg ""
foreach ticket_id $tid {

    im_ticket::audit -ticket_id $ticket_id -action "before_update"
    if {[catch {
	db_dml update_ticket_assignee "update im_tickets set ticket_assignee_id = :ticket_assignee_id where ticket_id = :ticket_id"

	# Also add the new guy as a member of the ticket
	im_biz_object_add_role $ticket_assignee_id $ticket_id 1300

    } err_msg]} {
	set msg [lang::message::lookup "" intranet-helpdesk.Change_Assignee_Problems "We found problems while updating the ticket_assignee_id"]
	ad_return_complaint 1 "$msg:<br>$err_msg"
	break
    }
    im_ticket::audit -ticket_id $ticket_id -action "after_update"
}

set fb_msg [lang::message::lookup "" intranet-helpdesk.Reassigned_Msg "The ticket(s) have been reassigned."]
ad_returnredirect -message $fb_msg $return_url
