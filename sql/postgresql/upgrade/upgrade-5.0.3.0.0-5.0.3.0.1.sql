-- upgrade-5.0.3.0.0-5.0.3.0.1.sql

SELECT acs_log__debug('/packages/intranet-helpdesk/sql/postgresql/upgrade/upgrade-5.0.3.0.0-5.0.3.0.1.sql','');


SELECT im_category_new(30536, 'Move to other container', 'Intranet Ticket Action');
update im_categories set aux_string1 = '/intranet-helpdesk/action-move' where category_id = 30536;


