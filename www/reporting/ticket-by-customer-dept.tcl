
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
    { report_status_id "" }
    { report_type_id "" }
    { report_prio_id "" }
    { report_queue_id "" }
    { report_assignee_id "" }
    { report_assignee_dept_id "" }
}

# ------------------------------------------------------------
# Security
# ------------------------------------------------------------

set menu_label "reporting_helpdesk_ticket_by_customer_dept"
set current_user_id [ad_maybe_redirect_for_registration]
set read_p [db_string report_perms "
	select	im_object_permission_p(m.menu_id, :current_user_id, 'read')
	from	im_menus m
	where	m.label = :menu_label
" -default 'f']

set read_p "t"
if {![string equal "t" $read_p]} {
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


# ------------------------------------------------------------
# Defaults
# ------------------------------------------------------------

set days_in_future 31
db_1row todays_date "
select
	to_char(sysdate::date + :days_in_future::integer, 'YYYY') as todays_year,
	to_char(sysdate::date + :days_in_future::integer, 'MM') as todays_month
from dual
"

if {"" == $report_start_date} { set report_start_date "2015-01-01" }
if {"" == $report_end_date} { set report_end_date "$todays_year-$todays_month-01" }

set user_url "/intranet/users/view?user_id="
set this_url [export_vars -base "/intranet-helpdesk/reporting/ticket-by-customer-dept" {report_start_date} ]
set levels {2 "Evaluees + Evaluators"} 


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
    set cc_code [db_string cc_code "select cost_center_code from im_cost_centers where cost_center_id = :report_cost_center" -default ""]
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
if { ![empty_string_p $where_clause] } {
    set where_clause " and $where_clause"
}



# ------------------------------------------------------------
# Define the report - SQL, counters, headers and footers 
#

set sql "
select	t.*,
	substring(customer_contact_dept for 2) as customer_contact_dept_2char,
	substring(customer_contact_dept for 4) as customer_contact_dept_4char
from	(
	select
		child.tree_sortkey as child_tree_sortkey,
		child.*,
		t.*,
		p.*,
		p.project_name as ticket_name,
		p.project_nr as ticket_nr,
		o.creation_user as ticket_creation_user_id,
		im_name_from_user_id(t.ticket_customer_contact_id) as customer_contact_name,
		(select im_cost_center_code_from_id(department_id) from im_employees 
		 where employee_id = t.ticket_customer_contact_id
		) as customer_contact_dept,
		im_category_from_id(t.ticket_status_id) as ticket_status,
		im_category_from_id(t.ticket_type_id) as ticket_type,
		im_category_from_id(t.ticket_prio_id) as ticket_prio,
		to_char(t.ticket_creation_date, 'YYYY-MM-DD') as ticket_creation_date_pretty,
		im_name_from_user_id(o.creation_user) as creation_user_name,
		im_name_from_user_id(o.creation_user) as ticket_creation_user_name,
		im_name_from_user_id(o.creation_user) as ticket_creation_user_name,
		acs_object__name(t.ticket_queue_id) as ticket_queue
	from
		im_forum_topics parent,
		im_forum_topics child,
		im_tickets t,
		im_projects p,
		acs_objects o
	where
		t.ticket_id = p.project_id and
		t.ticket_id = o.object_id and
		parent.topic_id = (select min(topic_id) from im_forum_topics ft where ft.object_id = t.ticket_id) and
		child.tree_sortkey between parent.tree_sortkey and tree_right(parent.tree_sortkey)
		$where_clause
	) t
order by
	customer_contact_dept_4char,
	ticket_name,
	child_tree_sortkey
"

# ---------------------------------------------
# Report Definition


set report_def [list \
	group_by customer_contact_dept_2char \
	header {
		"\#colspan=99 <b>$customer_contact_dept</b>"
	} \
	content [list  \
		group_by ticket_nr \
		header {
			$ticket_nr
		        $ticket_name
		} \
		content [list \
			header {
				$topic_name
				$subject
			} \
			content {} \
		] \
	] \
	footer {
		$customer_contact_dept
	} \
]


# Global header/footer
set header0 {"Nr" "Ticket"}
set footer0 {"" "" "" "" "" "" "" ""}

set counters [list]

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
