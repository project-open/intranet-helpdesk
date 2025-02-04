# /packages/intranet-helpdesk/tcl/intranet-helpdesk-procs.tcl
#
# Copyright (c) 2003-2008 ]project-open[
#
# All rights reserved. Please check
# https://www.project-open.com/license/ for details.

ad_library {
    @author frank.bergmann@project-open.com
}


# ----------------------------------------------------------------------
# Constants
# ----------------------------------------------------------------------

ad_proc -public im_ticket_status_open {} { return 30000 }
ad_proc -public im_ticket_status_closed {} { return 30001 }
ad_proc -public im_ticket_status_accepted {} { return 30008 }
ad_proc -public im_ticket_status_internal_review {} { return 30010 }
ad_proc -public im_ticket_status_assigned {} { return 30011 }
ad_proc -public im_ticket_status_customer_review {} { return 30012 }
ad_proc -public im_ticket_status_waiting_for_other {} { return 30026 }
ad_proc -public im_ticket_status_frozen {} { return 30028 }
ad_proc -public im_ticket_status_duplicate {} { return 30090 }
ad_proc -public im_ticket_status_invalid {} { return 30091 }
ad_proc -public im_ticket_status_outdated {} { return 30092 }
ad_proc -public im_ticket_status_rejected {} { return 30093 }
ad_proc -public im_ticket_status_wontfix {} { return 30094 }
ad_proc -public im_ticket_status_cantreproduce {} { return 30095 }
ad_proc -public im_ticket_status_resolved {} { return 30096 }
ad_proc -public im_ticket_status_deleted {} { return 30097 }
ad_proc -public im_ticket_status_canceled {} { return 30098 }

ad_proc -public im_ticket_type_purchase_request {} { return 30102 }
ad_proc -public im_ticket_type_workplace_move_request {} { return 30104 }
ad_proc -public im_ticket_type_telephony_request {} { return 30106 }
ad_proc -public im_ticket_type_project_request {} { return 30108 }
ad_proc -public im_ticket_type_bug_request {} { return 30110 }
ad_proc -public im_ticket_type_report_request {} { return 30112 }
ad_proc -public im_ticket_type_permission_request {} { return 30114 }
ad_proc -public im_ticket_type_feature_request {} { return 30116 }
ad_proc -public im_ticket_type_training_request {} { return 30118 }
ad_proc -public im_ticket_type_sla_request {} { return 30120 }
ad_proc -public im_ticket_type_nagios_alert {} { return 30122 }

ad_proc -public im_ticket_type_generic_problem_ticket {} { return 30130 }

ad_proc -public im_ticket_type_comment_request {} { return 30140 }

ad_proc -public im_ticket_type_incident_ticket {} { return 30150 }
ad_proc -public im_ticket_type_problem_ticket {} { return 30152 }
ad_proc -public im_ticket_type_change_ticket {} { return 30154 }
ad_proc -public im_ticket_type_project_change_request {} { return 30156 }
ad_proc -public im_ticket_type_user_story {} { return 30158 }

ad_proc -public im_ticket_type_idea {} { return 30180 }

ad_proc -public im_ticket_action_close {} { return 30500 }
ad_proc -public im_ticket_action_close_notify {} { return 30510 }
ad_proc -public im_ticket_action_duplicated {} { return 30520 }
ad_proc -public im_ticket_action_close_delete {} { return 30590 }


# ----------------------------------------------------------------------
# PackageID
# ----------------------------------------------------------------------

ad_proc -public im_package_helpdesk_id {} {
    Returns the package id of the intranet-helpdesk module
} {
    return [util_memoize im_package_helpdesk_id_helper]
}

ad_proc -private im_package_helpdesk_id_helper {} {
    return [db_string im_package_core_id {
        select package_id from apm_packages
        where package_key = 'intranet-helpdesk'
    } -default 0]
}


# ----------------------------------------------------------------------
# Permissions
# ---------------------------------------------------------------------

ad_proc -public im_ticket_permissions {
    user_id 
    ticket_id 
    view_var 
    read_var 
    write_var 
    admin_var
} {
    Fill the "by-reference" variables read, write and admin
    with the permissions of $user_id on $ticket_id
} {
    ns_log Notice "im_ticket_permissions: user_id=$user_id, ticket_id=$ticket_id"
    upvar $view_var view
    upvar $read_var read
    upvar $write_var write
    upvar $admin_var admin

    set view 0
    set read 0
    set write 0
    set admin 0

    set admin_p [im_is_user_site_wide_or_intranet_admin $user_id]
    set edit_ticket_status_p [im_permission $user_id edit_ticket_status]
    set add_tickets_for_customers_p [im_permission $user_id add_tickets_for_customers]
    set add_tickets_p [im_permission $user_id "add_tickets"]
    set view_tickets_all_p [im_permission $user_id "view_tickets_all"]
    set edit_tickets_all_p [im_permission $user_id "edit_tickets_all"]

    # Determine the list of all groups in which the current user is a member
    set user_parties [im_profile::profiles_for_user -user_id $user_id]
    lappend user_parties $user_id

    if {![db_0or1row ticket_info "
	select	coalesce(t.ticket_assignee_id, 0) as ticket_assignee_id,
		coalesce(t.ticket_customer_contact_id,0) as ticket_customer_contact_id,
		coalesce(o.creation_user,0) as creation_user_id,
		(select count(*) from (
			-- member of an explicitely assigned ticket_queue
			select	distinct g.group_id
			from	acs_rels r, groups g 
			where	r.object_id_one = g.group_id and
				r.object_id_two = :user_id and
				g.group_id = t.ticket_queue_id
		) t) as queue_member_p,
		(select count(*) from (
			-- member of the ticket - any role_id will do.
			select	distinct r.object_id_one
			from	acs_rels r,
				im_biz_object_members bom
			where	r.rel_id = bom.rel_id and
				r.object_id_two in ([join $user_parties ","])
		) t) as ticket_member_p,
		(select count(*) from (
			-- admin of the ticket
			select	distinct r.object_id_one
			from	acs_rels r,
				im_biz_object_members bom
			where	r.rel_id = bom.rel_id and
				r.object_id_two in ([join $user_parties ","]) and
				bom.object_role_id in (1301, 1302)
		) t) as ticket_admin_p,

		(select count(*) from (
			-- user is a member of the SLA - any role will do
			select	rp.project_id
			from	acs_rels r,
				im_projects rp,
				im_biz_object_members bom
			where	r.rel_id = bom.rel_id and
				r.object_id_one = rp.project_id and
				rp.project_id = p.parent_id and
				r.object_id_two in ([join $user_parties ","])
		) t) as sla_member_p,

		(select count(*) from (
			-- user is a member of the ticket customer - any role will do
			select	rc.company_id
			from	acs_rels r,
				im_companies rc,
				im_biz_object_members bom
			where	r.rel_id = bom.rel_id and
				r.object_id_one = rc.company_id and
				r.object_id_two in ([join $user_parties ","]) and
				p.company_id = rc.company_id
		) t) as customer_member_p,

		(select count(*) from (
			-- cases with user as task_assignee
			select distinct wfc.object_id
			from	wf_task_assignments wfta,
				wf_tasks wft,
				wf_cases wfc
			where	t.ticket_id = wfc.object_id and
				wft.state in ('enabled', 'started') and
				wft.case_id = wfc.case_id and
				wfta.task_id = wft.task_id and
				wfta.party_id in ([join $user_parties ","])
		) t) as case_assignee_p,
		(select count(*) from (
			-- cases with user as task holding_user
			select	distinct wfc.object_id
			from	wf_tasks wft,
				wf_cases wfc
			where	t.ticket_id = wfc.object_id and
				wft.holding_user = :user_id and
				wft.state in ('enabled', 'started') and
				wft.case_id = wfc.case_id
		) t) as holding_user_p
	from	im_tickets t,
		im_projects p,
		acs_objects o
	where	t.ticket_id = :ticket_id and
		t.ticket_id = p.project_id and
		t.ticket_id = o.object_id
    "]} {
	# Didn't find ticket - just return with permissions set to 0...
	return 0
    }

    set owner_p [expr $user_id == $creation_user_id]
    set assignee_p [expr $user_id == $ticket_assignee_id]
    set customer_p [expr $customer_member_p || $user_id == $ticket_customer_contact_id]

    # Customer contacts from the same company as the customer_contact_id should have
    # read permission on the ticket of their colleague, but not have write permission
    set read [expr $admin_p || $owner_p || $assignee_p || $customer_p || $sla_member_p || $ticket_member_p || $holding_user_p || $case_assignee_p || $queue_member_p || $view_tickets_all_p || $edit_tickets_all_p]
    set write [expr $admin_p || $edit_tickets_all_p || $ticket_admin_p]

    set view $read
    set admin $write

}

ad_proc -public im_ticket_permission_read_sql {
    { -user_id "" }
} {
    Returns a SQL statement that returns the list of ticket_ids
    that are readable for the user
} {
    if {"" == $user_id} { set user_id [ad_conn user_id] }
    ns_log Notice "im_ticket_permissions_read_sql: user_id=$user_id"

    # The SQL for admins and users who can read everything
    set read_all_sql "select ticket_id from im_tickets"

    # Admins can do everything
    set admin_p [im_is_user_site_wide_or_intranet_admin $user_id]
    if {$admin_p} { return $read_all_sql }

    # Users with permissions to read any tickets
    set view_tickets_all_p [im_permission $user_id "view_tickets_all"]
    if {$view_tickets_all_p} { return $read_all_sql }

    # Determine the list of all groups in which the current user is a member
    set user_parties [im_profile::profiles_for_user -user_id $user_id]
    lappend user_parties $user_id

    set read_sql "
	select	t.ticket_id
	from	im_tickets t,
		im_projects p,
		acs_objects o
	where	t.ticket_id = p.project_id and
		t.ticket_id = o.object_id and
		(t.ticket_assignee_id = :user_id
		OR t.ticket_customer_contact_id = :user_id
		OR o.creation_user = :user_id
		OR exists(
			-- member of an explicitely assigned ticket_queue
			select	g.group_id
			from	acs_rels r, 
				groups g 
			where	r.object_id_one = g.group_id and
				r.object_id_two = :user_id and
				g.group_id = t.ticket_queue_id			
		) OR t.ticket_id in (
			-- member of the ticket - any role_id will do.
			select	r.object_id_one
			from	acs_rels r,
				im_biz_object_members bom
			where	r.rel_id = bom.rel_id and
				r.object_id_two in ([join $user_parties ","])
		) OR p.parent_id in (
			-- user is a member of the SLA - any role will do
			select	rp.project_id
			from	acs_rels r,
				im_projects rp,
				im_biz_object_members bom
			where	r.rel_id = bom.rel_id and
				r.object_id_one = rp.project_id and
				r.object_id_two in ([join $user_parties ","])
		) OR p.company_id in (
			-- user is a member of the ticket customer - any role will do
			select	rc.company_id
			from	acs_rels r,
				im_companies rc,
				im_biz_object_members bom
			where	r.rel_id = bom.rel_id and
				r.object_id_one = rc.company_id and
				r.object_id_two in ([join $user_parties ","])
		) OR t.ticket_id in (
			-- cases with user as task_assignee
			select	wfc.object_id
			from	wf_task_assignments wfta,
				wf_tasks wft,
				wf_cases wfc
			where	wft.state in ('enabled', 'started') and
				wft.case_id = wfc.case_id and
				wfta.task_id = wft.task_id and
				wfta.party_id in ([join $user_parties ","])
		) OR t.ticket_id in (
			-- cases with user as task holding_user
			select	wfc.object_id
			from	wf_tasks wft,
				wf_cases wfc
			where	wft.holding_user = :user_id and
				wft.state in ('enabled', 'started') and
				wft.case_id = wfc.case_id
		))
    "
    return $read_sql
}




# ----------------------------------------------------------------------
# Navigation Bar
# ---------------------------------------------------------------------

ad_proc -public im_ticket_navbar { 
    {-current_plugin_id "" }
    {-plugin_url "" }
    {-navbar_menu_label "helpdesk"}
    default_letter 
    base_url 
    next_page_url 
    prev_page_url 
    export_var_list 
    {select_label ""} 
} {
    Returns rendered HTML code for a horizontal sub-navigation
    bar for /intranet/projects/.
    The lower part of the navbar also includes an Alpha bar.

    @param default_letter none marks a special behavious, hiding the alpha-bar.
    @navbar_menu_label Determines the "parent menu" for the menu tabs for 
		       search shortcuts, defaults to "projects".
} {
    # -------- Defaults -----------------------------
    set user_id [ad_conn user_id]
    set url_stub [ns_urldecode [im_url_with_query]]

    set sel "<td class=tabsel>"
    set nosel "<td class=tabnotsel>"
    set a_white "<a class=whitelink"
    set tdsp "<td>&nbsp;</td>"

    # -------- Calculate Alpha Bar with Pass-Through params -------
    set bind_vars [ns_set create]
    foreach var $export_var_list {
	upvar 1 $var value
	if { [info exists value] } {
	    ns_set put $bind_vars $var $value
	}
    }
    set alpha_bar [im_alpha_bar -prev_page_url $prev_page_url -next_page_url $next_page_url $base_url $default_letter $bind_vars]

    # Get the Subnavbar
    set parent_menu_sql "select menu_id from im_menus where label = '$navbar_menu_label'"
    set parent_menu_id [util_memoize [list db_string parent_admin_menu $parent_menu_sql -default 0]]
    
    ns_set put $bind_vars letter $default_letter
    ns_set delkey $bind_vars project_status_id

    set navbar [im_sub_navbar \
		    -components \
		    -current_plugin_id $current_plugin_id \
		    -plugin_url $plugin_url \
		    $parent_menu_id \
		    $bind_vars \
		    $alpha_bar \
		    "tabnotsel" \
		    $select_label \
    ]

    return $navbar
}


# ----------------------------------------------------------------------
# Components
# ---------------------------------------------------------------------

namespace eval im_ticket {

    ad_proc -public next_ticket_nr {
    } {
        Create a new ticket_nr. Calculates the max() of current
	ticket_nrs and add +1, or just use a sequence for the next value.

        @author frank.bergmann@project-open.com
	@return next ticket_nr
    } {
	set next_ticket_nr_method [parameter::get_from_package_key -package_key "intranet-helpdesk" -parameter "NextTicketNrMethod" -default "sequence"]

	switch $next_ticket_nr_method {
	    sequence {
		# Make sure everybody _really_ gets a different NR!
		return [db_nextval im_ticket_seq]
	    }
	    default {
		# Try to avoid any "holes" in the list of ticket NRs
		set last_ticket_nr [db_string last_pnr "
		select	max(project_nr::integer)
		from	im_projects
		where	project_type_id = [im_project_type_ticket]
			and project_nr ~ '^\[0-9\]+\$'
	        " -default 0]
	
		# Make sure the counter is not behind the current value
		while {[db_string lv "select last_value from im_ticket_seq"] < $last_ticket_nr} {
		    set ttt [db_string update "select nextval('im_ticket_seq')"]
		}
		return [expr {$last_ticket_nr + 1}]
		
	    }
	}
    }


#    ad_proc -public new_from_hash {
#        { -var_hash "" }
#    } {
#        Create a new ticket. There are only few required field.
#	Primary key is ticket_nr which defaults to ticket_name.
#
#       This procedure does NOT include audit - please call audit
#       after updating DynField and other operations after the
#       creation of the ticket.
#
#        @author frank.bergmann@project-open.com
#	@return The object_id of the new (or existing) ticket
#    } {
#	array set vars $var_hash
#	set ticket_new_sql "
#		SELECT im_ticket__new (
#			:ticket_id,		-- p_ticket_id
#			'im_ticket',		-- object_type
#			now(),			-- creation_date
#			0,			-- creation_user
#			'0.0.0.0',		-- creation_ip
#			null,			-- context_id	
#			:ticket_name,
#			:ticket_customer_id,
#			:ticket_type_id,
#			:ticket_status_id
#		)
#	"
#
#	# Set defaults.
#	set ticket_name $vars(ticket_name)
#	set ticket_nr $ticket_name
#	set ticket_parent_id ""
#	set ticket_status_id [im_ticket_status_active]
#	set ticket_type_id [im_ticket_type_hardware]
#	set ticket_version ""
#	set ticket_owner_id [ad_conn user_id]
#	set description ""
#	set note ""
#
#	# Override defaults
#	if {[info exists vars(ticket_nr)]} { set ticket_nr $vars(ticket_nr) }
#	if {[info exists vars(ticket_code)]} { set ticket_code $vars(ticket_nr) }
#	if {[info exists vars(ticket_parent_id)]} { set ticket_parent_id $vars(ticket_parent_id) }
#	if {[info exists vars(ticket_status_id)]} { set ticket_status_id $vars(ticket_status_id) }
#	if {[info exists vars(ticket_type_id)]} { set ticket_type_id $vars(ticket_type_id) }
#	if {[info exists vars(ticket_version)]} { set ticket_version $vars(ticket_version) }
#	if {[info exists vars(ticket_owner_id)]} { set ticket_owner_id $vars(ticket_owner_id) }
#	if {[info exists vars(description)]} { set description $vars(description) }
#	if {[info exists vars(note)]} { set note $vars(note) }
#
#	# Check if the item already exists
#        set ticket_id [db_string exists "
#		select	ticket_id
#		from	im_tickets
#		where	ticket_parent_id = :ticket_parent_id and
#			ticket_nr = :ticket_nr
#	" -default 0]
#
#	# Create a new item if necessary
#        if {!$ticket_id} { set ticket_id [db_string new $ticket_new_sql] }
#
#	# Update the item with additional variables from the vars array
#	set sql_list [list]
#	foreach var [array names vars] {
#	    if {$var eq "ticket_id"} { continue }
#	    lappend sql_list "$var = :$var"
#	}
#	set sql "
#		update im_tickets set
#		[join $sql_list ",\n"]
#		where ticket_id = :ticket_id
#	"
#        db_dml update_ticket $sql
#
#
#	# Fraber 151215: No audit inside the ticket creation.
#	# Write Audit Trail
#	# im_audit -object_id $ticket_id -action after_update
#
#	return $ticket_id
#    }


    ad_proc -public new {
        -ticket_sla_id:required
        { -ticket_name "" }
        { -ticket_nr "" }
	{ -ticket_customer_contact_id "" }
	{ -ticket_type_id "" }
	{ -ticket_status_id "" }
	{ -ticket_start_date "" }
	{ -ticket_end_date "" }
	{ -ticket_note "" }
	{ -creation_date "" }
	{ -creation_user "" }
	{ -creation_ip "" }
	{ -context_id "" }
    } {
	Create a new ticket.
	This procedure deals with the base ticket creation.
	DynField values need to be stored extract.

	This procedure does NOT include audit - please call audit
	after updating DynField and other operations after the
	creation of the ticket.

	@author frank.bergmann@project-open.com
	@return <code>ticket_id</code> of the newly created project or "" in case of an error.
    } {
	set ticket_id ""
	set current_user_id $creation_user
	if {"" == $current_user_id} { set current_user_id [ad_conn user_id] }

	db_transaction {

	    # Set default input values
	    if {"" == $ticket_nr} { set ticket_nr [db_nextval im_ticket_seq] }
	    if {"" == $ticket_name} { set ticket_name $ticket_nr }    
	    if {"" == $ticket_start_date} { set ticket_start_date [db_string now "select now()::date from dual"] }
	    if {"" == $ticket_end_date} { set ticket_end_date [db_string now "select (now()::date)+1 from dual"] }
	    set start_date_sql [template::util::date get_property sql_date $ticket_start_date]
	    set end_date_sql [template::util::date get_property sql_timestamp $ticket_end_date]
	
	    # Create a new forum topic of type "Note"
	    set topic_id [db_nextval im_forum_topics_seq]

	    # Get customer from SLA
	    set ticket_customer_id [db_string cid "select company_id from im_projects where project_id = :ticket_sla_id" -default ""]
	    if {"" == $ticket_customer_id} { ad_return_complaint 1 "<b>Unable to create ticket:</b><br>No customer was specified for ticket" }

	    set ticket_name_exists_p [db_string pex "select count(*) from im_projects where project_name = :ticket_name"]
	    if {$ticket_name_exists_p} { ad_return_complaint 1 "<b>Unable to create ticket:</b><br>Ticket Name '$ticket_name' already exists." }

	    set ticket_nr_exists_p [db_string pnex "select count(*) from im_projects where project_nr = :ticket_nr and parent_id = :ticket_sla_id"]
	    if {$ticket_nr_exists_p} { ad_return_complaint 1 "<b>Unable to create ticket:</b><br>Ticket Nr '$ticket_nr' already exists." }

	    set ticket_id [db_string exists "select min(project_id) from im_projects where project_type_id = [im_project_type_ticket] and lower(project_nr) = lower(:ticket_nr)" -default ""]
	    if {"" == $ticket_id} {
		set ticket_id [db_string ticket_insert {}]
	    }
	    db_dml ticket_update {}
	    db_dml project_update {}

	    # Deal with OpenACS 5.4 "title" static title columm which is wrong:
	    if {[im_column_exists acs_objects title]} {
		db_dml object_update "update acs_objects set title = null where object_id = :ticket_id"
	    }

	    # Add the current user to the project
	    im_biz_object_add_role $current_user_id $ticket_id [im_biz_object_role_full_member]
	
	    # Start a new workflow case
	    im_workflow_start_wf -object_id $ticket_id -object_type_id $ticket_type_id -skip_first_transition_p 1
	    im_audit -object_id $ticket_id

	    # Fraber 151215: Audit doesn't work inside a transaction!
	    # Write Audit Trail
	    # im_audit -object_id $ticket_id -action after_update

	    # Create a new forum topic of type "Note"
	    set topic_type_id [im_topic_type_id_discussion]
	    set topic_status_id [im_topic_status_id_open]
	    set message ""

	    set topic_owner_id $current_user_id

	    # Frank: The owner of a topic can edit its content.
	    #        But we don't want customers to edit their stuff here...
	    # if {[im_user_is_customer_p $current_user_id]} { 
	    #	# set topic_owner_id [db_string admin "select min(user_id) from users where user_id > 0" -default 0]
	    # }
	    # Klaus: ...resolved differently to avoid confusion, see below 

	    if {"" == $ticket_note} { set ticket_note [lang::message::lookup "" intranet-helpdesk.Empty_Forum_Message "No message specified"]}

	    db_dml topic_insert {
                insert into im_forum_topics (
                        topic_id, object_id, parent_id,
                        topic_type_id, topic_status_id, owner_id,
                        subject, message
                ) values (
                        :topic_id, :ticket_id, null,
                        :topic_type_id, :topic_status_id, :topic_owner_id,
                        :ticket_name, :ticket_note
                )
	    }

	    # If ticket had been created by customer, he becomes automatically the ADMIN of the biz object
	    # This allows him editing all forum threads related to the ticket. Therfore we remove the relationship
	    set ticket_object_admins [im_biz_object_admin_ids $ticket_id]
	    foreach biz_object_id $ticket_object_admins {
		if { [im_profile::member_p -profile_id [im_customer_group_id] -user_id $biz_object_id] } {
		    # revoke relationship
		    if {[catch {
			set sql "delete from im_biz_object_members where rel_id in (select rel_id from acs_rels where object_id_one = :ticket_id and object_id_two=:biz_object_id and rel_type = 'im_biz_object_member')"
			db_dml delete_rel_id_from_im_biz_object_members $sql
			db_dml delete_rel_id_from_acs_rels "delete from acs_rels where object_id_one = :ticket_id and object_id_two=:biz_object_id"
		    } err_msg]} {
			ad_return_complaint 1 [lang::message::lookup "" intranet-helpdesk.ErrorRemovingCustomerFromTicket "Not able to remove Ticket-Customer relationship. Please contact your SysAdmin: $err_msg"]
			ad_script_abort
		    }
		}
	    }

	    # Subscribe owner to Notifications	    
	    im_ticket::notification_subscribe -ticket_id $ticket_id -user_id $current_user_id

	} on_error {
	    ad_return_complaint 1 "<b>Error inserting new ticket</b>:<br>&nbsp;<br>
	    <pre>$errmsg</pre>"
	}

	return $ticket_id 
    }


    ad_proc -public internal_sla_id { } {
	Determines the "internal" SLA: This SLA is used for handling
	meta-tickets, such as a request to create an SLA for a user.
	This SLA might also be used as a default if no other SLAs
	are available.

        @author frank.bergmann@project-open.com
	@return sla_id related to "internal company"
    } {
	# This company represents the "owner" of this ]po[ instance
	set internal_company_id [im_company_internal]

	set sla_id [db_string internal_sla "
		select	project_id
		from	im_projects
		where	company_id = :internal_company_id and
			project_type_id = [im_project_type_sla] and
			project_nr = 'internal_sla'
        " -default ""]

	if {"" == $sla_id} {
	    ad_return_complaint 1 "<b>Didn't find the 'Internal SLA'</b>:<br>
		We didn't find the 'internal' ticket container in the system. <br>
		This ticket container is used for requests from
		users such as creating a new ticket container.<br>
		Please Contact your System Administrator to setup this ticket container.
		It needs to fulfill <br>
		the following conditions:<p>&nbsp;</p>
		<ul>
		<li>Customer: the 'Internal Company'<br>
		    (the company with the path 'internal' that represents
		    the organization running this system)</li>
		<li>Project Type: 'Ticket Container'</li>
		<li>Project Nr: 'internal_sla' (in lower case)
		</ul>
	    "
	}
	return $sla_id
    }


    ad_proc -public notification_subscribe {
        -ticket_id:required
	{ -user_id "" }
    } {
	Subscribe a user to notifications on a specific	ticket.
        @author frank.bergmann@project-open.com
    } {
	if {"" == $user_id} { set user_id [ad_conn user_id] }
	set type_id [notification::type::get_type_id -short_name "ticket_notif"]
	set interval_id [notification::get_interval_id -name "instant"]
	set delivery_method_id [notification::get_delivery_method_id -name "email"]

	notification::request::new \
	    -type_id $type_id \
	    -user_id $user_id \
	    -object_id $ticket_id \
	    -interval_id $interval_id \
	    -delivery_method_id $delivery_method_id
    }

    ad_proc -public notification_unsubscribe {
        -ticket_id:required
	{ -user_id "" }
    } {
	Unsubscribe a user to notifications on a specific ticket.
        @author frank.bergmann@project-open.com
    } {
	if {"" == $user_id} { set user_id [ad_conn user_id] }

	# Get list of requests. We don't want to use a db_foreach
	# because we don't know how many database connections the unsubscribe
	# action needs...
	set request_ids [db_list requests "
		select	request_id
		from	notification_requests
		where	object_id = :ticket_id and
			user_id = :user_id
	"]

	foreach request_id $request_ids {
	    # Security Check
	    notification::security::require_admin_request -request_id $request_id

	    # Actually Delete
	    notification::request::delete -request_id $request_id
	}
    }

    ad_proc -public add_reply {
        -ticket_id:required
	-subject:required
	{-message "" }
    } {
	Add a comment to the ticket as forum topic of type "reply".
    } {
	# Create a new forum topic of type "Reply"
	set current_user_id [ad_conn user_id]
	set topic_id [db_nextval im_forum_topics_seq]
	set parent_topic_id [db_string topic_id "select min(topic_id) from im_forum_topics where object_id = :ticket_id" -default ""]
	set topic_type_id [im_topic_type_id_reply]
	set topic_status_id [im_topic_status_id_open]

	# The owner of a topic can edit its content.
	# But we don't want customers to edit their stuff here...
	set topic_owner_id $current_user_id
	if {[im_user_is_customer_p $current_user_id]} { 
	    set topic_owner_id [db_string admin "select min(user_id) from users where user_id > 0" -default 0]
	}

	db_dml topic_insert "
	    insert into im_forum_topics (
                        topic_id, object_id, parent_id,
                        topic_type_id, topic_status_id, owner_id,
                        subject, message
                ) values (
                        :topic_id, :ticket_id, :parent_topic_id,
                        :topic_type_id, :topic_status_id, :current_user_id,
                        :subject, :message
                )
        "

	# Write Audit Trail
	im_audit -object_id $ticket_id -action after_update
    }

    ad_proc -public check_permissions {
	{-check_only_p 0}
	-ticket_id:required
        -operation:required
    } {
	Check if the user can perform view, read, write or admin the ticket
    } {
	set user_id [ad_conn user_id]
	set user_name [im_name_from_user_id $user_id]
	im_ticket_permissions $user_id $ticket_id view read write admin
	if {[lsearch {view read write admin} $operation] < 0} { 
	    ad_return_complaint 1 "Invalid operation '$operation':<br>Expected view, read, write or admin"
	    ad_script_abort
	}
	set perm [set $operation]

	# Just return the result check_only_p is set
	if {$check_only_p} { return $perm }

 	if {!$perm} { 
	    set action_forbidden_msg [lang::message::lookup "" intranet-helpdesk.Forbidden_operation_on_ticket "
	    <b>Unable to perform operation '%operation%'</b>:<br>You don't have the necessary permissions for ticket #%ticket_id%."]
	    ad_return_complaint 1 $action_forbidden_msg 
	    ad_script_abort
	}
	return $perm
    }

    ad_proc -public set_status_id {
	-ticket_id:required
        -ticket_status_id:required
    } {
        Set the ticket to the specified status.
	The procedure deals with some special cases
    } {
	set user_id [ad_conn user_id]
	set user_name [im_name_from_user_id $user_id]

	# Fraber 140202: Permission should be checked using check_permissions above!
	# im_ticket_permissions $user_id $ticket_id view read write admin
	db_dml update_ticket_status "
		update im_tickets set 
			ticket_status_id = :ticket_status_id
		where ticket_id = :ticket_id
	"

	# Add a message to the forum
	set ticket_status [im_category_from_id $ticket_status_id]
	im_ticket::add_reply -ticket_id $ticket_id -subject \
	    [lang::message::lookup "" intranet-helpdesk.Set_to_status_by_user "Set to status '%ticket_status%' by %user_name%"]


	# Set the status of the underlying project depending on the ticket status
	set project_status_id ""
	if {[im_category_is_a $ticket_status_id [im_ticket_status_open]]} { set project_status_id [im_project_status_open] }
	if {[im_category_is_a $ticket_status_id [im_ticket_status_closed]]} { set project_status_id [im_project_status_closed] }
	if {"" != $project_status_id} {
	    db_dml update_ticket_project_status "
		update im_projects set 
			project_status_id = [im_project_status_closed]
		where project_id = :ticket_id
	    "
	} else {
	    ad_return_complaint 1 "Internal Error: Found invalid ticket_status_id=$ticket_status_id"
	    ad_script_abort
	}

	im_audit -object_id $ticket_id -action after_update
    }


    ad_proc -public close_workflow {
	-ticket_id:required
    } {
        Stop the ticket workflow.
    } {
	# Cancel associated workflow
	im_workflow_cancel_workflow -object_id $ticket_id
    }

    ad_proc -public audit {
	-ticket_id:required
	-action:required
    } {
        Write the audit trail
    } {
	# Write Audit Trail
	im_audit -object_id $ticket_id -action $action
    }

    ad_proc -public close_forum {
	-ticket_id:required
    } {
        Set the ticket forum to "deleted"
    } {
	# Mark the topic as closed
	db_dml mark_as_closed "
			update im_forum_topics
        	        set topic_status_id = [im_topic_status_id_closed]
			where	parent_id is null and
				object_id = :ticket_id
	"

	# Close associated forum by moving to "deleted" folder
	db_dml move_to_deleted "
			update im_forum_topic_user_map
        	        set folder_id = 1
                	where topic_id in (
				select	t.topic_id
				from	im_forum_topics t
				where	t.parent_id is null and
					t.object_id = :ticket_id
			)
	"
    }

    ad_proc -public update_timestamp {
	-timestamp:required
	-ticket_id:required
    } {
        Set the specified timestamp(s) to now()
    } {
	foreach ts $timestamp {
	    switch $ts {
		done		{ set column "ticket_done_date" }
		default 	{ set column "" }
	    }
	    if {"" != $column} {
	        db_dml update_ticket_timestamp "
			update im_tickets set 
				ticket_done_date = now()
			where ticket_id = :ticket_id
	        "
	    }
	}
	im_audit -object_id $ticket_id -action after_update
    }

}


namespace eval im_ticket::notification {

    ad_proc -public get_url {
        object_id
    } {
        # Todo:
    }
}


# ----------------------------------------------------------------------
# Ticket - Project Relationship
# ---------------------------------------------------------------------

ad_proc -public im_helpdesk_new_ticket_ticket_rel {
    -ticket_id_from_search:required
    -ticket_id:required
    {-sort_order 0}
} {
    Mark the ticket (ticket_id) as a duplicate of ticket_id_from_search
} {
    if {"" == $ticket_id_from_search} { ad_return_complaint 1 "Internal Error - ticket_id_from_search is NULL" }
    if {"" == $ticket_id} { ad_return_complaint 1 "Internal Error - ticket_id is NULL" }

    set rel_id [db_string rel_exists "
	select	rel_id
	from	acs_rels
	where	object_id_one = :ticket_id and
		object_id_two = :ticket_id_from_search
    " -default 0]
    if {0 != $rel_id} { return $rel_id }

    return [db_string new_ticket_ticket_rel "
		select im_ticket_ticket_rel__new (
			null,			-- rel_id
			'im_ticket_ticket_rel',	-- rel_type
			:ticket_id,		-- object_id_one
			:ticket_id_from_search,	-- object_id_two
			null,			-- context_id
			[ad_conn user_id],	-- creation_user
			'[ns_conn peeraddr]',	-- creation_ip
			:sort_order		-- sort_order
		)
    "]
}


# ----------------------------------------------------------------------
# Selects & Options
# ---------------------------------------------------------------------

ad_proc -public im_ticket_options {
    {-include_empty_p 1}
    {-include_empty_name "" }
    {-maxlen_name 50 }
} {
    Returns a list of Tickets suitable for ad_form
} {
    set user_id [ad_conn user_id]

    set ticket_sql "
	select	child.*,
		t.*
	from	im_projects child,
		im_projects parent,
		im_tickets t
	where	parent.parent_id is null and
		child.project_id = t.ticket_id and
		child.tree_sortkey between parent.tree_sortkey and tree_right(parent.tree_sortkey)
	order by
		child.project_nr,
		child.project_name
    "

    set options [list]
    db_foreach tickets $ticket_sql {
	lappend options [list "$project_nr - [string range $project_name 0 $maxlen_name]" $ticket_id]
    }

    if {$include_empty_p} { set options [linsert $options 0 "$include_empty_name {}"] }

    return $options
}



ad_proc -public im_helpdesk_ticket_queue_options {
    {-mine_p 0}
    {-include_empty_p 1}
} {
    Returns a list of Ticket Queue tuples suitable for ad_form
} {
    set user_id [ad_conn user_id]

    set sql "
	select
		g.group_name,
		g.group_id
	from
		groups g,
		im_ticket_queue_ext q
	where
		g.group_id = q.group_id
	order by
		g.group_name
    "

    set options [list]
    db_foreach groups $sql {
	regsub -all " " $group_name "_" group_key
	set name [lang::message::lookup "" intranet-helpdesk.group_key $group_name]
	lappend options [list $name $group_id]
    }

    set options [db_list_of_lists company_options $sql]
    if {$include_empty_p} { set options [linsert $options 0 { "" "" }] }

    return $options
}


ad_proc -public im_helpdesk_ticket_sla_options {
    {-user_id 0 }
    {-mine_p 0}
    {-customer_id 0}
    {-include_empty_p 1}
    {-include_create_sla_p 0}
    {-include_internal_sla_p 0}
    {-include_default_option 0}
} {
    Returns a list of SLA tuples suitable for ad_form
    on which the current_user_id can add tickets
} {
    if {0 == $user_id} { set user_id [ad_conn user_id] }
    set sla_name_sql [parameter::get_from_package_key -package_key "intranet-helpdesk" -parameter "RenderSlaNameSql" -default "project_name"]

    # Determine the list of all groups in which the current user is a member
    set user_parties [im_profile::profiles_for_user -user_id $user_id]
    lappend user_parties $user_id

    # Don't offer to create a new SLA if the user doesn't have the rights to do so...
    if {![im_permission $user_id "add_projects"]} {
        set include_create_sla_p 0
    }

    # Is it enough to be a member of a customer to see all SLAs?
    set customer_member_is_sla_member_p [parameter::get_from_package_key -package_key "intranet-helpdesk" -parameter "TreatCustomerMembersAsSLAMembersP" -default 0]
    set customer_member_sla_sql ""
    if {$customer_member_is_sla_member_p} {
	set customer_member_sla_sql "
		UNION select project_id from im_projects where company_id in (
			select	object_id_one
			from	acs_rels
			where	object_id_two in ([join $user_parties ","])
                )
        "
    }

    # Can the user see all projects?
    set permission_sql "and p.project_id in (
		select object_id_one from acs_rels where object_id_two in ([join $user_parties ","]) UNION 
		select project_id from im_projects where company_id = :customer_id
		$customer_member_sla_sql
    )"

    set sql "
	select distinct
		$sla_name_sql as sla_name,
		project_id
	from	(
		select	p.*, c.*
		from	im_projects p,
			im_companies c,
			im_projects main_p
		where	p.company_id = c.company_id and
			main_p.tree_sortkey = tree_root_key(p.tree_sortkey) and
			p.project_status_id not in ([join [im_sub_categories [im_project_status_closed]] ","]) and
			p.project_type_id = [im_project_type_sla] and
			main_p.project_status_id not in ([join [im_sub_categories [im_project_status_closed]] ","])
	UNION
		select	p.*, c.*
		from	im_projects p,
			im_companies c
		where	p.company_id = c.company_id and
			p.project_id = :include_default_option
		) p
	where	1=1
		$permission_sql
    "

    # "Internal SLA" Logic - Remove the Internal SLA from the list
    # if there is an SLA specific to the user.
    if {!$include_internal_sla_p} {
	set count [db_string sla_count "select count(*) from ($sql) t"]
	if {$count > 1} {
	    append sql "\t\tand p.project_nr != 'internal_sla'"
	}
    }

    append sql "\t\torder by sla_name"


    set options [list]
    db_foreach slas $sql {
	lappend options [list $sla_name $project_id]
    }

    if {$include_create_sla_p} { set options [linsert $options 0 [list [lang::message::lookup "" intranet-helpdesk.New_SLA "New SLA"] "new"]] }
    if {$include_empty_p} { set options [linsert $options 0 { "" "" }] }

    return $options
}




# ----------------------------------------------------------------------
# Portlets
# ---------------------------------------------------------------------

ad_proc -public im_helpdesk_similar_tickets_component {
    -ticket_id:required
} {
    Returns a HTML table with a list of tickets that are somehow
    "related" to the current ticket based on full-text similarity,
    configuration items, users etc.
} {
    set params [list \
                    [list ticket_id $ticket_id] \
    ]

    set result [ad_parse_template -params $params "/packages/intranet-helpdesk/lib/similar-tickets"]
    return [string trim $result]
}


ad_proc -public im_ticket_timeline_component {
    -ticket_id:required
} {
    A set of dates during a ticket lifecycle
} {
    set params [list \
                    [list ticket_id $ticket_id] \
    ]

    set result [ad_parse_template -params $params "/packages/intranet-helpdesk/lib/ticket-timeline"]
    return [string trim $result]
}


ad_proc -public im_helpdesk_home_component {
    {-show_empty_ticket_list_p 1}
    {-view_name "ticket_personal_list" }
    {-order_by_clause ""}
    {-ticket_type_id 0}
    {-ticket_status_id 0}
} {
    Returns a HTML table with the list of tickets of the
    current user. 

    @param show_empty_ticket_list_p Should we show an empty ticket list?
           Setting this parameter to 0 the component will just disappear
           if there are no tickets.
} {
    return [im_helpdesk_ticket_component \
		-show_empty_ticket_list_p $show_empty_ticket_list_p \
		-view_name $view_name \
		-ticket_user_id [ad_conn user_id] \
		-order_by_clause $order_by_clause \
		-ticket_type_id $ticket_type_id \
		-ticket_status_id $ticket_status_id \
    ]
}



ad_proc -public im_helpdesk_project_component {
    {-project_id 0}
} {
    Returns a HTML table with the list of tickets for the current
    project.
} {
    if {![im_project_has_type $project_id [im_project_type_ticket_container]]} { return "" }
    set view_name "ticket_project_list"

    return [im_helpdesk_ticket_component \
		-show_empty_ticket_list_p 1 \
		-view_name $view_name \
		-ticket_sla_id $project_id \
    ]
}



ad_proc -public im_helpdesk_ticket_component {
    {-show_empty_ticket_list_p 1}
    {-view_name "ticket_personal_list" }
    {-ticket_user_id 0}
    {-order_by_clause ""}
    {-ticket_type_id 0}
    {-ticket_status_id 0}
    {-ticket_sla_id 0}
    {-limit 10}
} {
    Returns a HTML table with the list of tickets of the
    current user. Don't do any fancy sorting and pagination, 
    because a single user won't be a member of many active tickets.

    @param show_empty_ticket_list_p Should we show an empty ticket list?
           Setting this parameter to 0 the component will just disappear
           if there are no tickets.
} {
    if {"" == $order_by_clause} {
	set order_by_clause  [parameter::get_from_package_key -package_key "intranet-helpdesk" -parameter "HomeTicketListSortClause" -default "p.project_nr DESC"]
    }
    set org_order_by_clause $order_by_clause

    # Determine the list of all groups in which the current user is a member
    set ticket_user_parties [im_profile::profiles_for_user -user_id $ticket_user_id]
    lappend user_parties $ticket_user_id
    # ([join $user_parties ","])


    # ---------------------------------------------------------------
    # Columns to show:

    set view_id [db_string get_view_id "select view_id from im_views where view_name=:view_name"]
    set column_headers [list]
    set column_vars [list]
    set extra_selects [list]
    set extra_froms [list]
    set extra_wheres [list]

    set column_sql "
	select	*
	from	im_view_columns
	where	view_id = :view_id and group_id is null
	order by sort_order
    "

    db_foreach column_list_sql $column_sql {
	if {"" == $visible_for || [eval $visible_for]} {
	    lappend column_headers "$column_name"
	    lappend column_vars "$column_render_tcl"
	}
	if {"" != $extra_select} { lappend extra_selects $extra_select }
	if {"" != $extra_from} { lappend extra_froms $extra_from }
	if {"" != $extra_where} { lappend extra_wheres $extra_where }
    }

    # ---------------------------------------------------------------
    # Generate SQL Query

    set extra_select [join $extra_selects ",\n\t"]
    set extra_from [join $extra_froms ",\n\t"]
    set extra_where [join $extra_wheres "and\n\t"]
    if { $extra_select ne "" } { set extra_select ",\n\t$extra_select" }
    if { $extra_from ne "" } { set extra_from ",\n\t$extra_from" }
    if { $extra_where ne "" } { set extra_where "and\n\t$extra_where" }

    if {0 == $ticket_status_id} { set ticket_status_id [im_ticket_status_open] }


    set ticket_status_restriction ""
    if {0 != $ticket_status_id} { set ticket_status_restriction "and t.ticket_status_id in ([join [im_sub_categories $ticket_status_id] ","])" }

    set ticket_type_restriction ""
    if {0 != $ticket_type_id} { set ticket_type_restriction "and t.ticket_type_id in ([join [im_sub_categories $ticket_type_id] ","])" }

    set ticket_sla_restriction ""
    if {0 != $ticket_sla_id} { set ticket_sla_restriction "and p.parent_id = :ticket_sla_id" }

    if {0 != $ticket_user_id} {
	set perm_sql "
	(select
		p.*
	from
	        im_tickets t,
		im_projects p
	where
		t.ticket_id = p.project_id
		and (
			t.ticket_assignee_id = :ticket_user_id 
			OR t.ticket_customer_contact_id = :ticket_user_id
			OR t.ticket_queue_id in (
				select distinct
					g.group_id
				from	acs_rels r, groups g 
				where	r.object_id_one = g.group_id and
					r.object_id_two in ([join $ticket_user_parties ","])
			)
			OR p.project_id in (	
				-- cases with user as task holding_user
				select distinct wfc.object_id
				from	wf_tasks wft,
					wf_cases wfc
				where	wft.state in ('enabled', 'started') and
					wft.case_id = wfc.case_id and
					wft.holding_user = :ticket_user_id
			) OR p.project_id in (
				-- cases with user as task_assignee
				select distinct wfc.object_id
				from	wf_task_assignments wfta,
					wf_tasks wft,
					wf_cases wfc
				where	wft.state in ('enabled', 'started') and
					wft.case_id = wfc.case_id and
					wfta.task_id = wft.task_id and
					wfta.party_id in ([join $ticket_user_parties ","])
			)
		)
		and t.ticket_status_id not in ([im_ticket_status_deleted], [im_ticket_status_closed])
		$ticket_status_restriction
		$ticket_type_restriction
		$ticket_sla_restriction
	)"
    } else {
	set perm_sql "
	(select
		p.*
	from
	        im_tickets t,
		im_projects p
	where
		t.ticket_id = p.project_id and 
		t.ticket_status_id not in ([im_ticket_status_deleted], [im_ticket_status_closed])
		$ticket_status_restriction
		$ticket_type_restriction
		$ticket_sla_restriction
	)"
    }

    set personal_ticket_query "
	SELECT
		p.*,
		t.*,
		to_char(p.end_date, 'YYYY-MM-DD HH24:MI') as end_date_formatted,
	        c.company_name,
	        im_category_from_id(t.ticket_type_id) as ticket_type,
	        im_category_from_id(t.ticket_status_id) as ticket_status,
	        im_category_from_id(t.ticket_prio_id) as ticket_prio,
	        to_char(end_date, 'HH24:MI') as end_date_time,
		im_name_from_user_id(t.ticket_assignee_id) as ticket_assignee_name,
		im_name_from_user_id(t.ticket_customer_contact_id) as ticket_customer_contact_name
                $extra_select
	FROM
		$perm_sql p,
		im_tickets t,
		im_companies c
                $extra_from
	WHERE
		p.project_id = t.ticket_id and
		p.company_id = c.company_id
		$ticket_status_restriction
		$ticket_type_restriction
                $extra_where
	order by $org_order_by_clause
    "
    
    if {"" != $limit} {
	append personal_ticket_query "LIMIT $limit\n"
    }

    
    # ---------------------------------------------------------------
    # Format the List Table Header

    # Set up colspan to be the number of headers + 1 for the # column
    set colspan [expr {[llength $column_headers] + 1}]

    set table_header_html "<tr>\n"
    foreach col $column_headers {
	regsub -all " " $col "_" col_txt
	set col_txt [lang::message::lookup "" intranet-core.$col_txt $col]
	append table_header_html "  <td class=\"rowtitle\">$col_txt</td>\n"
    }
    append table_header_html "</tr>\n"

    # ---------------------------------------------------------------
    # Format the Result Data

    set url "index?"
    set table_body_html ""
    set bgcolor(0) " class=roweven "
    set bgcolor(1) " class=rowodd "
    set ctr 0
    db_foreach personal_ticket_query $personal_ticket_query {

	set url [im_maybe_prepend_http $url]
	if { $url eq "" } {
	    set url_string "&nbsp;"
	} else {
	    set url_string "<a href=\"$url\">$url</a>"
	}
	
	# Append together a line of data based on the "column_vars" parameter list
	set row_html "<tr$bgcolor([expr {$ctr % 2}])>\n"
	foreach column_var $column_vars {
	    append row_html "\t<td class=\"list\">"
	    set cmd "append row_html $column_var"
	    eval "$cmd"
	    append row_html "</td>\n"
	}
	append row_html "</tr>\n"
	append table_body_html $row_html
	
	incr ctr
    }

    # Show a reasonable message when there are no result rows:
    if { $table_body_html eq "" } {

	# Let the component disappear if there are no tickets...
	if {!$show_empty_ticket_list_p} { return "" }

	set table_body_html "
	    <tr><td colspan=\"$colspan\"><ul><li><b> 
	    [lang::message::lookup "" intranet-core.lt_There_are_currently_n "There are currently no entries matching the selected criteria"]
	    </b></ul></td></tr>
	"
    }

    # Building link to create new ticket
    set line_create_ticket ""
    if { [im_permission [ad_conn user_id] add_tickets] } {
	# set url_create_ticket [export_vars -base "/intranet-helpdesk/new" {{form_mode edit} {form_id ticket_new} ticket_sla_id}]
	set url_create_ticket [export_vars -base "/intranet-helpdesk/new" ]
	set link_create_ticket "<a href='$url_create_ticket'> [lang::message::lookup "" intranet-helpdesk.Add_a_new_ticket "New ticket"]</a>"
	set line_create_ticket "<tr><td colspan='99'align='left'><ul><li>$link_create_ticket</li></ul></td></tr>"
    }

    return "
	<table class=\"table_component\" width=\"100%\">
	<thead>$table_header_html</thead>
	<tbody>$table_body_html</tbody>
	$line_create_ticket
	</table><br/>
    "
}



# ----------------------------------------------------------------------
# Navigation Bar Tree
# ---------------------------------------------------------------------

ad_proc -public im_navbar_tree_helpdesk { 
    -user_id:required
    { -locale "" }
} {
    Creates an <ul> ...</ul> collapsable menu for the
    system's main NavBar.
} {
    set current_user_id [ad_conn user_id]
    set wiki [im_navbar_doc_wiki]

    set html "
	<li><a href=\"/intranet-helpdesk/index\">[lang::message::lookup "" intranet-helpdesk.Service_Mgmt "IT Service Management"]</a>
	<ul>
	<li><a href=\"$wiki/module-itsm\">[lang::message::lookup "" intranet-core.ITSM_Help "ITSM Help"]</a>
    "

    # --------------------------------------------------------------
    # Tickets
    # --------------------------------------------------------------

    # Create new Ticket
    if {[im_permission $current_user_id "add_tickets"]} {
	append html "<li><a href=\"/intranet-helpdesk/new\">[lang::message::lookup "" intranet-helpdesk.New_Ticket "New Ticket"]</a>\n"
    }

    if {[im_permission $current_user_id "view_tickets_all"]} {
	# Add sub-menu with types of tickets
	append html "
		<li><a href=\"/intranet-helpdesk/index\">[lang::message::lookup "" intranet-helpdesk.Ticket_Types "Ticket Types"]</a>
		<ul>
        "
	set ticket_type_sql "select * from im_ticket_types order by ticket_type"
	db_foreach ticket_types $ticket_type_sql {
	    set url [export_vars -base "/intranet-helpdesk/index" {ticket_type_id}]
	    regsub -all " " $ticket_type "_" ticket_type_subst
	    set name [lang::message::lookup "" intranet-helpdesk.Ticket_type_$ticket_type_subst "${ticket_type}s"]
	    append html "<li><a href=\"$url\">$name</a></li>\n"
	}
	append html "
		</ul>
		</li>
        "
    }

    append html "
	[if {![catch {set ttt [im_navbar_tree_confdb]}]} {set ttt} else {set ttt ""}]
	[if {![catch {set ttt [im_navbar_tree_release_mgmt]}]} {set ttt} else {set ttt ""}]
	[if {![catch {set ttt [im_navbar_tree_bug_tracker]}]} {set ttt} else {set ttt ""}]
	[im_navbar_tree_helpdesk_ticket_type -base_ticket_type_id [im_ticket_type_incident_ticket] -base_ticket_type [lang::message::lookup "" intranet-helpdesk.Incident_ticket_type "Incident"]]
	[im_navbar_tree_helpdesk_ticket_type -base_ticket_type_id [im_ticket_type_problem_ticket] -base_ticket_type [lang::message::lookup "" intranet-helpdesk.Problem_ticket_type "Problem"]]
	[im_navbar_tree_helpdesk_ticket_type -base_ticket_type_id [im_ticket_type_change_ticket] -base_ticket_type [lang::message::lookup "" intranet-helpdesk.Change_ticket_type "Change"]]
    "



    # --------------------------------------------------------------
    # SLAs
    # --------------------------------------------------------------

    set sla_url [export_vars -base "/intranet/projects/index" {{project_type_id [im_project_type_sla]}}]
    append html "
	<li><a href=\"$sla_url\">[lang::message::lookup "" intranet-helpdesk.SLA_Management "SLA Management"]</a>
	<ul>
    "

    # Add list of SLAs
    if {[im_permission $current_user_id "add_projects"]} {
	set url [export_vars -base "/intranet/projects/new" {{project_type_id [im_project_type_sla]}}]
	set name [lang::message::lookup "" intranet-helpdesk.New_SLA "New SLA"]
	append html "<li><a href=\"$url\">$name</a></li>\n"
    }

    if {$current_user_id > 0} {
	set url [export_vars -base "/intranet/projects/index" {{project_type_id [im_project_type_sla]}}]
	set name [lang::message::lookup "" intranet-helpdesk.SLA_List "SLAs"]
	append html "<li><a href=\"$url\">$name</a></li>\n"
    }

    append html "
	</ul>
	</li>
    "

    # --------------------------------------------------------------
    # End of ITSM
    # --------------------------------------------------------------

    append html "
	</ul>
	</li>
    "
    return $html
}


ad_proc -public im_navbar_tree_helpdesk_ticket_type { 
    -base_ticket_type_id:required
    -base_ticket_type:required
} { 
    Show one of {Issue|Incident|Problem|Change} Management
} {
    set current_user_id [ad_conn user_id]
    set wiki [im_navbar_doc_wiki]

    set html "
	<li><a href=\"/intranet-helpdesk/index\">[lang::message::lookup "" intranet-helpdesk.${base_ticket_type}_Management "$base_ticket_type Management"]</a>
	<ul>
    "

    if {0 == $current_user_id} { return "$html</ul>\n" }

    # Create a new Ticket
    set url [export_vars -base "/intranet-helpdesk/new" {base_ticket_type_id}]
    set name [lang::message::lookup "" intranet-helpdesk.New_${base_ticket_type}_Ticket "New $base_ticket_type Ticket"]
    append html "<li><a href=\"$url\">$name</a>\n"

    # Add sub-menu with types of tickets
    append html "
	<li><a href=\"[export_vars -base "/intranet-helpdesk/index" {base_ticket_type_id}]\">$base_ticket_type Ticket Types</a>
	<ul>
    "
    set ticket_type_sql "
	select	*
	from	im_ticket_types
	where	ticket_type_id in ([join [im_sub_categories $base_ticket_type_id] ","])
	order by ticket_type
    "
    db_foreach ticket_types $ticket_type_sql {
	set url [export_vars -base "/intranet-helpdesk/index" {ticket_type_id}]
        regsub -all " " $ticket_type "_" ticket_type_subst
	set name [lang::message::lookup "" intranet-helpdesk.Ticket_type_$ticket_type_subst "${ticket_type}s"]
	append html "<li><a href=\"$url\">$name</a></li>\n"
    }
    append html "
	</ul>
	</li>
    "

    append html "
	</ul>
	</li>
    "
    return $html
}


# ---------------------------------------------------------------
# Component showing related objects
# ---------------------------------------------------------------

ad_proc -public im_helpdesk_related_objects_component {
    -ticket_id:required
} {
    Returns a HTML component with the list of related tickets.
} {
    set params [list \
                    [list base_url "/intranet-helpdesk/"] \
                    [list ticket_id $ticket_id] \
                    [list return_url [im_url_with_query]] \
    ]

    set result [ad_parse_template -params $params "/packages/intranet-helpdesk/www/related-objects-component"]
    return [string trim $result]
}

ad_proc -public im_helpdesk_related_tickets_component {
    -ticket_id:required
} {
    Replaced by im_helpdesk_related_objects_component
} {
    return ""
}





# ---------------------------------------------------------------
# Nuke
# ---------------------------------------------------------------

ad_proc im_ticket_nuke {
    {-current_user_id 0}
    ticket_id
} {
    Nuke (complete delete from the database) a ticket.
    Returns an empty string if everything was OK or an error
    string otherwise.
} {
    ns_log Notice "im_ticket_nuke ticket_id=$ticket_id"
    return [im_project_nuke -current_user_id $current_user_id $ticket_id]
}


ad_proc -public im_menu_tickets_admin_links {

} {
    Return a list of admin links to be added to the "projects" menu
} {
    set result_list {}
    set current_user_id [ad_conn user_id]
    set return_url [im_url_with_query]


    if {[im_is_user_site_wide_or_intranet_admin $current_user_id]} {
        lappend result_list [list [lang::message::lookup "" intranet-helpdesk.Admin_Helpdesk "Admin Helpdesk"] "/intranet-helpdesk/admin/"]
	lappend result_list [list [lang::message::lookup "" intranet-helpdesk.Admin_Helpdesk_Queues "Admin Helpdesk Queues"] "/admin/group-types/one?group_type=im_ticket_queue"]
    }

    if {[im_permission $current_user_id "add_tickets"]} {
#        lappend result_list [list [lang::message::lookup "" intranet-helpdesk.Add_a_new_ticket "New Ticket"] "[export_vars -base "/intranet-helpdesk/new" {ticket_sla_id return_url}]"]

	set wf_oid_col_exists_p [im_column_exists wf_workflows object_type]
	if {$wf_oid_col_exists_p} {
        set wf_sql "
                select  t.pretty_name as wf_name,
                        w.*
                from    wf_workflows w,
                        acs_object_types t
                where   w.workflow_key = t.object_type
                        and w.object_type = 'im_ticket'
        "
	    db_foreach wfs $wf_sql {
		set new_from_wf_url [export_vars -base "/intranet-helpdesk/new" {workflow_key}]
		lappend result_list [list [lang::message::lookup "" intranet-helpdesk.New_workflow "New %wf_name%"] "$new_from_wf_url"]
	    }
	}
    }

    # Append user-defined menus
    set bind_vars [list return_url $return_url]
    set links [im_menu_ul_list -no_uls 1 -list_of_links 1 "tickets_admin" $bind_vars]
    foreach link $links {
        lappend result_list $link
    }

    return $result_list
}



# ---------------------------------------------------------------
# 
# ---------------------------------------------------------------

ad_proc -public im_helpdesk_ticket_aging_diagram {
    {-ticket_customer_contact_dept_id 0 }
    {-ticket_customer_contact_id 0 }
    {-ticket_assignee_dept_id 0 }
    {-ticket_sla_id 0 }
    {-ticket_type_id 0 }
    {-ticket_status_id 0 }
    {-ticket_prio_id 0 }
    {-exclude_ticket_type_ids "" }
    {-exclude_ticket_status_ids "" }
    {-exclude_ticket_prio_ids "" }
    {-diagram_width ""}
    {-diagram_height ""}
    {-diagram_title ""}
    {-diagram_font ""}
    {-diagram_theme ""}
    {-diagram_limit ""}
    {-diagram_inset_padding ""}
    {-diagram_tooltip_width ""}
    {-diagram_tooltip_height ""}
    {-diagram_legend_width ""}
    {-diagram_ticket_sla_id ""}
} {
    Returns a HTML component with a pie chart with top customer
} {
    # Compatibility
    if {"" ne $diagram_ticket_sla_id} { set ticket_sla_id $diagram_ticket_sla_id }

    if {"" != $ticket_sla_id && 0 != $ticket_sla_id} {
	if {[im_security_alert_check_integer -location "im_helpdesk_ticket_aging_diagram" -value $ticket_sla_id]} { return }
	set project_type_id [util_memoize [list db_string project_type "select project_type_id from im_projects where project_id = $ticket_sla_id" -default 0]]
	if {![im_category_is_a $project_type_id [im_project_type_sla]]} { return }
    }

    # Sencha check and permissions
    if {![im_sencha_extjs_installed_p]} { return "" }
    set current_user_id [ad_conn user_id]

    # Fraber 150420: No need for permissions, really, because no critical information is shown
    # if {![im_permission $current_user_id view_tickets_all]} { return "" }
    im_sencha_extjs_load_libraries

    # Call the portlet page
    set params [list \
                    [list ticket_customer_contact_dept_id $ticket_customer_contact_dept_id] \
                    [list ticket_customer_contact_id $ticket_customer_contact_id] \
                    [list ticket_assignee_dept_id $ticket_assignee_dept_id] \
                    [list ticket_sla_id $ticket_sla_id] \
                    [list ticket_type_id $ticket_type_id] \
                    [list ticket_status_id $ticket_status_id] \
                    [list exclude_ticket_type_ids $exclude_ticket_type_ids] \
                    [list exclude_ticket_status_ids $exclude_ticket_status_ids] \
                    [list exclude_ticket_prio_ids $exclude_ticket_prio_ids] \
                    [list diagram_width $diagram_width] \
                    [list diagram_height $diagram_height] \
                    [list diagram_title $diagram_title] \
                    [list diagram_font $diagram_font] \
                    [list diagram_theme $diagram_theme] \
                    [list diagram_limit $diagram_limit] \
                    [list diagram_padding $diagram_inset_padding] \
                    [list diagram_tooltip_width $diagram_tooltip_width] \
                    [list diagram_tooltip_height $diagram_tooltip_height] \
                    [list diagram_legend_width $diagram_legend_width] \
    ]

    set result [ad_parse_template -params $params "/packages/intranet-helpdesk/lib/ticket-aging"]
    return [string trim $result]
}



# ---------------------------------------------------------------
# 
# ---------------------------------------------------------------

ad_proc -public im_helpdesk_ticket_age_number_per_queue {
    {-ticket_customer_contact_id 0}
    {-diagram_width ""}
    {-diagram_height ""}
    {-diagram_title ""}
    {-diagram_font ""}
    {-diagram_theme ""}
} {
    Returns a HTML component with a bar chart with tickets and age per queue
} {
    # Sencha check and permissions
    if {![im_sencha_extjs_installed_p]} { return "" }
    set current_user_id [ad_conn user_id]

    # No need for permissions, really, because no critical information is shown
    # if {![im_permission $current_user_id view_tickets_all]} { return "" }
    im_sencha_extjs_load_libraries

    # Call the portlet page
    set params [list \
                    [list ticket_customer_contact_id $ticket_customer_contact_id] \
                    [list diagram_width $diagram_width] \
                    [list diagram_height $diagram_height] \
                    [list diagram_title $diagram_title] \
                    [list diagram_font $diagram_font] \
                    [list diagram_theme $diagram_theme] \
    ]

    set result [ad_parse_template -params $params "/packages/intranet-helpdesk/lib/ticket-age-per-queue"]
    return [string trim $result]
}




# ---------------------------------------------------------------
# Allow the user to add queues to tickets
# ---------------------------------------------------------------

ad_proc im_helpdesk_member_add_queue_component {
    -object_id:required
} {
    Component that returns a formatted HTML form allowing
    users to add queues to a ticket.
} {
    # ------------------------------------------------
    # Applicability, Defauls & Security
    set object_type [util_memoize [list db_string acs_object_type "select object_type from acs_objects where object_id = $object_id" -default ""]]
    if {"im_ticket" != $object_type} { return "" }

    set current_user_id [ad_conn user_id]
    set perm_cmd "${object_type}_permissions \$current_user_id \$object_id view_p read_p write_p admin_p"
    eval $perm_cmd
    if {!$write_p} { return "" }

    set object_name [acs_object_name $object_id]
    set page_title [lang::message::lookup "" intranet-helpdesk.Add_queue "Add queue"]

    set notify_checked ""
    if {[parameter::get_from_package_key -package_key "intranet-core" -parameter "NotifyNewMembersDefault" -default "1"]} {
        set notify_checked "checked"
    }
    
    set bind_vars [ns_set create]
    set queues_sql "
	select	g.group_id,
		g.group_name
	from	groups g,
		im_ticket_queue_ext tqe
	where	g.group_id = tqe.group_id
	order by lower(g.group_name)
    "
    set default ""
    set list_box [im_selection_to_list_box -translate_p "0" $bind_vars queue_select $queues_sql user_id_from_search $default 10 0]

    set passthrough {object_id return_url also_add_to_object_id limit_to_users_in_group_id}
    foreach var $passthrough {
	if {![info exists $var]} { set $var [im_opt_val -limit_to nohtml $var] }
    }

    set role_id [im_biz_object_role_full_member]
    set result "
	<form method=GET action=/intranet/member-add-2>
	[export_vars -form {passthrough {notify_asignee 0}}]
	[eval "export_vars -form {$passthrough}"]
	<table cellpadding=0 cellspacing=2 border=0>
	<tr><td>
	$list_box
	</td></tr>
	<tr><td>
	[_ intranet-core.add_as] [im_biz_object_roles_select role_id $object_id $role_id]
	</td></tr>
	<tr><td>
	<input type=submit value=\"[_ intranet-core.Add]\">
	</td></tr>
	</table>
	</form>
    "
    
    return $result
}




# ----------------------------------------------------------------------
# Check for new mail to be converted into tickets
# ----------------------------------------------------------------------

ad_proc -public im_helpdesk_inbox_pop3_import_sweeper { } {
    Check for new mail to be converted into tickets
} {
    ns_log Notice "im_helpdesk_inbox_pop3_import_sweeper: Starting"

    set pop3_host [parameter::get_from_package_key -package_key intranet-helpdesk -parameter InboxPOP3Host -default ""]
    if {"" == [string trim $pop3_host]} { return }

    set serverroot [acs_root_dir]
    set cmd "$serverroot/packages/intranet-helpdesk/perl/import-pop3.perl"
    ns_log Notice "im_helpdesk_inbox_pop3_import_sweeper: cmd=$cmd"

    # Make sure that only one thread is working at a time
    if {[nsv_incr intranet_helpdesk_pop3_import sweeper_p] > 1} {
        nsv_incr intranet_helpdesk_pop3_import sweeper_p -1
        ns_log Notice "intranet_helpdesk_pop3_import_sync: Aborting. There is another process running"
        return
    }
    set result ""
    if {[catch {
	set result [im_exec bash -c $cmd]
	ns_log Notice "im_helpdesk_inbox_pop3_import_sweeper: Result: $result"	
    } err_msg]} {

	# Error during import-pop3.perl execution
	# This is dangerous, because it means that
	# customer emails may get lost.
	ns_log Error "im_helpdesk_inbox_pop3_import_sweeper: Error: $err_msg"

	# Send out a warning email
	set email [parameter::get_from_package_key -package_key "intranet-helpdesk" -parameter "HelpdeskOwner" -default ""]
	set sender_email [im_parameter -package_id [ad_acs_kernel_id] SystemOwner "" [ad_system_owner]]
	set subject "Error Importing Customer Emails"
	set message "Error executing: $cmd
Please search for 'Error:' in the text below.
No customer emails are lost, however the
offending ticket may get duplicated.
$err_msg
"
	if {[catch {
	    ns_sendmail $email $sender_email $subject $message
	} errmsg]} {
	    ns_log Error "im_helpdesk_inbox_pop3_import_sweeper: Error sending to \"$email\": $errmsg"
	}

    }

    nsv_incr intranet_helpdesk_pop3_import sweeper_p -1
}
