# /packages/intranet-helpdesk/lib/similar-tickets.tcl
#
# Copyright (C) 2014 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.


# ----------------------------------------------------------------------
# Variables and Parameters
# ---------------------------------------------------------------------

# The following variables are expected in the environment
# defined by the calling /tcl/*.tcl libary:

# ticket_id:required
set org_ticket_id $ticket_id
set how_many 20
set max_message 300

set same_customer_contact_score 1
set same_config_item_score 1




# ----------------------------------------------------------------------
# Ticket info
# ---------------------------------------------------------------------

# Get everything about the ticket
db_1row ticket_info "
	select	*
	from	im_tickets t,
		im_projects p,
		acs_objects o
	where	t.ticket_id = :org_ticket_id and
		p.project_id = t.ticket_id and
		o.object_id = t.ticket_id
"

# ----------------------------------------------------------------------
# Select out several types of related tickets
# ---------------------------------------------------------------------

set ttt {
 ticket_description               | text
 ticket_file                      | text
 ticket_request                   | text
 ticket_resolution                | text

    ticket_sla_id		{t 1.0 house "SLA" }
}


set field_list { 
    ticket_customer_contact_id	{t 1.0 user_go "Customer Contact" }
    ticket_assignee_id		{t 1.0 user "Ticket Assignee" }
    company_id  		{p 1.0 house "Customer" }
    parent_id   		{p 1.0 house "SLA" }
    ticket_dept_id		{t 1.0 building "Department" }
    ticket_service_id		{t 1.0 cog "Service" }
    ticket_queue_id		{t 1.0 basket "Queue" }
    ticket_conf_item_id		{t 1.0 server "Configuration Item" }
    ticket_component_id		{t 1.0 server "Component" }
}

set ttt {
    ticket_application_id	{t 1.0 application "Application" }
    ticket_area_id		{t 1.0 group "Area" }
    ticket_service_type_id	{t 1.0 cog "Service Type" }
}
array set field_hash $field_list
set matching_fields {}
set score_fields {}
foreach field [array names field_hash] {
    set field_attrs $field_hash($field)
    set field_table [lindex $field_attrs 0]
    set field_score [lindex $field_attrs 1]
    set field_gif [lindex $field_attrs 2]
    lappend matching_fields "CASE WHEN $field_table.$field = :$field THEN $field_score ELSE 0 END as ${field}_score"
    lappend score_fields "${field}_score"
}

set sql "
select	ttt.*
 from	(
	select	tt.*,
		(select ff.message from im_forum_topics ff where ff.topic_id = main_topic_id) as message,
		[join $score_fields " + "] as score
	from	(
		select	t.ticket_id,
			p.project_nr,
			p.project_name,
			(select min(topic_id) from im_forum_topics f where p.project_id = f.object_id) as main_topic_id,
			[join $matching_fields ",\n\t\t\t"]
		from	im_tickets t,
			im_projects p
		where	t.ticket_id = p.project_id and
			t.ticket_id != :org_ticket_id
		) tt
	) ttt
where	score > 0
order by score DESC
LIMIT :how_many
"


# ---------------------------------------------------------------
# Format the List Table Header
# ---------------------------------------------------------------

set table_header_html ""
append table_header_html "<td class=rowtitle>[lang::message::lookup "" intranet-core.Score Score]</td>\n"
append table_header_html "<td class=rowtitle>[lang::message::lookup "" intranet-helpdesk.Ticket Ticket]</td>\n"

set table_body_html ""
set bgcolor(0) " class=roweven "
set bgcolor(1) " class=rowodd "
set ctr 0

db_foreach tickets $sql {

    set ticket_url [export_vars -base "/intranet-helpdesk/new" {ticket_id return_url {form_mode display}}]
    set score_html ""
    foreach field [array names field_hash] {
	set var "${field}_score"
	set val [expr $$var]
	set field_entry $field_hash($field)
	set field_gif [lindex $field_entry 2]
	set field_name_pretty [lindex $field_entry 3]
	if {$val > 0} {
	    set gif_text "[lang::message::lookup "" intranet-helpdesk.Shared_with_this_ticket "Shared with this ticket:"] $field_name_pretty"
	    append score_html [im_gif -translate_p 0 $field_gif $gif_text $gif_text]
	}
    }


    set row_html "<tr$bgcolor([expr {$ctr % 2}])>\n"
    append row_html "<td>$score_html</td>\n"
    append row_html "<td><a href=$ticket_url>$project_name</a></td>\n"
    append row_html "</tr>\n"
    append row_html "<tr$bgcolor([expr {$ctr % 2}])>\n"
    append row_html "<td colspan=2>[string range $message 0 $max_message]</td>\n"
    append row_html "</tr>\n"

    append table_body_html $row_html

    incr ctr
}

