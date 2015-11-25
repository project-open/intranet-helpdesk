# /packages/intranet-helpdesk/www/reporting/ticket-by-customer-dept.tcl
#
# Copyright (c) 2003-2008 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/ for licensing details.


ad_page_contract {
    Shows the results of the evaluated users
} {
    { report_start_date "" }
    { report_end_date "" }
    { report_level_of_detail 2 }
    { report_output_format "html" }
    { report_sla_id "" }
    { report_status_id [im_ticket_status_open] }
    { report_type_id "" }
    { report_prio_id "" }
    { report_queue_id "" }
    { report_assignee_id "" }
    { report_assignee_dept_id "943830" }
    { report_message_substring_len 200 }
}

# ------------------------------------------------------------
# Security
# ------------------------------------------------------------

set menu_label "reporting_helpdesk_ticket_by_customer_dept"
set current_user_id [auth::require_login]
set read_p [db_string report_perms "
	select	im_object_permission_p(m.menu_id, :current_user_id, 'read')
	from	im_menus m
	where	m.label = :menu_label
" -default 'f']

set read_p "t"
if {"t" ne $read_p } {
    ad_return_complaint 1 "<li>
    [lang::message::lookup "" intranet-reporting.You_dont_have_permissions "You don't have the necessary permissions to view this page"]"
    return
}

set page_title "Tickets by Customer Contact Department"
set context_bar [im_context_bar $page_title]
set context ""

# Check Date formats
set report_start_date [string range $report_start_date 0 9]
if {"" != $report_start_date && ![regexp {^[0-9][0-9][0-9][0-9]\-[0-9][0-9]\-[0-9][0-9]$} $report_start_date]} {
    ad_return_complaint 1 "Start Date doesn't have the right format.<br>
    Current value: '$report_start_date'<br>
    Expected format: 'YYYY-MM-DD'"
}

set report_end_date [string range $report_end_date 0 9]
if {"" != $report_end_date && ![regexp {^[0-9][0-9][0-9][0-9]\-[0-9][0-9]\-[0-9][0-9]$} $report_end_date]} {
    ad_return_complaint 1 "Start Date doesn't have the right format.<br>
    Current value: '$report_end_date'<br>
    Expected format: 'YYYY-MM-DD'"
}

if {![string is integer $report_message_substring_len]} {
    set report_message_substring_len 200
}



# ------------------------------------------------------------
# Defaults
# ------------------------------------------------------------

set days_in_future 31
db_1row todays_date "
select
	to_char(sysdate::date, 'YYYY') as todays_year,
	to_char(sysdate::date, 'MM') as todays_month,
	to_char(sysdate::date + :days_in_future::integer, 'YYYY') as next_month_year,
	to_char(sysdate::date + :days_in_future::integer, 'MM') as next_month_month
from dual
"

if {"" == $report_start_date} { set report_start_date "$todays_year-$todays_month-01" }
if {"" == $report_end_date} { set report_end_date "$next_month_year-$next_month_month-01" }

set ticket_url "/intranet-helpdesk/new?form_mode=display&ticket_id="
set project_url "/intranet/projects/view?project_id="
set user_url "/intranet/users/view?user_id="
set this_url [export_vars -base "/intranet-helpdesk/reporting/ticket-by-customer-dept" {report_start_date} ]
set levels {1 "Main Dept" 2 "Main Dept + Tickets" 3 "Main Dept + Tickets + Discussions"} 


# ------------------------------------------------------------
# Conditional SQL Where-Clause
#

set criteria [list]

if {"" != $report_start_date} { lappend criteria "t.ticket_creation_date >= :report_start_date::timestamptz" }
if {"" != $report_end_date} { lappend criteria "t.ticket_creation_date <= :report_end_date::timestamptz" }
if {"" != $report_sla_id} { lappend criteria "p.parent_id = :report_sla_id" }
if {"" != $report_queue_id} { lappend criteria "t.ticket_queue_id = :report_queue_id" }
if {"" != $report_assignee_id} { lappend criteria "t.ticket_assignee_id = :report_assignee_id" }

if {"" != $report_status_id} { lappend criteria "t.ticket_status_id in ([join [im_sub_categories $report_status_id] ","])" }
if {"" != $report_type_id} { lappend criteria "t.ticket_type_id in ([join [im_sub_categories $report_type_id] ","])" }
if {"" != $report_prio_id} { lappend criteria "t.ticket_prio_id in ([join [im_sub_categories $report_prio_id] ","])" }

if {"" != $report_assignee_dept_id} {
    set cc_code [db_string cc_code "select cost_center_code from im_cost_centers where cost_center_id = :report_assignee_dept_id" -default ""]
    set cc_len [string length $cc_code]
    lappend criteria "t.ticket_assignee_id in (
	select e.employee_id
	from   im_employees e
	where  e.department_id in (
	       select	cc.cost_center_id
	       from	im_cost_centers cc
	       where	substring(cc.cost_center_code for :cc_len) = :cc_code
	)
)" }

set where_clause [join $criteria " and\n            "]
if { $where_clause ne "" } {
    set where_clause " and $where_clause"
}



# ------------------------------------------------------------
# Calculate the ticket_first_discussion_topic_id_lazy_cached
# for those tickets that have not yet been calculated
#
db_dml first_discussion_topic "
update im_tickets
set ticket_first_discussion_topic_id_lazy_cached = (select min(topic_id) from im_forum_topics ft where ft.object_id = ticket_id)
where ticket_first_discussion_topic_id_lazy_cached is null
"

# ------------------------------------------------------------
# Define the report - SQL, counters, headers and footers 
#

set sql "
select	t.*,
	coalesce(im_cost_center_code_from_id(customer_contact_dept_id), 'undefined') as customer_contact_dept_code,
	coalesce(im_cost_center_name_from_id(customer_contact_dept_id), 'Tickets with no customer contact') as customer_contact_dept_name,
	trim(substring(ticket_prio for 2)) as ticket_prio_substring
from	(
	select
		child.tree_sortkey as child_tree_sortkey,
		child.*,
		substring(child.message for :report_message_substring_len) as message_substring,
		t.*,
		p.*,
		p.project_name as ticket_name,
		p.project_nr as ticket_nr,
		o.creation_user as ticket_creation_user_id,
		p.parent_id as ticket_sla_id,
		acs_object__name(p.parent_id) as ticket_sla_name,
		im_name_from_user_id(t.ticket_customer_contact_id) as ticket_customer_contact_name,
		im_name_from_user_id(t.ticket_assignee_id) as ticket_assignee_name,
		coalesce((select department_id from im_employees where employee_id = t.ticket_customer_contact_id), 0) as customer_contact_dept_id,
		im_category_from_id(t.ticket_status_id) as ticket_status,
		im_category_from_id(t.ticket_type_id) as ticket_type,
		im_category_from_id(t.ticket_prio_id) as ticket_prio,
		to_char(t.ticket_creation_date, 'YYYY-MM-DD') as ticket_creation_date_pretty,
		im_name_from_user_id(o.creation_user) as creation_user_name,
		im_name_from_user_id(o.creation_user) as ticket_creation_user_name,
		acs_object__name(t.ticket_queue_id) as ticket_queue
	from
		acs_objects o,
		im_projects p,
		im_tickets t
		LEFT OUTER JOIN im_forum_topics parent ON parent.topic_id = t.ticket_first_discussion_topic_id_lazy_cached,
		im_forum_topics child
	where
		t.ticket_id = p.project_id and
		t.ticket_id = o.object_id and
		child.tree_sortkey between parent.tree_sortkey and tree_right(parent.tree_sortkey)
		$where_clause
	) t
order by
	customer_contact_dept_code,
	ticket_prio,
	ticket_name,
	child_tree_sortkey
"

# ---------------------------------------------
# Report Definition


set report_def [list \
	group_by customer_contact_dept_code \
	header {
		"\#colspan=99 <b>$customer_contact_dept_code - $customer_contact_dept_name</b>"
	} \
	content [list  \
		group_by ticket_nr \
		header {
		        $customer_contact_dept_code
			"<a href=$ticket_url$ticket_id target=_blank>$ticket_nr</a>"
		        $ticket_prio_substring
		        $ticket_type
		        $ticket_status
		        $ticket_queue
		        "<a href=$project_url$ticket_sla_id target=_blank>$ticket_sla_name</a>"
		        "<a href=$user_url$ticket_assignee_id target=_blank>$ticket_assignee_name</a>"
		        "<a href=$user_url$ticket_customer_contact_id target=_blank>$ticket_customer_contact_name</a>"
			"<a href=$ticket_url$ticket_id target=_blank>$ticket_name</a>"
		} \
		content [list \
			header {
			    "\#colspan=99 $message_substring"
			} \
			content {} \
		] \
		footer { } \
	] \
	footer {} \
]


# Global header/footer
set header0 {"Cust<br>Dept" "Nr" "Prio" "Type" "Status" "Queue" "SLA" "Assignee" "Contact" "Ticket"}
set footer0 {"" "" "" "" "" "" "" ""}

set tickets_per_dept_counter [list \
        pretty_name Tickets \
        var tickets_per_dept_subtotal \
        reset \$customer_contact_dept_id \
        expr 1 \
]

set counters [list ]



# ------------------------------------------------------------
# Start formatting the page
#

# Write out HTTP header, considering CSV/MS-Excel formatting
im_report_write_http_headers -output_format $report_output_format

# Add the HTML select box to the head of the page
switch $report_output_format {
    html {
        ns_write "
	[im_header]
	[im_navbar]
	<form>
		<table border=0 cellspacing=1 cellpadding=1>
		<tr>
		  <td class=form-label>Level of Details</td>
		  <td class=form-widget>
		    [im_select -translate_p 0 report_level_of_detail $levels $report_level_of_detail]
		  </td>
		</tr>
		<tr>
		  <td class=form-label>Start Date</td>
		  <td class=form-widget>
		    <input type=textfield name=report_start_date value=$report_start_date>
		  </td>
		</tr>
		<tr>
		  <td class=form-label>End Date</td>
		  <td class=form-widget>
		    <input type=textfield name=report_end_date value=$report_end_date>
		  </td>
		</tr>
		<tr>
		  <td class=form-label>Ticket Type</td>
		  <td class=form-widget>
		    [im_category_select -package_key "intranet-helpdesk" -include_empty_p 1 -include_empty_name "All" "Intranet Ticket Type" report_type_id $report_type_id]
		  </td>
		</tr>
		<tr>
		  <td class=form-label>Ticket Status</td>
		  <td class=form-widget>
		    [im_category_select -package_key "intranet-helpdesk" -include_empty_p 1 -include_empty_name "All" "Intranet Ticket Status" report_status_id $report_status_id]
		  </td>
		</tr>
		<tr>
		  <td class=form-label>Customer Contact Dept</td>
		  <td class=form-widget>
		    [im_cost_center_select report_assignee_dept_id $report_assignee_dept_id]
		  </td>
		</tr>
		<tr>
		  <td class=form-label>Discussions Message Length</td>
		  <td class=form-widget>
		    <input type=textfield name=report_message_substring_len value=$report_message_substring_len size=6>
		  </td>
		</tr>

                <tr>
                  <td class=form-label>Format</td>
                  <td class=form-widget>
                    [im_report_output_format_select report_output_format "" $report_output_format]
                  </td>
                </tr>
		<tr>
		  <td class=form-label></td>
		  <td class=form-widget><input type=submit value=Submit></td>
		</tr>
		</table>
	</form>
	<table border=0 cellspacing=1 cellpadding=1>\n"
    }
}

im_report_render_row \
    -output_format $report_output_format \
    -row $header0 \
    -row_class "rowtitle" \
    -cell_class "rowtitle"

set footer_array_list [list]
set last_value_list [list]
set class "rowodd"
db_foreach sql $sql {

    if {$report_message_substring_len == [string length $message_substring]} { append message_substring "..." }

    im_report_display_footer \
	-output_format $report_output_format \
	-group_def $report_def \
	-footer_array_list $footer_array_list \
	-last_value_array_list $last_value_list \
	-level_of_detail $report_level_of_detail \
	-row_class $class \
	-cell_class $class
    
    im_report_update_counters -counters $counters
    
    set last_value_list [im_report_render_header \
			     -output_format $report_output_format \
			     -group_def $report_def \
			     -last_value_array_list $last_value_list \
			     -level_of_detail $report_level_of_detail \
			     -row_class $class \
			     -cell_class $class
			]

    set footer_array_list [im_report_render_footer \
			       -output_format $report_output_format \
			       -group_def $report_def \
			       -last_value_array_list $last_value_list \
			       -level_of_detail $report_level_of_detail \
			       -row_class $class \
			       -cell_class $class
			  ]
}

im_report_display_footer \
    -output_format $report_output_format \
    -group_def $report_def \
    -footer_array_list $footer_array_list \
    -last_value_array_list $last_value_list \
    -level_of_detail $report_level_of_detail \
    -display_all_footers_p 1 \
    -row_class $class \
    -cell_class $class

im_report_render_row \
    -output_format $report_output_format \
    -row $footer0 \
    -row_class $class \
    -cell_class $class


switch $report_output_format {
    html { ns_write "</table>\n[im_footer]\n" }
}
