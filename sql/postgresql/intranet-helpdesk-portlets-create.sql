-- /packages/intranet-helpdesk/sql/postgresql/intranet-helpdesk-portlets-create.sql
--
-- Copyright (c) 2003-2008 ]project-open[
--
-- All rights reserved. Please check
-- http://www.project-open.com/license/ for details.
--
-- @author frank.bergmann@project-open.com


select  im_component_plugin__del_module('intranet-helpdesk');
-- select  im_menu__del_module('intranet-helpdesk');


-----------------------------------------------------------
-- Component Plugin
--
-- Forum component on the ticket page itself

SELECT im_component_plugin__new (
	null, 'im_component_plugin', now(), null, null, null,				-- context_id
	'Discussions',			-- plugin_name - shown in menu
	'intranet-helpdesk',		-- package_name
	'bottom',			-- location
	'/intranet-helpdesk/new',	-- page_url
	null,				-- view_name
	10,				-- sort_order
	'im_forum_full_screen_component -object_id $ticket_id',	-- component_tcl
	'lang::message::lookup "" "intranet-helpdesk.Ticket_Discussions" "Ticket Discussions"'
);

SELECT acs_permission__grant_permission(
	(select plugin_id from im_component_plugins where plugin_name = 'Discussions' and package_name = 'intranet-helpdesk'), 
	(select group_id from groups where group_name = 'Employees'),
	'read'
);


-- Timesheet plugin
select im_component_plugin__new (
	null,					-- plugin_id
	'im_component_plugin',			-- object_type
	now(),					-- creation_date
	null,					-- creation_user
	null,					-- creattion_ip
	null,					-- context_id

	'Timesheet',				-- plugin_name - shown in menu
	'intranet-helpdesk',			-- package_name
	'right',				-- location
	'/intranet-helpdesk/new',		-- page_url
	null,					-- view_name
	50,					-- sort_order
	'im_timesheet_project_component $current_user_id $ticket_id',
	'lang::message::lookup "" intranet-helpdesk.Ticket_Timesheet "Ticket Timesheet"'
);

SELECT acs_permission__grant_permission(
	(select plugin_id from im_component_plugins where plugin_name = 'Timesheet' and package_name = 'intranet-helpdesk'), 
	(select group_id from groups where group_name = 'Employees'),
	'read'
);


create or replace function inline_0 ()
returns integer as '
declare
	row			RECORD;
	v_plugin_id		integer;
	v_sort_order		integer;
BEGIN
	select plugin_id, sort_order into v_plugin_id, v_sort_order from im_component_plugins
	where package_name = ''intranet-helpdesk'' and plugin_name = ''Timesheet'';
	FOR row IN
		select user_id from users_active au
		where 0 = (
			select count(*) from im_component_plugin_user_map cpum
			where cpum.user_id = au.user_id and cpum.plugin_id = v_plugin_id
		)
	LOOP
		insert into im_component_plugin_user_map (plugin_id, user_id, sort_order, minimized_p, location)
		values (v_plugin_id, row.user_id, v_sort_order, ''f'', ''none'');
	END LOOP;
	return 0;
end;' language 'plpgsql';
select inline_0 ();
drop function inline_0 ();



-- ------------------------------------------------------
-- Workflow Graph

SELECT	im_component_plugin__new (
	null,					-- plugin_id
	'im_component_plugin',			-- object_type
	now(),					-- creation_date
	null,					-- creation_user
	null,					-- creation_ip
	null,					-- context_id

	'Workflow',				-- component_name - shown in menu
	'intranet-helpdesk',			-- package_name
	'right',				-- location
	'/intranet-helpdesk/new',		-- page_url
	null,					-- view_name
	10,					-- sort_order
	'im_workflow_graph_component -object_id $ticket_id',
	'lang::message::lookup "" intranet-helpdesk.Ticket_Workflow "Ticket Workflow"'
);

SELECT acs_permission__grant_permission(
	(select plugin_id from im_component_plugins where plugin_name = 'Workflow' and package_name = 'intranet-helpdesk'), 
	(select group_id from groups where group_name = 'Employees'),
	'read'
);



-- move component to Ticket Menu Tab for all users
create or replace function inline_0 ()
returns integer as '
declare
	row			RECORD;
	v_plugin_id		integer;
	v_sort_order		integer;
BEGIN
	select plugin_id, sort_order into v_plugin_id, v_sort_order from im_component_plugins 
	where package_name = ''intranet-helpdesk'' and plugin_name = ''Workflow'';
	FOR row IN 
		select user_id from users_active au
		where 0 = (
			select count(*) from im_component_plugin_user_map cpum
			where cpum.user_id = au.user_id and cpum.plugin_id = v_plugin_id
		)
	LOOP
		insert into im_component_plugin_user_map (plugin_id, user_id, sort_order, minimized_p, location)
		values (v_plugin_id, row.user_id, v_sort_order, ''f'', ''none'');
	END LOOP;
	return 0;
end;' language 'plpgsql';
select inline_0 ();
drop function inline_0 ();



-- ------------------------------------------------------
-- Journal on Absence View Page

SELECT	im_component_plugin__new (
	null,					-- plugin_id
	'im_component_plugin',			-- object_type
	now(),					-- creation_date
	null,					-- creation_user
	null,					-- creation_ip
	null,					-- context_id

	'Journal',				-- component_name - shown in menu
	'intranet-helpdesk',			-- package_name
	'bottom',				-- location
	'/intranet-helpdesk/new',		-- page_url
	null,					-- view_name
	100,					-- sort_order
	'im_workflow_journal_component -object_id $ticket_id',
	'lang::message::lookup "" intranet-helpdesk.Ticket_Journal "Ticket Journal"'
);

SELECT acs_permission__grant_permission(
	(select plugin_id from im_component_plugins where plugin_name = 'Journal' and package_name = 'intranet-helpdesk'), 
	(select group_id from groups where group_name = 'Employees'),
	'read'
);


-- move component to Ticket Menu Tab for all users
create or replace function inline_0 ()
returns integer as '
declare
	row			RECORD;
	v_plugin_id		integer;
	v_sort_order		integer;
BEGIN
	select plugin_id, sort_order into v_plugin_id, v_sort_order from im_component_plugins 
	where package_name = ''intranet-helpdesk'' and plugin_name = ''Journal'';
	FOR row IN 
		select user_id from users_active au
		where 0 = (
			select count(*) from im_component_plugin_user_map cpum
			where cpum.user_id = au.user_id and cpum.plugin_id = v_plugin_id
		)
	LOOP
		insert into im_component_plugin_user_map (plugin_id, user_id, sort_order, minimized_p, location)
		values (v_plugin_id, row.user_id, v_sort_order, ''f'', ''none'');
	END LOOP;
	return 0;
end;' language 'plpgsql';
select inline_0 ();
drop function inline_0 ();



-- ------------------------------------------------------
-- Filestorage on Absence View Page

SELECT	im_component_plugin__new (
	null,					-- plugin_id
	'im_component_plugin',			-- object_type
	now(),					-- creation_date
	null,					-- creation_user
	null,					-- creation_ip
	null,					-- context_id

	'Filestorage',				-- component_name - shown in menu
	'intranet-helpdesk',			-- package_name
	'bottom',				-- location
	'/intranet-helpdesk/new',		-- page_url
	null,					-- view_name
	110,					-- sort_order
	'im_filestorage_ticket_component $user_id $ticket_id $ticket_name $return_url', -- component_tcl
	'lang::message::lookup "" intranet-helpdesk.Ticket_Filestorage "Ticket Filestorage"'
);

SELECT acs_permission__grant_permission(
	(select plugin_id from im_component_plugins where plugin_name = 'Filestorage' and package_name = 'intranet-helpdesk'), 
	(select group_id from groups where group_name = 'Employees'),
	'read'
);

-- move component to Ticket Menu Tab for all users
create or replace function inline_0 ()
returns integer as '
declare
	row			RECORD;
	v_plugin_id		integer;
	v_sort_order		integer;
BEGIN
	select plugin_id, sort_order into v_plugin_id, v_sort_order from im_component_plugins 
	where package_name = ''intranet-helpdesk'' and plugin_name = ''Filestorage'';
	FOR row IN 
		select user_id from users_active au
		where 0 = (
			select count(*) from im_component_plugin_user_map cpum
			where cpum.user_id = au.user_id and cpum.plugin_id = v_plugin_id
		)
	LOOP
		insert into im_component_plugin_user_map (plugin_id, user_id, sort_order, minimized_p, location)
		values (v_plugin_id, row.user_id, v_sort_order, ''f'', ''none'');
	END LOOP;
	return 0;
end;' language 'plpgsql';
select inline_0 ();
drop function inline_0 ();




-- ------------------------------------------------------
-- List of Tickets at the home page
SELECT	im_component_plugin__new (
	null,				-- plugin_id
	'im_component_plugin',		-- object_type
	now(),				-- creation_date
	null,				-- creation_user
	null,				-- creation_ip
	null,				-- context_id
	'Home Ticket Component',	-- plugin_name
	'intranet-helpdesk',		-- package_name
	'left',				-- location
	'/intranet/index',		-- page_url
	null,				-- view_name
	20,				-- sort_order
	'im_helpdesk_home_component',
	'lang::message::lookup "" intranet-helpdesk.Home_Ticket_Component "Home Ticket Component"'
);

SELECT acs_permission__grant_permission(
        (select plugin_id from im_component_plugins where plugin_name = 'Home Ticket Component' and package_name = 'intranet-helpdesk'),
        (select group_id from groups where group_name = 'Employees'),
        'read'
);



-- ------------------------------------------------------
-- Workflow Actions in the object's View Page
SELECT	im_component_plugin__new (
	null,				-- plugin_id
	'im_component_plugin',		-- object_type
	now(),				-- creation_date
	null,				-- creation_user
	null,				-- creation_ip
	null,				-- context_id
	'Actions',			-- plugin_name
	'intranet-helpdesk',		-- package_name
	'left',				-- location
	'/intranet-helpdesk/new',	-- page_url
	null,				-- view_name
	0,				-- sort_order
	'im_workflow_action_component -object_id $ticket_id',
	'lang::message::lookup "" intranet-helpdesk.Ticket_Workflow_Actions "Ticket Workflow Actions"'
);

SELECT acs_permission__grant_permission(
        (select plugin_id from im_component_plugins 
	 where plugin_name = 'Actions' and package_name = 'intranet-helpdesk'
	),
        (select group_id from groups where group_name = 'Employees'),
        'read'
);

SELECT acs_permission__grant_permission(
        (select plugin_id from im_component_plugins 
	 where plugin_name = 'Actions' and package_name = 'intranet-helpdesk'
	),
        (select group_id from groups where group_name = 'Customers'),
        'read'
);

SELECT acs_permission__grant_permission(
        (select plugin_id from im_component_plugins 
	 where plugin_name = 'Actions' and package_name = 'intranet-helpdesk'),
        (select group_id from groups where group_name = 'Freelancers'),
        'read'
);



-- ------------------------------------------------------
-- Show the customer contacts information
-- to allow the helpdesk to contact the customer
--
SELECT	im_component_plugin__new (
	null,				-- plugin_id
	'im_component_plugin',		-- object_type
	now(),				-- creation_date
	null,				-- creation_user
	null,				-- creation_ip
	null,				-- context_id
	'Customer Info',		-- plugin_name
	'intranet-helpdesk',		-- package_name
	'right',			-- location
	'/intranet-helpdesk/new',	-- page_url
	null,				-- view_name
	10,				-- sort_order
	'im_user_base_info_component -user_id $ticket_customer_contact_id -show_user_conf_items_p 1',
	'lang::message::lookup "" intranet-helpdesk.Customer_Info "Customer Info"'
);

SELECT acs_permission__grant_permission(
        (select plugin_id from im_component_plugins where plugin_name = 'Customer Info' and package_name = 'intranet-helpdesk'),
        (select group_id from groups where group_name = 'Employees'),
        'read'
);



-- ------------------------------------------------------
-- Show related objects
--
SELECT	im_component_plugin__new (
	null,				-- plugin_id
	'im_component_plugin',		-- object_type
	now(),				-- creation_date
	null,				-- creation_user
	null,				-- creation_ip
	null,				-- context_id
	'Ticket Related Objects',	-- plugin_name
	'intranet-helpdesk',		-- package_name
	'right',			-- location
	'/intranet-helpdesk/new',	-- page_url
	null,				-- view_name
	91,				-- sort_order
	'im_biz_object_related_objects_component -object_id $ticket_id',
	'lang::message::lookup "" intranet-helpdesk.Ticket_Related_Objects "Ticket Related Objects"'
);

SELECT acs_permission__grant_permission(
        (select plugin_id from im_component_plugins where plugin_name = 'Ticket Related Objects' and package_name = 'intranet-helpdesk'),
        (select group_id from groups where group_name = 'Employees'),
        'read'
);


-- ------------------------------------------------------
-- Show users associated with ticket
--
SELECT	im_component_plugin__new (
	null,				-- plugin_id
	'im_component_plugin',		-- object_type
	now(),				-- creation_date
	null,				-- creation_user
	null,				-- creation_ip
	null,				-- context_id
	'Ticket Members',		-- plugin_name
	'intranet-helpdesk',		-- package_name
	'right',			-- location
	'/intranet-helpdesk/new',	-- page_url
	null,				-- view_name
	80,				-- sort_order
        'im_group_member_component $ticket_id $current_user_id $user_admin_p $return_url "" "" 1',
	'lang::message::lookup "" intranet-helpdesk.Ticket_Members "Ticket Members"'
);

SELECT acs_permission__grant_permission(
        (
		select plugin_id
		from im_component_plugins 
		where plugin_name = 'Ticket Members' and package_name = 'intranet-helpdesk'
	),
        (
		select group_id 
		from groups 
		where group_name = 'Employees'
	),
        'read'
);



-- ------------------------------------------------------
-- Show tickets in SLA
--
SELECT im_component_plugin__new (
	null,				-- plugin_id
	'im_component_plugin',		-- object_type
	now(),				-- creation_date
	null,				-- creation_user
	null,				-- creation_ip
	null,				-- context_id
	'Project Ticket Component',	-- plugin_name - shown in menu
	'intranet-helpdesk',		-- package_name
	'left',				-- location
	'/intranet/projects/view',	-- page_url
	null,				-- view_name
	20,				-- sort_order
	'im_helpdesk_project_component -project_id $project_id'	-- component_tcl
);

SELECT acs_permission__grant_permission(
	(select plugin_id from im_component_plugins where plugin_name = 'Project Ticket Component' and package_name = 'intranet-helpdesk'), 
	(select group_id from groups where group_name = 'Employees'),
	'read'
);









-----------------------------------------------------------
-- Ticket Aging Reports
--


SELECT im_component_plugin__new (
	null,				-- plugin_id
	'im_component_plugin',		-- object_type
	now(),				-- creation_date
	null,				-- creation_user
	null,				-- creation_ip
	null,				-- context_id
	'Ticket Aging',			-- plugin_name - shown in menu
	'intranet-helpdesk',		-- package_name
	'right',			-- location
	'/intranet-helpdesk/index',	-- page_url
	null,				-- view_name
	30,				-- sort_order
	'im_helpdesk_ticket_aging_diagram',	-- component_tcl
	'lang::message::lookup "" "intranet-helpdesk.Ticket_Aging" "Ticket Aging"'
);

SELECT acs_permission__grant_permission(
	(select plugin_id from im_component_plugins where plugin_name = 'Ticket Aging' and package_name = 'intranet-helpdesk'), 
	(select group_id from groups where group_name = 'Employees'),
	'read'
);
SELECT acs_permission__grant_permission(
	(select plugin_id from im_component_plugins where plugin_name = 'Ticket Aging' and package_name = 'intranet-helpdesk'), 
	(select group_id from groups where group_name = 'Customers'),
	'read'
);
SELECT acs_permission__grant_permission(
	(select plugin_id from im_component_plugins where plugin_name = 'Ticket Aging' and package_name = 'intranet-helpdesk'), 
	(select group_id from groups where group_name = 'Freelancers'),
	'read'
);


-- Tickets for a user on the home page
SELECT im_component_plugin__new (
	null,					-- plugin_id
	'im_component_plugin',			-- object_type
	now(),					-- creation_date
	null,					-- creation_user
	null,					-- creation_ip
	null,					-- context_id
	'My Tickets Aging',			-- plugin_name - shown in menu
	'intranet-helpdesk',			-- package_name
	'right',				-- location
	'/intranet-helpdesk/dashboard',		-- page_url
	null,					-- view_name
	40,					-- sort_order
	'im_helpdesk_ticket_aging_diagram -diagram_limit 600 -diagram_height 450 -ticket_customer_contact_id [ad_conn user_id]',	-- component_tcl
	'lang::message::lookup "" "intranet-helpdesk.My_Tickets_Aging" "My Tickets Aging"'
);

SELECT acs_permission__grant_permission(
	(select plugin_id from im_component_plugins where plugin_name = 'My Tickets Aging' and package_name = 'intranet-helpdesk'),
	(select group_id from groups where group_name = 'Employees'),
	'read'
);

-- Ticket aging for a SLA on the SLA page
SELECT im_component_plugin__new (
	null,					-- plugin_id
	'im_component_plugin',			-- object_type
	now(),					-- creation_date
	null,					-- creation_user
	null,					-- creation_ip
	null,					-- context_id
	'SLA Ticket Aging',			-- plugin_name - shown in menu
	'intranet-helpdesk',			-- package_name
	'left',					-- location
	'/intranet/projects/view',		-- page_url
	null,					-- view_name
	40,					-- sort_order
	'im_helpdesk_ticket_aging_diagram -diagram_limit 600 -diagram_height 450 -ticket_sla_id $project_id',	-- component_tcl
	'lang::message::lookup "" "intranet-helpdesk.SLA_Ticket_Aging" "SLA Ticket Aging"'
);

SELECT acs_permission__grant_permission(
	(select plugin_id from im_component_plugins where plugin_name = 'SLA Ticket Aging' and package_name = 'intranet-helpdesk'),
	(select group_id from groups where group_name = 'Employees'),
	'read'
);

-- Ticket aging for the department of the user
-- IF the user is a department head
SELECT im_component_plugin__new (
	null,					-- plugin_id
	'im_component_plugin',			-- object_type
	now(),					-- creation_date
	null,					-- creation_user
	null,					-- creation_ip
	null,					-- context_id
	'Tickets Created by my Department',	-- plugin_name - shown in menu
	'intranet-helpdesk',			-- package_name
	'left',					-- location
	'/intranet/index',			-- page_url
	null,					-- view_name
	40,					-- sort_order
	'im_helpdesk_ticket_aging_diagram -diagram_limit 600 -diagram_height 450 ' ||
	'-ticket_customer_contact_dept_id [db_string my_dept "select department_id ' ||
	'from im_employees where employee_id = [ad_conn user_id]" -default ""]',	-- component_tcl
	'lang::message::lookup "" "intranet-helpdesk.Tickets_Created_by_my_Department" "Tickets Created by my Department"'
);

SELECT acs_permission__grant_permission(
	(select plugin_id from im_component_plugins where plugin_name = 'Tickets Created by my Department' and package_name = 'intranet-helpdesk'),
	(select group_id from groups where group_name = 'Employees'),
	'read'
);




SELECT im_component_plugin__new (
	null,					-- plugin_id
	'im_component_plugin',			-- object_type
	now(),					-- creation_date
	null,					-- creation_user
	null,					-- creation_ip
	null,					-- context_id
	'Tickets Executed by my Department',	-- plugin_name - shown in menu
	'intranet-helpdesk',			-- package_name
	'left',					-- location
	'/intranet/index',			-- page_url
	null,					-- view_name
	40,					-- sort_order
	'im_helpdesk_ticket_aging_diagram -diagram_limit 600 -diagram_height 450 ' ||
	'-ticket_assignee_dept_id [db_string my_dept "select department_id ' ||
	'from im_employees where employee_id = [ad_conn user_id]" -default ""]',	-- component_tcl
	'lang::message::lookup "" "intranet-helpdesk.Tickets_Executed_by_my_Department" "Tickets Executed by my Department"'
);

SELECT acs_permission__grant_permission(
	(select plugin_id from im_component_plugins where plugin_name = 'Tickets Executed by my Department' and package_name = 'intranet-helpdesk'),
	(select group_id from groups where group_name = 'Employees'),
	'read'
);












-----------------------------------------------------------
-- Ticket number and age per dept
--

SELECT im_component_plugin__new (
        null,                           -- plugin_id
        'im_component_plugin',          -- object_type
        now(),                          -- creation_date
        null,                           -- creation_user
        null,                           -- creation_ip
        null,                           -- context_id
        'Tickets per Queue & Dept',	-- plugin_name - shown in menu
        'intranet-helpdesk',            -- package_name
        'right',                        -- location
        '/intranet-helpdesk/index',     -- page_url
        null,                           -- view_name
        30,                             -- sort_order
        'im_helpdesk_ticket_age_number_per_queue',     -- component_tcl
        'lang::message::lookup "" "intranet-helpdesk.Ticket_per_Queue_and_Dept" "Tickets per Queue & Dept"'
);

SELECT acs_permission__grant_permission(
        (select plugin_id from im_component_plugins where plugin_name = 'Tickets per Queue & Dept' and package_name = 'intranet-helpdesk'),
        (select group_id from groups where group_name = 'Employees'),
        'read'
);


-----------------------------------------------------------
-- Tickets for a user on the home page
--

SELECT im_component_plugin__new (
	null,				-- plugin_id
	'im_component_plugin',		-- object_type
	now(),				-- creation_date
	null,				-- creation_user
	null,				-- creation_ip
	null,				-- context_id
	'My Tickets Execution',		-- plugin_name - shown in menu
	'intranet-helpdesk',		-- package_name
	'right',			-- location
	'/intranet/index',		-- page_url
	null,				-- view_name
	40,				-- sort_order
	'im_helpdesk_ticket_age_number_per_queue -ticket_customer_contact_id [ad_conn user_id]',	-- component_tcl
	'lang::message::lookup "" "intranet-helpdesk.My_Ticket_Execution" "My Tickets Execution"'
);

SELECT acs_permission__grant_permission(
	(select plugin_id from im_component_plugins where plugin_name = 'My Tickets Execution' and package_name = 'intranet-helpdesk'),
	(select group_id from groups where group_name = 'Employees'),
	'read'
);






-- Enable all reporting menus - no idea why they are disabled...
update im_menus
set enabled_p = 't'
where  parent_menu_id in (select menu_id from im_menus where label = 'reporting');



-- Update aging report with filters
update im_reports 
set report_sql = '
select	age,
	sum(prio1) as prio1,
	sum(prio2) as prio2,
	sum(prio3) as prio3,
	sum(prio4) as prio4
from	(
	select	t.ticket_id,
		now()::date - o.creation_date::date as age,
		CASE WHEN ticket_prio_id in (30201) THEN 1 ELSE 0 END as prio1,
		CASE WHEN ticket_prio_id in (30202, 30203) THEN 1 ELSE 0 END as prio2,
		CASE WHEN ticket_prio_id in (30204, 30205, 30206) THEN 1 ELSE 0 END as prio3,
		CASE WHEN ticket_prio_id not in (30201, 30202, 30203, 30204, 30205, 30206) OR ticket_prio_id is null THEN 1 ELSE 0 END as prio4
	from	im_tickets t,
		im_projects p,
		acs_objects o
	where	t.ticket_id = o.object_id and
		t.ticket_id = p.project_id and
		ticket_status_id in (select * from im_sub_categories(30000)) and
		(0 = %sla_id% OR p.parent_id = %sla_id%) and
		(0 = %type_id% OR t.ticket_type_id in (select * from im_sub_categories(%type_id%))) and
		(0 = %status_id% OR t.ticket_status_id in (select * from im_sub_categories(%status_id%))) and
		(0 = %prio_id% OR t.ticket_prio_id in (select * from im_sub_categories(%prio_id%))) and
		(0 = %customer_contact_id% OR t.ticket_customer_contact_id = %customer_contact_id%) and
		(0 = length(''%customer_dept_code%'') OR t.ticket_customer_contact_id in (
			select	e.employee_id
			from	im_employees e,
				im_cost_centers cc
			where	e.department_id = cc.cost_center_id and 
				substring(cc.cost_center_code for (length(''%customer_dept_code%''))) = ''%customer_dept_code%''
		)) and
		(0 = length(''%assignee_dept_code%'') OR t.ticket_assignee_id in (
			select	e.employee_id
			from	im_employees e, 
				im_cost_centers cc
			where	e.department_id = cc.cost_center_id and 
				substring(cc.cost_center_code for (length(''%assignee_dept_code%''))) = ''%assignee_dept_code%''
		))
UNION
	-- Define one default entry for today
	select	0 as ticket_id,
		now()::date - im_day_enumerator::date as age,
		0 as prio1,
		0 as prio2,
		0 as prio3,
		0 as prio4
	from	im_day_enumerator(
			coalesce((select min(creation_date::date) from acs_objects where object_id in (
				select t.ticket_id from im_tickets t where ticket_status_id in (select * from im_sub_categories(30000))
			)), now()::date),
			now()::date+1
		)
	) t
group by age
order by age
LIMIT %limit%'
where report_code = 'rest_ticket_aging_histogram';






