# /packages/intranet-helpdesk/www/new.tcl
#
# Copyright (c) 2003-2008 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_page_contract {
    @author frank.bergmann@project-open.com
} {
    ticket_id:integer,optional
    { return_url "" }
    edit_p:optional
    message:optional
    { ticket_status_id "[im_ticket_status_open]" }
    { return_url "/intranet-helpdesk/" }
    { vars_from_url ""}
}


# ------------------------------------------------------------------
# Default & Security
# ------------------------------------------------------------------

set current_user_id [ad_maybe_redirect_for_registration]
set action_url "/intranet-helpdesk/new"
set focus "ticket.var_name"
set page_title [lang::message::lookup "" intranet-helpdesk.New_Ticket "New Ticket"]
set context [list $page_title]

if {![info exists ticket_id]} { set form_mode "edit" }
if {![info exists form_mode]} { set form_mode "" }

set edit_ticket_status_p [im_permission $current_user_id edit_ticket_status]

# Show the ADP component plugins?
set show_components_p 0

# Can the currrent user create new helpdesk customers?
set user_can_create_new_customer_p 1
set user_can_create_new_customer_contact_p 1

# ------------------------------------------------------------------
# Delete?
# ------------------------------------------------------------------

set button_pressed [template::form get_action ticket]
# ad_return_complaint 1 '$button_pressed'


if {"delete" == $button_pressed} {
    db_exec_plsql ticket_delete {}
    ad_returnredirect $return_url
}


# ------------------------------------------------------------------
# Action - Who is allowed to do what?
# ------------------------------------------------------------------

set actions [list]
set actions [list {"Edit" edit} {"asdf" asdf} ]

if {[im_permission $current_user_id add_tickets]} {
    lappend actions {"Delete" delete}
}


# ------------------------------------------------------------------
# Build the form
# ------------------------------------------------------------------

set elements [list]
lappend elements ticket_id:key
lappend elements {ticket_name:text(text) {label "[lang::message::lookup {} intranet-helpdesk.Name {Title}]"} {html {size 50}}}

# ---------------------------------------------
# Customer
set customer_options [im_company_options -type "Customer" -include_empty 0]
if {$user_can_create_new_customer_p} {
    set customer_options [linsert $customer_options 0 [list "Create New Customer" "new"]]
}
set customer_options [linsert $customer_options 0 [list "" ""]]
lappend elements {ticket_customer_id:text(select) {label "[lang::message::lookup {} intranet-helpdesk.Customer Customer]"} {options $customer_options}}


# ---------------------------------------------
# Customer Contact
set customer_contact_options [im_user_options -group_id [im_customer_group_id] -include_empty_p 0]
if {$user_can_create_new_customer_p} {
    set customer_contact_options [linsert $customer_contact_options 0 [list "Create New Customer Contact" "new"]]
}
set customer_contact_options [linsert $customer_contact_options 0 [list "" ""]]
lappend elements {ticket_customer_contact_id:text(select) {label "[lang::message::lookup {} intranet-helpdesk.Customer_Contact {<nobr>Customer Contact</nobr>}]"} {options $customer_contact_options}}

# ---------------------------------------------
# Status
if {$edit_ticket_status_p} {
    lappend elements {ticket_status_id:text(im_category_tree) {label "[lang::message::lookup {} intranet-helpdesk.Status Status]"} {custom {category_type "Intranet Ticket Status"}} }
}

# ---------------------------------------------
# Type
lappend elements {ticket_type_id:text(im_category_tree) {label "[lang::message::lookup {} intranet-helpdesk.Type Type]"} {custom {category_type "Intranet Ticket Type"}}}


ad_form \
    -name ticket \
    -cancel_url $return_url \
    -action $action_url \
    -actions $actions \
    -has_edit 1 \
    -mode $form_mode \
    -export {next_url return_url} \
    -form $elements



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
# Search 
# ------------------------------------------------------------------

# Set the form variables if we have been redirected from a "new" page.
set url_vars_set [ns_conn form]
foreach var_from_url $vars_from_url {
    ad_set_element_value -element $var_from_url [im_opt_val $var_from_url]
}

# Rediret to CompanyNewPage if the ticket_customer_id was set to "new"
set ticket_customer_id_value [template::element get_value ticket ticket_customer_id]
if {"new" == $ticket_customer_id_value && $user_can_create_new_customer_p} {

    # Copy all ticket form values to local variables
    template::form::get_values ticket

    # Get the list of all variables in the form
    set form_vars [template::form::get_elements ticket]

    # Remove the "ticket_id" field, because we want ad_form in edit mode.
    set ticket_id_pos [lsearch $form_vars "ticket_id"]
    set form_vars [lreplace $form_vars $ticket_id_pos $ticket_id_pos]

    # Remove the "ticket_customer_id" field to allow the user to select the new customer.
    set ticket_customer_id_pos [lsearch $form_vars "ticket_customer_id"]
    set form_vars [lreplace $form_vars $ticket_customer_id_pos $ticket_customer_id_pos]

    # calculate the vars for _this_ form
    set export_vars_varlist [list]
    foreach form_var $form_vars {
	lappend export_vars_varlist [list $form_var [im_opt_val $form_var]]
    }

    # Add the "vars_from_url" to tell this form to set from values for these vars when we're back again.
    lappend export_vars_varlist [list vars_from_url $form_vars]

    # Determine the current_url where we have to come back to.
    set current_url [export_vars -base [ad_conn url] $export_vars_varlist]

    # Prepare the URL to create a new customer. 
    set new_customer_url [export_vars -base "/intranet/companies/new" {{company_type_id [im_company_type_customer]} {return_url $current_url}}]
    ad_returnredirect $new_customer_url
}



# Rediret to UserNewPage if the ticket_customer_contact_id was set to "new"
set ticket_customer_contact_id_value [template::element get_value ticket ticket_customer_contact_id]
if {"new" == $ticket_customer_contact_id_value && $user_can_create_new_customer_contact_p} {

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
	{also_add_to_biz_object {$ticket_customer_id_value 1300}}
    }]
    ad_returnredirect $new_customer_contact_url
}


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
		p.*
	from	im_projects p,
		im_tickets t
	where	p.project_id = t.ticket_id and
		t.ticket_id = :ticket_id

} -new_data {

    set ticket_nr [db_nextval im_ticket_seq]
    set start_date [db_string now "select now()::date from dual"]
    set end_date [db_string now "select (now()::date)+1 from dual"]
    set start_date_sql [template::util::date get_property sql_date $start_date]
    set end_date_sql [template::util::date get_property sql_timestamp $end_date]

	db_string ticket_insert {}
	db_dml ticket_update {}
	db_dml project_update {}

	# Write Audit Trail
	im_project_audit $ticket_id


    db_transaction {
    } on_error {
	ad_return_complaint 1 "<b>Error inserting new ticket</b>:
	<pre>$errmsg</pre>"
    }

} -edit_data {

    edit_set ticket_nr [string tolower $ticket_nr]
    set start_date_sql [template::util::date get_property sql_date $start_date]
    set end_date_sql [template::util::date get_property sql_timestamp $end_date]

    db_dml ticket_update {}
    db_dml project_update {}

    # Write Audit Trail
    im_project_audit $ticket_id

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
# Project Menu
# ---------------------------------------------------------------

# Setup the subnavbar
set bind_vars [ns_set create]

if {[info exists ticket_id]} {
    ns_set put $bind_vars ticket_id $ticket_id
}

set project_menu_id [db_string parent_menu "select menu_id from im_menus where label='project'" -default 0]
set sub_navbar [im_sub_navbar \
    -components \
    -base_url "/intranet-helpdesk/" \
    $project_menu_id \
    $bind_vars "" "pagedesriptionbar" "project_timesheet_ticket"] 

