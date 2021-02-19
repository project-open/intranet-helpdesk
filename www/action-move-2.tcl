# /packages/intranet-helpdesk/www/action-move-2.tcl
#
# Copyright (C) 2003-2008 ]project-open[
#
# All rights reserved. Please check
# https://www.project-open.com/license/ for details.

ad_page_contract {

    @param tid The list of ticket_id's 
    @author klaus.hofeditz@project-open.com
} {
    { tid:integer,multiple {}}
    { ticket_container_id "" }
    { return_url "/intranet-helpdesk/index" }
}

# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------

set current_user_id [auth::require_login]
set page_title [lang::message::lookup "" intranet-helpdesk.Title_Move_Ticket "Move Ticket"]

if {"" == $ticket_container_id} {
    ad_return_complaint 1  [lang::message::lookup "" intranet-helpdesk.Please_Provide_Ticket_Container "Please Select Ticket Container"]
}

set err_msg ""
foreach ticket_id $tid {

    im_ticket::audit -ticket_id $ticket_id -action "before_update"
    if {[catch {
	db_dml update_ticket_container "update im_projects set parent_id = :ticket_container_id where project_id = :ticket_id"
    } err_msg]} {
	set msg [lang::message::lookup "" intranet-helpdesk.Change_Container_Problems "We found problems while updating the ticket container"]
	ad_return_complaint 1 "$msg:<br>$err_msg"
	break
    }
    im_ticket::audit -ticket_id $ticket_id -action "after_update"
}

set fb_msg [lang::message::lookup "" intranet-helpdesk.Moved_Msg "The ticket(s) have been moved."]
ad_returnredirect -message $fb_msg $return_url
