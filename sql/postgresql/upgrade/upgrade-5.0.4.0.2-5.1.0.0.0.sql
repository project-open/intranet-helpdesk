-- upgrade-5.0.4.0.2-5.1.0.0.0.sql

SELECT acs_log__debug('/packages/intranet-helpdesk/sql/postgresql/upgrade/upgrade-5.0.4.0.2-5.1.0.0.0.sql','');


-- New ticket_container_email_selector
SELECT im_dynfield_attribute_new ('im_project', 'ticket_container_email_selector', 'Email Selector RegExp', 'textarea_small', 'string', 'f');


-- Add a RegExp email selector to ticket containers
--
create or replace function inline_0 () 
returns integer as $body$
DECLARE
	v_count			integer;
BEGIN
	-- Check if colum exists in the database
	select	count(*) into v_count from user_tab_columns where lower(table_name) = 'im_projects' and lower(column_name) = 'ticket_container_email_selector';
	IF v_count = 0 THEN
		alter table im_projects add column ticket_container_email_selector text;
	END IF;

	-- New field in forum topics for MIME Message-ID of creating email
	select	count(*) into v_count from user_tab_columns where lower(table_name) = 'im_forum_topics' and lower(column_name) = 'mime_message_id';
	IF v_count = 0 THEN
		alter table im_forum_topics add column mime_message_id text;
	END IF;

	return 0;
END;$body$ language 'plpgsql';
SELECT inline_0 ();
DROP FUNCTION inline_0 ();

