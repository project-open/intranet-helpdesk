# /packages/intranet-helpdesk/www/new.tcl
#
# Copyright (c) 2003-2008 ]project-open[
#
# All rights reserved. Please check
# https://www.project-open.com/license/ for details.

# -----------------------------------------------------------
# Page Head
#
# There are two different heads, depending whether it's called
# "standalone" (TCL-page) or as a Workflow Panel.
# -----------------------------------------------------------

# Skip if this page is called as part of a Workflow panel
if {![info exists task]} {

    ad_page_contract {
	@author frank.bergmann@project-open.com
    } {
	ticket_id:integer,optional
	{ ticket_name "" }
	{ ticket_nr "" }
	{ ticket_sla_id "" }
	{ ticket_customer_contact_id "" }
	{ task_id "" }
	message:optional
	{ ticket_status_id "" }
	{ ticket_type_id "" }
	{ return_url "/intranet-helpdesk/" }
	{ vars_from_url ""}
	{ plugin_id:integer "" }
	{ view_name "ticket_list"}
	{ mine_p "all" }
	{ form_mode "edit" }
	{ render_template_id:integer 0 }
	{ escalate_from_ticket_id 0 }
	{ format "html" }
    }

    set show_components_p 1
    set enable_master_p 1

} else {
    
    set task_id $task(task_id)
    set case_id $task(case_id)

    set vars_from_url ""
    set return_url [im_url_with_query]

    set ticket_id [db_string pid "select object_id from wf_cases where case_id = :case_id" -default ""]
    set transition_key [db_string transition_key "select transition_key from wf_tasks where task_id = :task_id"]
    set task_page_url [export_vars -base [ns_conn url] { ticket_id task_id return_url}]

    set show_components_p 0
    set enable_master_p 0
    set ticket_type_id ""
    set ticket_sla_id ""
    set ticket_customer_contact_id ""

    set plugin_id ""
    set view_name "standard"
    set mine_p "all"

    set render_template_id 0
    set escalate_from_ticket_id 0
    set format "html"

    ad_returnredirect [export_vars -base "/intranet-helpdesk/new" { {ticket_id $task(object_id)} {form_mode display}} ]
}

# ------------------------------------------------------------------
# Security
# ------------------------------------------------------------------

set current_user_id [auth::require_login]
set user_id $current_user_id
set current_url [im_url_with_query]
set action_url "/intranet-helpdesk/new"
set focus "ticket.var_name"

if {[info exists ticket_id] && "" == $ticket_id} { unset ticket_id }


set user_admin_p [im_is_user_site_wide_or_intranet_admin $current_user_id]
set add_projects_p [im_permission $current_user_id "add_projects"]
set add_tickets_p [im_permission $current_user_id "add_tickets"]
set add_companies_p [im_permission $current_user_id "add_companies"]
set add_users_p [im_permission $current_user_id "add_users"]
set add_tickets_for_customers_p [im_permission $current_user_id add_tickets_for_customers]
set view_tickets_all_p [im_permission $current_user_id "view_tickets_all"]
set edit_tickets_all_p [im_permission $current_user_id "edit_tickets_all"]
set edit_ticket_status_p [im_permission $current_user_id edit_ticket_status]

# Can the current user create new helpdesk customers?
# The list of user groups that can be managed by the current user
set user_can_create_new_customer_contact_p 0
set managable_profiles [im_profile::profile_options_managable_for_user $current_user_id]
foreach tuple $managable_profiles {
    set gid [lindex $tuple 1]
    if {$gid == [im_profile_customers]} { set user_can_create_new_customer_contact_p 1 }
}
if {!$add_users_p} { set user_can_create_new_customer_contact_p 0 }

# Determine permission for the ticket.
# Consider the case that we are creating a new ticket which doesn't exist in the DB yet.
set view_p 1
set read_p 1
set write_p 1
set admin_p 1
set ticket_exists_p 0
if {[info exists ticket_id]} {
    set ticket_exists_p [db_string exists_p "select count(*) from im_tickets where ticket_id = :ticket_id"]
    if {$ticket_exists_p} {
	im_ticket_permissions $user_id $ticket_id view_p read_p write_p admin_p
    }
}

# Decisions taken:
#
# - Read the current ticket? - read_p
# - Create a new ticket? - add_tickets_p - add_tickets_p
# - Modify an existing ticket? - write_p
# - Show "Edit" button in DISPLAY mode - write_p - ???
# - Allow the current user to create a ticket in the name of a customer? - add_tickets_for_customers_p
# - Allow to nuke - Admin
# - Show the various ticket actions
# - Can the user create a new SLA? - add_projects_p
# - Can the user create a new customer contact? - user_can_create_new_customer_contact_p
# - Can the user create a new customer company? - add_companies_p
# - Can the user edit the status of an existing ticket? - edit_ticket_status_p
# - 


# ------------------------------------------------------------------
# Default
# ------------------------------------------------------------------

# By default return to the existing ticket
# IF we are editing an existing ticket (ticket_id exists and is not empty)
if {[info exists ticket_id] && "" != $ticket_id} {
    set return_url [export_vars -base "/intranet-helpdesk/new" {ticket_id {form_mode display}} ]
}

set copy_from_ticket_name ""

# message_html allows us to add a warning popup etc.
set message_html ""

if {![info exists ticket_status_id] || "" == $ticket_status_id} {
    set ticket_status_id [im_parameter -package_id [im_package_helpdesk_id] DefaultNewTicketStatus "" [im_ticket_status_open]]
}


# ------------------------------------------------------------------
# Create ticket as a copy of another ticket.
# Get SLA and type if we are copying data from an existing ticket
# ------------------------------------------------------------------

if {0 != $escalate_from_ticket_id} {
    db_0or1row copy_ticket_info "
	select	p.project_name as copy_from_ticket_name,
		p.parent_id as ticket_sla_id,
		t.ticket_type_id
	from	im_tickets t,
		im_projects p
	where	t.ticket_id = p.project_id and
		t.ticket_id = :escalate_from_ticket_id
    "

    # Escalation logic: The new ticket is always a "probem ticket" (or below)
    set ticket_type_id [im_ticket_type_generic_problem_ticket]
}


# ----------------------------------------------
# Page Title


set page_title [lang::message::lookup "" intranet-helpdesk.New_Ticket "New Ticket"]
if {([info exists ticket_id] && $ticket_id ne "")} {
    set page_title [db_string title "select project_name from im_projects where project_id = :ticket_id" -default ""]
}
if {0 != $escalate_from_ticket_id} {
    set page_title [lang::message::lookup "" intranet-helpdesk.New_Problem_Ticket_from "New Problem Ticket from '%copy_from_ticket_name%'"]
}
if {"" == $page_title && 0 != $ticket_type_id} { 
    set ticket_type [im_category_from_id $ticket_type_id]
    set page_title [lang::message::lookup "" intranet-helpdesk.New_TicketType "New %ticket_type%"]
} 

set context [list $page_title]


# ----------------------------------------------
# Determine ticket type

# We need the ticket_type_id for page title, dynfields etc.
# Check if we can deduce the ticket_type_id from ticket_id
if {0 == $ticket_type_id || "" == $ticket_type_id} {
    if {([info exists ticket_id] && $ticket_id ne "")} { 
	set ticket_type_id [db_string ttype_id "select ticket_type_id from im_tickets where ticket_id = :ticket_id" -default 0]
    }
}

# ----------------------------------------------
# Calculate form_mode

if {"edit" == [template::form::get_action helpdesk_action]} { set form_mode "edit" }
if {![info exists ticket_id]} { set form_mode "edit" }
if {![info exists form_mode]} { set form_mode "display" }

if {[info exists ticket_id]} {
    if {!$read_p} {
	ad_return_complaint 1 [lang::message::lookup "" intranet-helpdesk.No_right_to_read_ticket "You don't have the permission to see this ticket."]
	ad_script_abort
    }
    if {!$write_p} {
	set form_mode "display"
    }
}

# Check if the user is allowed to create a new ticket
if {"edit" == $form_mode && ![info exists ticket_id]} {
    if {!$add_tickets_p} {
	ad_return_complaint 1 [lang::message::lookup "" intranet-helpdesk.No_right_to_create_new_ticket "You don't have the permission to create a new ticket."]
	ad_script_abort
    }
}

# Show the ADP component plugins?
if {"edit" == $form_mode} { set show_components_p 0 }

set ticket_exists_p 0
if {([info exists ticket_id] && $ticket_id ne "")} {
    # Check if the ticket exists
    set ticket_exists_p [db_string ticket_exists_p "select count(*) from im_tickets where ticket_id = :ticket_id"]

    # Write Audit Trail
    im_audit -object_id $ticket_id -action before_update

}

# Check if the ticket was changed recently by another user
if {"edit" == $form_mode && [info exists ticket_id]} {
    set exists_p [db_0or1row recently_changed "
	select	(now() - lock_date)::interval as lock_interval,
		trunc(extract(epoch from now() - lock_date))::integer % 60 as lock_seconds,
		trunc(extract(epoch from now() - lock_date) / 60.0)::integer as lock_minutes,
		lock_user,
		im_name_from_user_id(lock_user) as lock_user_name,
		lock_ip
	from	im_biz_objects
	where	object_id = :ticket_id
    "]

    # Check that we've found the value
    if {$exists_p && "" != $lock_user} {

	# Write out a warning if the ticket was modified by a different
	# user in the last 10 minutes
	set max_lock_seconds [im_parameter -package_id [im_package_core_id] LockMaxLockSeconds "" 600]
	set max_lock_seconds [im_parameter -package_id [im_package_helpdesk_id] LockMaxLockSeconds "" $max_lock_seconds]
	if {$lock_seconds < $max_lock_seconds && $lock_user != $current_user_id} {
	    
	    set msg [lang::message::lookup "" intranet-helpdesk.Ticket_Recently_Edited "This ticket was locked by %lock_user_name% %lock_minutes% minutes and %lock_seconds% seconds ago."]
	    set message_html "
		<script type=\"text/javascript\" nonce=\"[im_csp_nonce]\">
			alert('$msg');
		</script>
	    "

	}
    } else {
	# Set the lock on the ticket
	db_dml set_lock "
		update im_biz_objects set
			lock_ip = '[ns_conn peeraddr]',
			lock_date = now(),
			lock_user = :current_user_id
		where object_id = :ticket_id
	"
    }
}


# ---------------------------------------------
# The base form. Define this early so we can extract the form status
# ---------------------------------------------

set title_label [lang::message::lookup {} intranet-helpdesk.Name {Title}]
set title_help [lang::message::lookup {} intranet-helpdesk.Title_Help {Please enter a descriptive name for the new ticket.}]

set actions {}
if {$write_p} { lappend actions [list [lang::message::lookup {} intranet-helpdesk.Edit Edit] edit] }

ns_log Notice "new: ad_form: Setup fields"
ad_form \
    -name helpdesk_ticket \
    -action $action_url \
    -actions $actions \
    -has_edit 1 \
    -mode $form_mode \
    -export {next_url return_url escalate_from_ticket_id} \
    -form {
	ticket_id:key
	{ticket_name:text(text) {label $title_label} {html {size 50}}}
	{ticket_nr:text(hidden),optional }
	{start_date:date(hidden),optional }
	{end_date:date(hidden),optional }
    }

# ------------------------------------------------------------------
# User Extensible Ticket Actions
# ------------------------------------------------------------------

set tid [value_if_exists ticket_id]
set ticket_action_customize_html "<a href=[export_vars -base "/intranet/admin/categories/index" {{select_category_type "Intranet Ticket Action"}}]>[im_gif -translate_p 1 wrench "Custom Actions"]</a>"
if {!$user_admin_p} { set ticket_action_customize_html "" }

set ticket_action_select [im_category_select \
     -translate_p 1 \
     -plain_p 0 \
     -include_empty_p 0 \
     -include_empty_name "" \
     "Intranet Ticket Action" \
     action_id \
]

set action_l10n [lang::message::lookup "" intranet-helpdesk.Action "Action"]
set export_vars [export_vars -form {return_url tid}]
set ticket_action_html "
<form action=/intranet-helpdesk/action name=helpdesk_action>
$export_vars
$ticket_action_select
<input type=submit value='$action_l10n'>
$ticket_action_customize_html
</form>
"

# No write permissions - no actions...
if {!$write_p} { set ticket_action_html "" }


# ------------------------------------------------------------------
# Redirect if ticket_type_id or ticket_sla_id are missing
# ------------------------------------------------------------------

if {"edit" == $form_mode} {
    set redirect_p 0
    # redirect if ticket_type_id is not defined
    if {("" == $ticket_type_id || 0 == $ticket_type_id) && (![info exists ticket_id] || $ticket_id eq "")} {
	set all_same_p [im_dynfield::subtype_have_same_attributes_p -object_type "im_ticket"]
	set all_same_p 0
	if {!$all_same_p} { 
	    set redirect_p 1 
	}
    }

    # Redirect if the SLA hasn't been defined yet
    if {("" == $ticket_sla_id || 0 == $ticket_sla_id) && (![info exists ticket_id] || $ticket_id eq "")} { 
	set redirect_p 1 
    }

    # Redirect in order to define the SLA and the ticket type
    if {$redirect_p} {
	set new_typeselect_url_default "/intranet-helpdesk/new-typeselect"
	set new_typeselect_url [parameter::get_from_package_key -package_key "intranet-helpdesk" -parameter "NewTypeSelectUrl" -default $new_typeselect_url_default]
	if {"" == $new_typeselect_url} { set new_typeselect_url $new_typeselect_url_default }
	ad_returnredirect [export_vars -base $new_typeselect_url {{return_url $current_url} ticket_id ticket_type_id ticket_name ticket_nr ticket_sla_id}]
    }

}


# ------------------------------------------------------------------
# Get ticket_customer_id from information available in order to set options right
# ------------------------------------------------------------------

if {$ticket_exists_p} {
    db_1row ticket_info "
	select	t.*, p.*,
		t.ticket_customer_deadline::date as ticket_customer_deadline,
		p.company_id as ticket_customer_id,
		p.parent_id as ticket_sla_id_from_parent
	from	im_projects p,
		im_tickets t
	where	p.project_id = t.ticket_id
		and p.project_id = :ticket_id
    "
    set ticket_sla_id $ticket_sla_id_from_parent
}


# Check if we can get the ticket_customer_id.
# We need this field in order to limit the customer contacts to show.
if {(![info exists ticket_customer_id] || $ticket_customer_id eq "") && ([info exists ticket_sla_id] && $ticket_sla_id ne "") && "new" != $ticket_sla_id} {
    set ticket_customer_id [db_string cid "select company_id from im_projects where project_id = :ticket_sla_id" -default ""]
}


# ------------------------------------------------------------------
# Redirect for "New SLA" option
# ------------------------------------------------------------------

# Fetch variable values from the HTTP session and write to local variables
set url_vars_set [ns_conn form]
foreach var_from_url $vars_from_url {
    ad_set_element_value -element $var_from_url [im_opt_val -limit_to nohtml $var_from_url]
}

if {"new" == $ticket_sla_id && $add_projects_p} {

    # Copy all ticket form values to local variables
    catch {
	template::form::get_values ticket
    }

    # Get the list of all variables in the form
    set form_vars [template::form::get_elements helpdesk_ticket]

    # Remove the "ticket_id" field, because we want ad_form in edit mode.
    set ticket_id_pos [lsearch $form_vars "ticket_id"]
    set form_vars [lreplace $form_vars $ticket_id_pos $ticket_id_pos]

    # Remove the "ticket_sla_id" field to allow the user to select the new sla.
    set ticket_sla_id_pos [lsearch $form_vars "ticket_sla_id"]
    set form_vars [lreplace $form_vars $ticket_sla_id_pos $ticket_sla_id_pos]

    # calculate the vars for _this_ form
    set export_vars_varlist [list]
    foreach form_var $form_vars {
	lappend export_vars_varlist [list $form_var [im_opt_val -limit_to nohtml $form_var]]
    }

    # Add the "vars_from_url" to tell this form to set from values for these vars when we're back again.
    lappend export_vars_varlist [list vars_from_url $form_vars]

    # Determine the current_url so that we can come back here:
    set current_url [export_vars -base [ad_conn url] $export_vars_varlist]

    # Prepare the URL to create a new customer. 
    set new_sla_url [export_vars -base "/intranet/projects/new" {
	{project_type_id [im_project_type_sla]} 
	{project_name "SLA"} 
	{start_date "2000-01-01"} 
	{end_date "2099-12-31"} 
	{return_url $current_url}
    }]
    ad_returnredirect $new_sla_url
}


# ------------------------------------------------------------------
# Redirect for "New Customer Contact" option
# ------------------------------------------------------------------

if {"new" == $ticket_customer_contact_id && $user_can_create_new_customer_contact_p} {

    # Copy all ticket form values to local variables
    template::form::get_values helpdesk_ticket

    # Get the list of all variables in the form
    set form_vars_raw [template::form::get_elements helpdesk_ticket]
    set url_set [ns_conn form]
    if {"" == $url_set} { set url_set [ns_set create] }
    set url_vars_raw [ad_ns_set_keys $url_set]

    array set form_vars_hash {}
    foreach var [concat $form_vars_raw $url_vars_raw] {
	# Remove "ticket_id" field because we want ad_form in edit mode, and ticket_customer_contact_id for the new user
	if {$var in {"ticket_id" "ticket_customer_contact_id" "object_type"}} { continue }
	if {[regexp {^__} $var match]} { continue }		;# Exclude __* system form vars
	if {[regexp {[\:\.]} $var match]} { continue }		;# Exclude vars with ":", "." ...
	set val [im_opt_val -limit_to nohtml $var]
	if {"" eq $val} { continue }
	set form_vars_hash($var) $var
    }
    set form_vars [array names form_vars_hash]

    # calculate the vars for _this_ form
    set export_vars_varlist [list]
    foreach form_var $form_vars {
	lappend export_vars_varlist [list $form_var [im_opt_val -limit_to nohtml $form_var]]
    }

    # Add the "vars_from_url" to tell this form to set from values for these vars when we're back again.
    lappend export_vars_varlist [list vars_from_url $form_vars]

    # Determine the current_url where we have to come back to.
    set current_url [export_vars -base [ad_conn url] $export_vars_varlist]

    # Prepare the URL to create a new customer_contact. 
    set new_customer_contact_url [export_vars -base "/intranet/users/new" {
	{profile [im_customer_group_id]} 
	{return_url $current_url}
	{also_add_to_biz_object {$ticket_customer_id 1300}}
    }]

    ad_returnredirect $new_customer_contact_url
}

# ------------------------------------------------------------------
# Form options
# ------------------------------------------------------------------

if {([info exists ticket_customer_id] && $ticket_customer_id ne "")} {
    set customer_sla_options [im_helpdesk_ticket_sla_options -customer_id $ticket_customer_id -include_create_sla_p $add_projects_p -include_internal_sla_p 1 -include_default_option $ticket_sla_id]
    set customer_contact_options [db_list_of_lists customer_contact_options "
	select	im_name_from_user_id(u.user_id) as name,
		u.user_id
	from	users u
	where	u.user_id in (
			-- Members of group helpdesk
			select member_id from group_distinct_member_map where group_id = [im_profile_helpdesk]
			-- Members of the ticket customer
		UNION	select object_id_two from acs_rels where object_id_one = :ticket_customer_id
		UNION	select	member_id
			from	group_member_map gmm,
				acs_rels r
			where	r.object_id_two = gmm.group_id and
				r.object_id_one = :ticket_customer_id
			-- Members of the ticket SLA
		UNION	select object_id_two from acs_rels where object_id_one = :ticket_sla_id
		UNION	select	member_id
			from	group_member_map gmm,
				acs_rels r
			where	r.object_id_two = gmm.group_id and
				r.object_id_one = :ticket_sla_id
		) and
		user_id not in (
			select  u.user_id
			from    users u,
			        acs_rels r,
			        membership_rels mr
			where   r.rel_id = mr.rel_id and
			        r.object_id_two = u.user_id and
			        r.object_id_one = acs__magic_object_id('registered_users') and
			        mr.member_state != 'approved'		
		)
	order by name
    "]
} else {
    set customer_sla_options [im_helpdesk_ticket_sla_options -include_create_sla_p $add_projects_p]
    set customer_contact_options [im_user_options -include_empty_p 0]
}

# customer_contact_options
#
if {$add_companies_p} {
    set customer_contact_options [linsert $customer_contact_options 0 [list "Create New Customer Contact" "new"]]
}
set customer_contact_options [linsert $customer_contact_options 0 [list "" ""]]


# ------------------------------------------------------------------
# Check if the user is allowed to create a ticket for somebody else
# ------------------------------------------------------------------

set ticket_elements [list]

if {$add_tickets_for_customers_p} {

    lappend ticket_elements {ticket_sla_id:text(select) {label "[lang::message::lookup {} intranet-helpdesk.SLA SLA]"} {options $customer_sla_options}}
    lappend ticket_elements {ticket_customer_contact_id:text(select),optional {label "[lang::message::lookup {} intranet-helpdesk.Customer_Contact {<nobr>Customer Contact</nobr>}]"} {options $customer_contact_options}}

} else {

    set ticket_customer_contact_id $current_user_id
    lappend ticket_elements {ticket_sla_id:text(select) {mode display} {label "[lang::message::lookup {} intranet-helpdesk.SLA SLA]"} {options $customer_sla_options}}
    lappend ticket_elements {ticket_customer_contact_id:text(select),optional {mode display} {label "[lang::message::lookup {} intranet-helpdesk.Customer_Contact {<nobr>Customer Contact</nobr>}]"} {options $customer_contact_options}}

}


# ---------------------------------------------
# Status & Type
# ---------------------------------------------

lappend ticket_elements {ticket_type_id:text(im_category_tree) {label "[lang::message::lookup {} intranet-helpdesk.Type Type]"} {custom {category_type "Intranet Ticket Type" translate_p 1}}}

if {$edit_ticket_status_p} {
    lappend ticket_elements {ticket_status_id:text(im_category_tree) {label "[lang::message::lookup {} intranet-helpdesk.Status Status]"} {custom {category_type "Intranet Ticket Status" translate_p 1 }} }
} else {
    lappend ticket_elements {ticket_status_id:text(im_category_tree) {mode display} {label "[lang::message::lookup {} intranet-helpdesk.Status Status]"} {custom {category_type "Intranet Ticket Status" translate_p 1 }} }
}



ad_form -extend -name helpdesk_ticket -form $ticket_elements

if {!$edit_ticket_status_p} {
    template::element::set_value helpdesk_ticket ticket_status_id $ticket_status_id
}

# ---------------------------------------------
# Add DynFields to the form
# ---------------------------------------------

set dynfield_ticket_type_id ""
if {[info exists ticket_type_id]} { set dynfield_ticket_type_id $ticket_type_id}

set dynfield_ticket_id ""
if {[info exists ticket_id]} { set dynfield_ticket_id $ticket_id }

set field_cnt [im_dynfield::append_attributes_to_form \
		       -form_display_mode $form_mode \
		       -object_subtype_id $dynfield_ticket_type_id \
		       -object_type "im_ticket" \
		       -form_id "helpdesk_ticket" \
		       -object_id $dynfield_ticket_id \
]

# ------------------------------------------------------------------
# 
# ------------------------------------------------------------------


# Fix for problem changing to "edit" form_mode
set form_action [template::form::get_action "helpdesk_ticket"]
if {"" != $form_action} { set form_mode "edit" }
set next_ticket_nr ""

ad_form -extend -name helpdesk_ticket -on_request {

    # Populate elements from local variables
    if {![info exists ticket_name] || "" == $ticket_name} { 
	set next_ticket_nr [im_ticket::next_ticket_nr] 
	set ticket_nr $next_ticket_nr

	# I suggest to abstain from pre-setting the name, it takes too much space in list views and TS logging page 
	# and does not add any value. Adjustments had been made to show the ticket nr in the component header
	# set ticket_name [lang::message::lookup "" intranet-helpdesk.Default_Ticket_Name "Ticket \#%next_ticket_nr%"]

    }

    if {0 != $escalate_from_ticket_id} {

	# Populate from another ticket
	set sql "
		select	t.*,
			p.*
		from	im_projects p,
			im_tickets t
		where	p.project_id = t.ticket_id and
			p.project_id = :escalate_from_ticket_id
	"
	set ticket_name [lang::message::lookup "" intranet-helpdesk.Problem_escalated_from "Problem escalated from %copy_from_ticket_name%"]

	# Get the fields in the form
	set form_elements [template::form::get_elements helpdesk_ticket]

	# Execute the sql and write values into the form.
	db_with_handle db {
	    set selection [db_exec select $db query $sql 1]
	    while {[db_getrow $db $selection]} {
		set col_names [ad_ns_set_keys $selection]
		for {set i 0} {$i < [ns_set size $selection]} {incr i} {
		    set var [lindex $col_names $i]
		    set val [ns_set value $selection $i]

		    ns_log Notice "new: Copying from ticket #$escalate_from_ticket_id: $var=$val"
	
		    # Skip a number of variables that shouldn't be copied
		    if {"ticket_resolution_time" == $var} { continue }

		    # Write the value into the form if the form element exists
		    if {[lsearch $form_elements $var] > -1} {
			template::element::set_value helpdesk_ticket $var $val
		    }	

		}
	    }
	}
	db_release_unused_handles
    }

} -select_query {

	select	t.*,
		t.ticket_customer_deadline::date as ticket_customer_deadline,
		p.*,
		p.parent_id as ticket_sla_id,
		p.project_name as ticket_name,
		p.project_nr as ticket_nr,
		p.company_id as ticket_customer_id
	from	im_projects p,
		im_tickets t
	where	p.project_id = t.ticket_id and
		t.ticket_id = :ticket_id

} -new_data {

    if {!$add_tickets_p} {
	ad_return_complaint 1 [lang::message::lookup "" intranet-helpdesk.No_right_to_create_new_ticket "You don't have the permission to create a new ticket."]
	ad_script_abort
    }

    set message ""
    if {[info exists ticket_note]} { append message $ticket_note } else { set ticket_note "" }
    if {[info exists ticket_description]} { append message $ticket_description } else { set ticket_description "" }
    if {(![info exists project_name] || $project_name eq "")} { set project_name $ticket_name}

    set ticket_id [im_ticket::new \
	-ticket_sla_id $ticket_sla_id \
	-ticket_name $ticket_name \
	-ticket_nr $ticket_nr \
	-ticket_customer_contact_id $ticket_customer_contact_id \
	-ticket_type_id $ticket_type_id \
	-ticket_status_id $ticket_status_id \
	-ticket_start_date $start_date \
	-ticket_end_date $end_date \
	-ticket_note $message \
    ]

    im_dynfield::attribute_store \
	-object_type "im_ticket" \
	-object_id $ticket_id \
	-form_id helpdesk_ticket

    # Add a new assignees & Queues to the members of a ticket
    if {[info exists ticket_assignee_id] && "" != $ticket_assignee_id} {
	im_biz_object_add_role $ticket_assignee_id $ticket_id 1300
    }
    if {[info exists ticket_queue_id] && "" != $ticket_queue_id} {
	im_biz_object_add_role $ticket_queue_id $ticket_id 1300
    }

    # --------------------------------------------
    # Notifications
    if {[catch {
	set sla_name [db_string get_data "select project_name from im_projects where project_id = :ticket_sla_id" -default 0]
    } err_msg]} {
	global errorInfo
	ns_log Error $errorInfo
	set sla_name ""
    }

    set ticket_link "[parameter::get -package_id [apm_package_id_from_key acs-kernel] -parameter "SystemURL" -default ""]/intranet-helpdesk/new?form_mode=display&ticket_id=$ticket_id"
    set notif_message [lang::message::lookup "" intranet-helpdesk.NotificationBody "A new ticket has been created:\n\nName: %ticket_name%\nLink: %ticket_link%\nNote: %ticket_note%\nDescription: %ticket_description%\n "]

    notification::new \
	-type_id [notification::type::get_type_id -short_name ticket_notif] \
	-object_id $ticket_id \
	-response_id "" \
	-notif_subject [lang::message::lookup "" intranet-helpdesk.NotificationSubject "Ticket Notification for SLA: %sla_name%"] \
	-notif_text $notif_message

    # TICKET ASSIGNMENTS 
    # For smaller organization this is probably all what's needed.
    # Employees that can 'handle' tickets will be simply added to the SLA project 
    # Whenever a new ticket has been created, these employees get auto-assigned to the ticket. 
    # They can view/edit the ticket and appear in the notification dropdown of the ticket forum portlet.
    # For alternative handling simply set invisible parameter to 'false'
    if { [parameter::get -package_id [apm_package_id_from_key intranet-helpdesk] -parameter "AutoAssignEmployeeMembersOfSLAToTicket" -default 0]  } {
	# Get all employee_id's from SLA 
	set employee_group_id [im_employee_group_id] 
	set sql "
		select
		     rels.object_id_two as party_id
		from
		     acs_rels rels
		     LEFT OUTER JOIN im_biz_object_members bo_rels ON (rels.rel_id = bo_rels.rel_id)
		     LEFT OUTER JOIN im_categories c ON (c.category_id = bo_rels.object_role_id)
		where
			 rels.object_id_one = :ticket_sla_id and
			 rels.object_id_two in (select party_id from parties) and
			 rels.object_id_two not in (
			 -- Exclude banned or deleted users
			 select     m.member_id
			 from       group_member_map m, membership_rels mr
			 where      m.rel_id = mr.rel_id and
				    m.group_id = acs__magic_object_id('registered_users') and
				    m.container_id = m.group_id and
				    mr.member_state != 'approved'
			) and
			rels.object_id_two in (select member_id from group_distinct_member_map m where group_id = :employee_group_id);
	"
	db_foreach r $sql {
	    im_biz_object_add_role $party_id $ticket_id 1300
	}
    }

    # Let's do the same for customer accounts related to the SLA
    if {[parameter::get -package_id [apm_package_id_from_key intranet-helpdesk] -parameter "AutoAssignCustomerMembersOfSLAToTicket" -default 0]} {
	# Get all customer_id's from SLA
	set customer_group_id [im_customer_group_id]
	set sql "
		select
		     rels.object_id_two as party_id
		from
		     acs_rels rels
		     LEFT OUTER JOIN im_biz_object_members bo_rels ON (rels.rel_id = bo_rels.rel_id)
		     LEFT OUTER JOIN im_categories c ON (c.category_id = bo_rels.object_role_id)
		where
			 rels.object_id_one = :ticket_sla_id and
			 rels.object_id_two in (select party_id from parties) and
			 rels.object_id_two not in (
			 -- Exclude banned or deleted users
			 select     m.member_id
			 from       group_member_map m, membership_rels mr
			 where      m.rel_id = mr.rel_id and
				    m.group_id = acs__magic_object_id('registered_users') and
				    m.container_id = m.group_id and
				    mr.member_state != 'approved'
			) and
			rels.object_id_two in (select member_id from group_distinct_member_map m where group_id = :customer_group_id);
	"
	db_foreach r $sql {
	    im_biz_object_add_role $party_id $ticket_id 1300
	}
    }

    if {[info exists escalate_from_ticket_id] && 0 != $escalate_from_ticket_id} {
	# Add an escalation relationship between the two tickets
	db_string add_ticket_ticket_rel "
			select im_ticket_ticket_rel__new (
				null,
				'im_ticket_ticket_rel',
				:ticket_id,
				:escalate_from_ticket_id,
				null,
				:current_user_id,
				'[ad_conn peeraddr]',
				0
			)
       "
    }

    # Write Audit Trail
    im_audit -object_id $ticket_id -action after_create

    # Using this page to create new tickets for HTML5 apps
    if {"json" == $format} { 
	doc_return 200 "application/json" "{\"success\": true}" 
	ad_script_abort
    }

    # fraber 100928: Disabling return_url.
    # For a new ticket it makes sense to be sent to the new ticket page...
    ad_returnredirect [export_vars -base "/intranet-helpdesk/new" {ticket_id {form_mode display}}]
    ad_script_abort

} -edit_data {

    if {!$write_p} {
	ad_return_complaint 1 [lang::message::lookup "" intranet-helpdesk.No_right_to_create_new_ticket "You don't have the permission to create a new ticket."]
	ad_script_abort
    }

    # Fix the ticket_nr. I don't understand why, but that should be OK...
    set ticket_nr [string trim [string tolower $ticket_nr]]
    if {"" == $ticket_nr} { set ticket_nr [im_ticket::next_ticket_nr] }

    if {(![info exists project_name] || $project_name eq "")} { set project_name $ticket_name }
    set start_date_sql [template::util::date get_property sql_date $start_date]
    set end_date_sql [template::util::date get_property sql_timestamp $end_date]

    # Update the ticket itself
    db_dml ticket_update {}

    # Update the im_projects table with ticket fields and an open/closed project status
    set project_status_id [im_project_status_open]
    if {[im_category_is_a $ticket_status_id [im_ticket_status_closed]]} { set project_status_id [im_project_status_closed] }
    db_dml project_update {}

    im_dynfield::attribute_store \
	-object_type "im_ticket" \
	-object_id $ticket_id \
	-form_id helpdesk_ticket

    # Add a new assignee to the members of a ticket
    if {[info exists ticket_assignee_id] && "" != $ticket_assignee_id} {
	im_biz_object_add_role $ticket_assignee_id $ticket_id 1300
    }
    if {[info exists ticket_queue_id] && "" != $ticket_queue_id} {
	im_biz_object_add_role $ticket_queue_id $ticket_id 1300
    }
    
    # Write Audit Trail
    im_audit -object_id $ticket_id -action after_update

} -after_submit {

    # Reset the lock on the ticket
    db_dml set_lock "
	update im_biz_objects set
		lock_ip = null,
		lock_date = null,
		lock_user = null
	where object_id = :ticket_id
    "

    if {"json" == $format} { 
	doc_return 200 "application/json" "{\"success\": true}" 
	ad_script_abort
    }

    ad_returnredirect $return_url
    ad_script_abort

} -validate {
    {ticket_name
	{ [string length $ticket_name] < 1000 }
	"[lang::message::lookup {} intranet-helpdesk.Ticket_name_too_long {Ticket Name too long (max 1000 characters).}]" 
    }
}

# ---------------------------------------------------------------
# Ticket Menu
# ---------------------------------------------------------------

# Setup the subnavbar
set bind_vars [ns_set create]
if {[info exists ticket_id]} { ns_set put $bind_vars ticket_id $ticket_id }
if {![info exists ticket_id]} { set ticket_id "" }
set ticket_parent_menu_id [db_string parent_menu "select menu_id from im_menus where label='helpdesk'" -default 0]
set sub_navbar [im_sub_navbar \
    -components \
    -current_plugin_id $plugin_id \
    -base_url "/intranet-helpdesk/new?ticket_id=$ticket_id" \
    -plugin_url "/intranet-helpdesk/new" \
    $ticket_parent_menu_id \
    $bind_vars "" "pagedesriptionbar" "helpdesk_summary"] 


# ---------------------------------------------------------------
# Notifications
# ---------------------------------------------------------------

set notification_html ""

if {$show_components_p} {

    set notification_object_id $ticket_id
    set notification_delivery_method_id [notification::get_delivery_method_id -name "email"]
    set notification_interval_id [notification::get_interval_id -name "instant"]
    set notification_type_short_name "ticket_notif"
    set notification_type_pretty_name "Ticket Notification"
    set notification_title [string totitle $notification_type_pretty_name]
    set notification_type_id [notification::type::get_type_id -short_name $notification_type_short_name]
    set notification_current_url [im_url_with_query]
    
    # Check if subscribed
    set notification_request_id [notification::request::get_request_id \
				     -type_id $notification_type_id \
				     -object_id $notification_object_id \
				     -user_id $user_id]
    
    set notification_subscribed_p [expr {$notification_request_id ne ""}] 
    
    if { $notification_subscribed_p } {
	set notification_url [notification::display::unsubscribe_url -request_id $notification_request_id -url $notification_current_url]
    } else {
	set notification_url [export_vars -base "/notifications/request-new?" {
	    {object_id $notification_object_id} 
	    {type_id $notification_type_id}
	    {delivery_method_id $notification_delivery_method_id}
	    {interval_id $notification_interval_id}
	    {"form\:id" "subscribe"}
	    {formbutton\:ok "OK"}
	    {return_url $notification_current_url}
	}]
    }
    
    set notification_message [ad_decode $notification_subscribed_p 1 "Unsubscribe from $notification_type_pretty_name" "Subscribe to $notification_type_pretty_name"]
    set printer_friendly_url [export_vars -base "/intranet-helpdesk/new" {ticket_id return_url {render_template_id 1}}]
    set printer_friendly_message [lang::message::lookup "" intranet-helpdesk.Show_in_printer_friendly_format "Show in printer friendly format"]
	
    set notification_html "
	<ul>
	<li><a href=\"$notification_url\">$notification_message</a>
	<li><a href=\"$printer_friendly_url\">$printer_friendly_message</a>
	</ul>
    "
}


# ---------------------------------------------------------------
# Filter with Dynamic Fields
# ---------------------------------------------------------------

set dynamic_fields_p 1
set form_id "ticket_filter"
set object_type "im_ticket"
set action_url "/intranet-helpdesk/index"
set form_mode "edit"

set mine_p_options {}
if {$view_tickets_all_p} { 
    lappend mine_p_options [list [lang::message::lookup "" intranet-helpdesk.All "All"] "all" ] 
}
lappend mine_p_options [list [lang::message::lookup "" intranet-helpdesk.My_group "My Group"] "queue"]
lappend mine_p_options [list [lang::message::lookup "" intranet-helpdesk.Mine "Mine"] "mine"]

# Add custom searches to drop-down
if {[im_table_exists im_sql_selectors]} {
    set selector_sql "
	select	s.name, s.short_name
	from	im_sql_selectors s
	where	s.object_type = 'im_ticket'
    "
    db_foreach selectors $selector_sql {
	lappend mine_p_options [list $name $short_name]
    }
}

set ticket_member_options [util_memoize [list db_list_of_lists ticket_members "
	select	im_name_from_user_id(user_id) as user_name,
		t.user_id
	from	(select  distinct
			object_id_two as user_id
		from    acs_rels r,
			im_tickets p
		where   r.object_id_one = p.ticket_id
		) t
	order by user_name
"] 300]
set ticket_member_options [linsert $ticket_member_options 0 [list [_ intranet-core.All] ""]]
set ticket_queue_options [im_helpdesk_ticket_queue_options]
set ticket_sla_options [im_helpdesk_ticket_sla_options -include_create_sla_p 1 -include_empty_p 1]
set sla_exists_p 1
if {[llength $ticket_sla_options] < 2 && !$view_tickets_all_p} { set sla_exists_p 0}

# No SLA defined for this user? Then allow the user to request a new SLA.
if {!$sla_exists_p} {
    # Check if there is already an SLA request
    set sla_requested_p [db_string sla_requested_p "
	select	count(*)
	from	im_tickets t,
		acs_objects o
	where	t.ticket_id = o.object_id and
		t.ticket_type_id = [im_ticket_type_sla_request] and
		o.creation_user = :current_user_id and
		t.ticket_status_id in (select * from im_sub_categories([im_ticket_status_open]))
    "]

    # Allow the user to request a new SLA if there isn't any yet.
    if {!$sla_requested_p} {
	ad_returnredirect request-sla
    }
}


ad_form \
    -name $form_id \
    -action $action_url \
    -mode $form_mode \
    -method GET \
    -export {start_idx order_by how_many view_name letter } \
    -form {
	{mine_p:text(select),optional {label "Mine/All"} {options $mine_p_options }}
    }

if {$view_tickets_all_p} {
    ad_form -extend -name $form_id -form {
	{ticket_status_id:text(im_category_tree),optional {label "[lang::message::lookup {} intranet-helpdesk.Status Status]"} {custom {category_type "Intranet Ticket Status" translate_p 1}} }
	{ticket_type_id:text(im_category_tree),optional {label "[lang::message::lookup {} intranet-helpdesk.Type Type]"} {custom {category_type "Intranet Ticket Type" translate_p 1} } }
	{ticket_queue_id:text(select),optional {label "[lang::message::lookup {} intranet-helpdesk.Queue Queue]"} {options $ticket_queue_options}}
	{ticket_sla_id:text(select),optional {label "[lang::message::lookup {} intranet-helpdesk.SLA SLA]"} {options $ticket_sla_options}}
    }

    template::element::set_value $form_id ticket_status_id [im_opt_val -limit_to integer ticket_status_id]
    template::element::set_value $form_id ticket_type_id [im_opt_val -limit_to integer ticket_type_id]
    template::element::set_value $form_id ticket_queue_id [im_opt_val -limit_to integer ticket_queue_id]
}

template::element::set_value $form_id mine_p $mine_p

im_dynfield::append_attributes_to_form \
    -object_type $object_type \
    -form_id $form_id \
    -object_id 0 \
    -advanced_filter_p 1 \
    -search_p 1

# Set the form values from the HTTP form variable frame
set org_mine_p $mine_p
im_dynfield::set_form_values_from_http -form_id $form_id
im_dynfield::set_local_form_vars_from_http -form_id $form_id
set mine_p $org_mine_p

array set extra_sql_array [im_dynfield::search_sql_criteria_from_form \
			       -form_id $form_id \
			       -object_type $object_type
]

#ToDo: Export the extra DynField variables into form's "export" variable list



# ----------------------------------------------------------
# Do we have to show administration links?
# ----------------------------------------------------------

ns_log Notice "new: Before admin links"
set admin_html "<ul>"
if {$user_admin_p} {
    append admin_html "<li><a href=\"/intranet-helpdesk/admin/\">[lang::message::lookup "" intranet-helpdesk.Admin_Helpdesk "Admin Helpdesk"]</a>\n"
    append admin_html "<li><a href=\"/admin/group-types/one?group_type=im_ticket_queue\">[lang::message::lookup "" intranet-helpdesk.Admin_Helpdesk_Queues "Admin Helpdesk Queues"]</a>\n"
}

if {$add_tickets_p} {
    append admin_html "<li><a href=\"[export_vars -base "/intranet-helpdesk/new" {ticket_sla_id}]\">[lang::message::lookup "" intranet-helpdesk.Add_a_new_ticket "New Ticket"]</a>\n"

    set wf_oid_col_exists_p [im_column_exists wf_workflows object_type]
    if {$wf_oid_col_exists_p} {
	set wf_sql "
		select	t.pretty_name as wf_name,
			w.*
		from	wf_workflows w,
			acs_object_types t
		where	w.workflow_key = t.object_type
			and w.object_type = 'im_ticket'
	"
	db_foreach wfs $wf_sql {
	    set new_from_wf_url [export_vars -base "/intranet/tickets/new" {workflow_key}]
	    append admin_html "<li><a href=\"$new_from_wf_url\">[lang::message::lookup "" intranet-helpdesk.New_workflow "New %wf_name%"]</a>\n"
	}
    }
}

# Append user-defined menus
append admin_html [im_menu_ul_list -no_uls 1 "tickets_admin" {}]

# Close the admin_html section
append admin_html "</ul>"



# ----------------------------------------------------------
# Navbars
# ----------------------------------------------------------

# Compile and execute the formtemplate if advanced filtering is enabled.
eval [template::adp_compile -string {<formtemplate id="ticket_filter"></formtemplate>}]
set form_html $__adp_output
set left_navbar_html "
	    <div class='filter-block'>
		<div class='filter-title'>
		    [lang::message::lookup "" intranet-helpdesk.Filter_Tickets "Filter Tickets"]
		</div>
		$form_html
	    </div>
	    <hr/>
"
if {$sla_exists_p} {
    append left_navbar_html "
	    <div class='filter-block'>
		<div class='filter-title'>
		    [lang::message::lookup "" intranet-helpdesk.Admin_Tickets "Admin Tickets"]
		</div>
		$admin_html
	    </div>
	    <hr/>
    "
}


# ---------------------------------------------------------------
# Special Output: Format using a template
# ---------------------------------------------------------------

# Use a specific template ("render_template_id") to render the "preview"
if {0 != $render_template_id} {

    if {1 == $render_template_id} {
	# Default Template

	set template_from_param [im_parameter -package_id [im_package_helpdesk_id] DefaultTicketTemplate "" ""]
	if {"" == $template_from_param} {
	    # Use the default template that comes as part of the module
	    set template_body "default.adp"
	    set template_path "[acs_root_dir]/packages/intranet-helpdesk/templates/"
	} else {
	    # Use the user's template in the template path
	    set template_body $template_from_param
	    set template_path [im_parameter -package_id [im_package_invoices_id] InvoiceTemplatePathUnix "" "/tmp/templates/"]
	}
    } else {
	set template_body [im_category_from_id $render_template_id]
	set template_path [im_parameter -package_id [im_package_invoices_id] InvoiceTemplatePathUnix "" "/tmp/templates/"]
    }

    if {"" == $template_body} {
	ad_return_complaint 1 "<li>You haven't specified a template for your ticket."
	ad_script_abort
    }

    set template_path "${template_path}/${template_body}"

    if {![file isfile $template_path] || ![file readable $template_path]} {
	ad_return_complaint "Unknown Ticket Template" "
	<li>Ticket template'$template_path' doesn't exist or is not readable
	for the web server. Please notify your system administrator."
	ad_script_abort
    }

    # -----------------------------------------------------
    # Extract a few more fields for the template

    # SQL fails when there's no t.ticket_customer_contact_id
    set ticket_customer_contact_id [db_string get_data "select ticket_customer_contact_id from im_tickets where ticket_id = :ticket_id" -default 0]
    if { "" == $ticket_customer_contact_id } {
	ad_return_complaint 1 [lang::message::lookup "" intranet-helpdesk.NoTicketCustomerContactIdFound "View not available, please set ticket attribute 'Customer Contact' first."]
	ad_script_abort
    }

    db_1row template_ticket_info "
	select	p.*,
		t.*,
		im_name_from_id(ticket_customer_contact_id) as ticket_customer_contact_name,
		im_name_from_id(ticket_assignee_id) as ticket_assignee_name,
		im_category_from_id(ticket_type_id) as ticket_type,
		im_category_from_id(ticket_status_id) as ticket_status,
		im_category_from_id(ticket_prio_id) as ticket_prio,
		sla.project_name as sla_name,
		cuc.*,
		(select country_name from country_codes where iso = cuc.ha_country_code) as ha_country_name,
		(select country_name from country_codes where iso = cuc.wa_country_code) as wa_country_name
	from	im_tickets t
		LEFT OUTER JOIN users_contact cuc ON (t.ticket_customer_contact_id = cuc.user_id),
		im_projects p
		LEFT OUTER JOIN im_projects sla ON (p.parent_id = sla.project_id)
	where	p.project_id = t.ticket_id and
		t.ticket_id = :ticket_id
    "
    set forum_html [im_forum_full_screen_component -object_id $ticket_id -read_only_p 1]
    set user_locale [lang::user::locale]
    set locale $user_locale

    # Render the page using the template
    set invoices_as_html [ns_adp_parse -file $template_path]

    # Show invoice using template
    ns_return 200 text/html $invoices_as_html
    ad_script_abort
}

