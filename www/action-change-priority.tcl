# /packages/intranet-helpdesk/www/action-change-priority.tcl
#
# Copyright (C) 2003-2012 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_page_contract {

    @author klaus.hofeditz@project-open.com
} {
    { tid ""}
    { ticket_ids {} }
    action_id:integer
    { ticket_id_from_search:integer "" }
    { return_url "/intranet-helpdesk/index" }
}

# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------

set current_user_id [auth::require_login]
set ticket_ids [list]
set page_title [lang::message::lookup "" intranet-helpdesk.Title_Change_Prio "Change Ticket Prio"]

set hidden_tid_html ""
foreach ticket_id $tid {
    lappend ticket_ids $ticket_id
    append hidden_tid_html "<input type='hidden' name='tid' value='$ticket_id'>\n"
}



set ticket_ids_csv [join $ticket_ids ","] 

set sql "
	select 	p.project_name,
		t.ticket_prio_id
	from 	im_projects p,
		im_tickets t
	where 	project_id in ($ticket_ids_csv) and 
		t.ticket_id = p.project_id
"

set ticket_list_html "<ul>"
db_foreach ticket $sql {
    append ticket_list_html "<li>${project_name} - Prio: [im_category_from_id $ticket_prio_id] </li>"
}
append ticket_list_html "</ul>"

set select_box [im_category_select_plain "Intranet Ticket Priority" "ticket_prio"]

# set form_action "[export_vars -base action-change-priority-2 {tid return_url]}"
set form_action "action-change-priority-2"
