# /packages/intranet-helpdesk/www/action-move.tcl
#
# Copyright (C) 2003-2014 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_page_contract {
    @author frank.bergmann@project-open.com
} {
    { tid:integer,multiple ""}
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
set page_title [lang::message::lookup "" intranet-helpdesk.Title_Move "Move Tickets"]
if {1 == [llength $tid]} { set tid [lindex $tid 0] }

set hidden_tid_html ""
foreach ticket_id $tid {
    lappend ticket_ids $ticket_id
    append hidden_tid_html "<input type='hidden' name='tid' value='$ticket_id'>\n"
}

set no_assignee_l10n [lang::message::lookup "" intranet-helpdesk.No_Assignee_None "<none>"]
set sql "
	select	p.project_name,
		coalesce(acs_object__name(t.ticket_assignee_id), :no_assignee_l10n) as ticket_assignee_name
	from	im_projects p,
		im_tickets t
	where	project_id in ([join $ticket_ids ","]) and 
		t.ticket_id = p.project_id
"

set ticket_list_html "<ul>"
db_foreach ticket $sql {
    append ticket_list_html "<li>${project_name} </li>"
}
append ticket_list_html "</ul>"

set select_box [im_project_select -project_type_id [im_project_type_ticket_container] ticket_container_id]

# set form_action [export_vars -base action-move-2 {tid return_url}]
set form_action "action-move-2"
