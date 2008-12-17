# /packages/intranet-helpdesk/www/new.tcl
#
# Copyright (c) 2003-2008 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.


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
	{ return_url "" }
	message:optional
	{ ticket_status_id "[im_ticket_status_open]" }
	{ ticket_type_id "" }
	{ return_url "/intranet-helpdesk/" }
	{ vars_from_url ""}
	{ plugin_id:integer "" }
	{ view_name "standard"}
	form_mode:optional
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

    # Don't show this page in WF panel.
    # Instead, redirect to this same page, but in TaskViewPage mode.
    ad_returnredirect "/intranet-helpdesk/new?ticket_id=$task(object_id)"

}

# ------------------------------------------------------------------
# Default & Security
# ------------------------------------------------------------------

set current_user_id [ad_maybe_redirect_for_registration]
set user_id $current_user_id
set current_url [im_url_with_query]
set action_url "/intranet-helpdesk/new"
set focus "ticket.var_name"

if {[info exists ticket_id] && "" == $ticket_id} { unset ticket_id }

# Can the currrent user create new helpdesk customers?
set user_can_create_new_customer_p 1
set user_can_create_new_customer_sla_p 1
set user_can_create_new_customer_contact_p 1


# ----------------------------------------------
# Page Title

set page_title [lang::message::lookup "" intranet-helpdesk.New_Ticket "New Ticket"]
if {[exists_and_not_null ticket_id]} {
    set page_title [db_string title "select project_name from im_projects where project_id = :ticket_id" -default ""]
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
    if {[exists_and_not_null ticket_id]} { 
	set ticket_type_id [db_string ttype_id "select ticket_type_id from im_tickets where ticket_id = :ticket_id" -default 0]
    }
}

# ----------------------------------------------
# Calculate form_mode

if {"edit" == [template::form::get_action ticket]} { set form_mode "edit" }
if {![info exists ticket_id]} { set form_mode "edit" }
if {![info exists form_mode]} { set form_mode "display" }

set edit_ticket_status_p [im_permission $current_user_id edit_ticket_status]

# Show the ADP component plugins?
if {"edit" == $form_mode} { set show_components_p 0 }

set ticket_exists_p 0
if {[exists_and_not_null ticket_id]} {
    set ticket_exists_p [db_string ticket_exists_p "select count(*) from im_tickets where ticket_id = :ticket_id"]
}

# ---------------------------------------------
# The base form. Define this early so we can extract the form status
# ---------------------------------------------

set title_label [lang::message::lookup {} intranet-helpdesk.Name {Title}]
set title_help [lang::message::lookup {} intranet-helpdesk.Title_Help {Please enter a descriptive name for the new ticket.}]

set edit_p [im_permission $current_user_id add_tickets_for_customers]
set delete_p $edit_p

set actions {}
if {$edit_p} { lappend actions {"Edit" edit} }
# if {$delete_p} { lappend actions {"Delete" delete} }

ad_form \
    -name ticket \
    -cancel_url $return_url \
    -action $action_url \
    -actions $actions \
    -has_edit 1 \
    -mode $form_mode \
    -export {next_url return_url} \
    -form {
	ticket_id:key
	{ticket_name:text(text) {label $title_label} {html {size 50}} {help_text $title_help} }
	{ticket_nr:text(hidden),optional }
	{start_date:date(hidden),optional }
	{end_date:date(hidden),optional }
    }

# ------------------------------------------------------------------
# Ticket Action
# ------------------------------------------------------------------

set tid [value_if_exists ticket_id]
set ticket_action_html "
<form action=/intranet-helpdesk/action>
[export_form_vars return_url tid]
<input type=submit value='[lang::message::lookup "" intranet-helpdesk.Perform_Action "Perform Action"]'>
[im_category_select \
     -translate_p 1 \
     -plain_p 1 \
     -include_empty_p 1 \
     -include_empty_name "" \
     "Intranet Ticket Action" \
     action_id \
]
</form>
"



# ------------------------------------------------------------------
# Delete pressed?
# ------------------------------------------------------------------

set button_pressed [template::form get_action ticket]
if {"delete" == $button_pressed} {
     db_dml mark_ticket_deleted "
	update	im_tickets
	set	ticket_status_id = [im_ticket_status_deleted]
	where	ticket_id = :ticket_id
     "
    ad_returnredirect $return_url
}


# ------------------------------------------------------------------
# Redirect if ticket_type_id or ticket_sla_id are missing
# ------------------------------------------------------------------

if {"edit" == $form_mode} {

    set redirect_p 0
    # redirect if ticket_type_id is not defined
    if {("" == $ticket_type_id || 0 == $ticket_type_id) && ![exists_and_not_null ticket_id]} {
	set all_same_p [im_dynfield::subtype_have_same_attributes_p -object_type "im_ticket"]
	set all_same_p 0
	if {!$all_same_p} { set redirect_p 1 }
    }

    # Redirect if the SLA hasn't been defined yet
    if {("" == $ticket_sla_id || 0 == $ticket_sla_id) && ![exists_and_not_null ticket_id]} { set redirect_p 1 }

    if {$redirect_p} {
	ad_returnredirect [export_vars -base "new-typeselect" {{return_url $current_url} ticket_id ticket_type_id ticket_name ticket_nr ticket_nr ticket_sla_id}]
    }

}


# ------------------------------------------------------------------
# Get ticket_customer_id from information available in order to set options right
# ------------------------------------------------------------------

if {$ticket_exists_p} {

    db_1row ticket_info "
	select
		t.*, p.*,
		p.company_id as ticket_customer_id
	from
		im_projects p,
		im_tickets t
	where
		p.project_id = t.ticket_id
		and p.project_id = :ticket_id
    "

}

# Check if we can get the ticket_customer_id.
# We need this field in order to limit the customer contacts to show.
if {![exists_and_not_null ticket_customer_id] && [exists_and_not_null ticket_sla_id] && "new" != $ticket_sla_id} {
    set ticket_customer_id [db_string cid "select company_id from im_projects where project_id = :ticket_sla_id" -default ""]
}


# ------------------------------------------------------------------
# Redirect for "New SLA" option
# ------------------------------------------------------------------

# Fetch variable values from the HTTP session and write to local variables
set url_vars_set [ns_conn form]
foreach var_from_url $vars_from_url {
    ad_set_element_value -element $var_from_url [im_opt_val $var_from_url]
}

if {"new" == $ticket_sla_id && $user_can_create_new_customer_sla_p} {

    # Copy all ticket form values to local variables
    template::form::get_values ticket

    # Get the list of all variables in the form
    set form_vars [template::form::get_elements ticket]

    # Remove the "ticket_id" field, because we want ad_form in edit mode.
    set ticket_id_pos [lsearch $form_vars "ticket_id"]
    set form_vars [lreplace $form_vars $ticket_id_pos $ticket_id_pos]

    # Remove the "ticket_sla_id" field to allow the user to select the new sla.
    set ticket_sla_id_pos [lsearch $form_vars "ticket_sla_id"]
    set form_vars [lreplace $form_vars $ticket_sla_id_pos $ticket_sla_id_pos]

    # calculate the vars for _this_ form
    set export_vars_varlist [list]
    foreach form_var $form_vars {
	lappend export_vars_varlist [list $form_var [im_opt_val $form_var]]
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
    template::form::get_values ticket

    # Get the list of all variables in the form
    set form_vars [template::form::get_elements ticket]

    # Remove the "ticket_id" field, because we want ad_form in edit mode.
    set ticket_id_pos [lsearch $form_vars "ticket_id"]
    set form_vars [lreplace $form_vars $ticket_id_pos $ticket_id_pos]

    # Remove the "ticket_customer_contact_id" field to allow the user to select the new customer_contact.
    set ticket_customer_contact_id_pos [lsearch $form_vars "ticket_customer_contact_id"]
    set form_vars [lreplace $form_vars $ticket_customer_contact_id_pos $ticket_customer_contact_id_pos]

    # calculate the vars for _this_ form
    set export_vars_varlist [list]
    foreach form_var $form_vars {
	lappend export_vars_varlist [list $form_var [im_opt_val $form_var]]
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

if {[exists_and_not_null ticket_customer_id]} {
    set customer_sla_options [im_helpdesk_ticket_sla_options -customer_id $ticket_customer_id -include_create_sla_p 1]
    set customer_contact_options [im_user_options -biz_object_id $ticket_customer_id -include_empty_p 0]
} else {
    set customer_sla_options [im_helpdesk_ticket_sla_options -include_create_sla_p 1]
    set customer_contact_options [im_user_options -include_empty_p 0]
}

# customer_contact_options
#
if {$user_can_create_new_customer_p} {
    set customer_contact_options [linsert $customer_contact_options 0 [list "Create New Customer Contact" "new"]]
}
set customer_contact_options [linsert $customer_contact_options 0 [list "" ""]]


# ------------------------------------------------------------------
# Check permission if the user is allowed to create a ticket for somebody else
# ------------------------------------------------------------------

set ticket_elements [list]

if {[im_permission $current_user_id add_tickets_for_customers]} {

    lappend ticket_elements {ticket_sla_id:text(select) {label "[lang::message::lookup {} intranet-helpdesk.SLA SLA]"} {options $customer_sla_options}}
    lappend ticket_elements {ticket_customer_contact_id:text(select) {label "[lang::message::lookup {} intranet-helpdesk.Customer_Contact {<nobr>Customer Contact</nobr>}]"} {options $customer_contact_options}}

} else {

#    lappend ticket_elements {ticket_sla_id:text(hidden) {options $customer_sla_options}}
#    lappend ticket_elements {ticket_customer_contact_id:text(hidden) {label "[lang::message::lookup {} intranet-helpdesk.Customer_Contact {<nobr>Customer Contact</nobr>}]"} {options $customer_contact_options}}

    lappend ticket_elements {ticket_sla_id:text(select) {mode display} {label "[lang::message::lookup {} intranet-helpdesk.SLA SLA]"} {options $customer_sla_options}}
    set ticket_customer_contact_id $current_user_id
    lappend ticket_elements {ticket_customer_contact_id:text(select) {mode display} {label "[lang::message::lookup {} intranet-helpdesk.Customer_Contact {<nobr>Customer Contact</nobr>}]"} {options $customer_contact_options}}

}



# ---------------------------------------------
# Status & Type

lappend ticket_elements {ticket_type_id:text(im_category_tree) {label "[lang::message::lookup {} intranet-helpdesk.Type Type]"} {custom {category_type "Intranet Ticket Type"}}}

if {$edit_ticket_status_p} {
    lappend ticket_elements {ticket_status_id:text(im_category_tree) {label "[lang::message::lookup {} intranet-helpdesk.Status Status]"} {custom {category_type "Intranet Ticket Status"}} }
}


# Extend the form with new fields
ad_form -extend -name ticket -form $ticket_elements



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
                       -form_id "ticket" \
                       -object_id $dynfield_ticket_id \
]

# ------------------------------------------------------------------
# 
# ------------------------------------------------------------------

# Fix for problem changing to "edit" form_mode
set form_action [template::form::get_action "ticket"]
if {"" != $form_action} { set form_mode "edit" }

ad_form -extend -name ticket -on_request {

    # Populate elements from local variables

} -select_query {

	select	t.*,
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

    set message ""
    if {[info exists ticket_note]} { append message $ticket_note }
    if {[info exists ticket_description]} { append message $ticket_description }

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
	-form_id ticket

    notification::new \
        -type_id [notification::type::get_type_id -short_name ticket_notif] \
        -object_id $ticket_id \
        -response_id "" \
        -notif_subject "New: Subject" \
        -notif_text "Text"

    # Send to page to show the new ticket, instead of returning to return_url
    ad_returnredirect [export_vars -base "/intranet-helpdesk/new" {ticket_id}]
    ad_script_abort

} -edit_data {

    set ticket_nr [string trim [string tolower $ticket_nr]]
    if {"" == $ticket_nr} { set ticket_nr [im_ticket::next_ticket_nr] }
    set start_date_sql [template::util::date get_property sql_date $start_date]
    set end_date_sql [template::util::date get_property sql_timestamp $end_date]

    db_dml ticket_update {}
    db_dml project_update {}

    im_dynfield::attribute_store \
	-object_type "im_ticket" \
	-object_id $ticket_id \
	-form_id ticket

    # Write Audit Trail
    im_project_audit $ticket_id

    notification::new \
        -type_id [notification::type::get_type_id -short_name ticket_notif] \
        -object_id $ticket_id \
        -response_id "" \
        -notif_subject "Edit: Subject" \
        -notif_text "Text"

} -on_submit {

	ns_log Notice "new: on_submit"

} -after_submit {

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

set ticket_menu_id [db_string parent_menu "select menu_id from im_menus where label='helpdesk'" -default 0]
set sub_navbar [im_sub_navbar \
    -components \
    -current_plugin_id $plugin_id \
    -base_url "/intranet-helpdesk/new?ticket_id=$ticket_id" \
    -plugin_url "/intranet-helpdesk/new" \
    $ticket_menu_id \
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
    
    set notification_subscribed_p [expr ![empty_string_p $notification_request_id]]
    
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
    
    set notification_message [ad_decode $notification_subscribed_p 1 "Unsubscribe from $notification_type_pretty_name" "Subscribe to $notification_type_pretty_name"] \
	
    set notification_html "
	<ul>
	<li><a href=\"$notification_url\">$notification_message</a>
	</ul>
    "
}

