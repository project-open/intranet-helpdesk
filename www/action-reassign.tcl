# /packages/intranet-helpdesk/www/action-reassign.tcl
#
# Copyright (C) 2003-2014 ]project-open[
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
set page_title [lang::message::lookup "" intranet-helpdesk.Title_Reassign "Reassign Tickets"]
if {1 == [llength $tid]} { set tid [lindex $tid 0] }

set hidden_tid_html ""
foreach ticket_id $tid {
    lappend ticket_ids $ticket_id
    append hidden_tid_html "<input type='hidden' name='tid' value='$ticket_id'>\n"
}

set no_assignee_l10n [lang::message::lookup "" intranet-helpdesk.No_Assignee_None "<none>"]
set ticket_ids_csv [join $ticket_ids ","] 
set sql "
	select	p.project_name,
		coalesce(acs_object__name(t.ticket_assignee_id), :no_assignee_l10n) as ticket_assignee_name
	from	im_projects p,
		im_tickets t
	where	project_id in ($ticket_ids_csv) and 
		t.ticket_id = p.project_id
"

set current_assignee_l10n [lang::message::lookup "" intranet-helpdesk.Current_Assignee "Current Assignee"]
set ticket_list_html "<ul>"
db_foreach ticket $sql {
    append ticket_list_html "<li>${project_name} - Current Assignee: $ticket_assignee_name </li>"
}
append ticket_list_html "</ul>"

# -------------------------------------------------
# Get the value range SQL from DynFields

db_1row dynfield_info "
	select	parameters as widget_parameters
	from	im_dynfield_widgets
	where	widget_name = 'ticket_assignees'
"

# ad_return_complaint 1 "'$widget_parameters'"

array set widget_parameter_hash [lindex $widget_parameters 0]
set widget_custom $widget_parameter_hash(custom)
array set widget_custom_hash $widget_custom
set widget_sql $widget_custom_hash(sql)

# The resulting SQL returns two columns:
# Col1: object_id (user_id)
# Col2: object_name (user name)
set select_box "<select name=ticket_assignee_id>\n"
append select_box "<option value>[_ "intranet-core.--_Please_select_--"]</option>\n"
set ticket_assignee_options [db_list_of_lists ticket_assignees $widget_sql]
foreach assig $ticket_assignee_options {
    set user_id [lindex $assig 0]
    set user_name [lindex $assig 1]
    append select_box "<option value=\"$user_id\">$user_name</option>\n"
}
append select_box "</select>\n"    

# set form_action [export_vars -base action-reassign-2 {tid return_url}]
set form_action "action-reassign-2"
