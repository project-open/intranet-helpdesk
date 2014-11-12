#!/usr/bin/perl -w

# --------------------------------------------------------
#
# import-pop3
#
# ]project-open[ ERP/Project Management System
# (c) 2008 - 2010 ]project-open[
# frank.bergmann@project-open.com
#
# --------------------------------------------------------

use FindBin;
use lib $FindBin::Bin;
use DBI;
use Net::POP3;
use MIME::Parser;				# http://perl.mines-albi.fr/perl5.6.1/site_perl/5.6.1/MIME/Tools.html
use MIME::Entity;
use MIME::WordDecoder;  
use Path::Class;
use Getopt::Long;


# --------------------------------------------------------
# Debug? 0=no output, 10=very verbose
$debug = 5;
MIME::Tools->debugging(1);

# --------------------------------------------------------
# Database Connection Parameters
#

# Information about the ]po[ database
$instance = getpwuid( $< );;				# The name of the database instance.
$db_username = "$instance";				# By default the same as the instance.
$db_pwd = "";						# The DB password. Empty by default.
$db_datasource = "dbi:Pg:dbname=$instance";		# How to identify the database
$ticket_file_storage = "/web/$instance/filestorage/tickets"; # Default filename for ticket file storage



# --------------------------------------------------------
# Default POP3 Mail Account
# Enter specific values in order to overwrite parameter values set in ]po[.
#
$pop3_host = "";					# "mail.your-server.com" - POP3 server of the mailbox
$pop3_user = "";					# "mailbox\@your-server.com" - you need to quote the at-sign
$pop3_pwd = "";						# "secret" - POP3 password



# --------------------------------------------------------
# Check for command line options
#
my $message_file = "";
my $result = GetOptions (
    "file=s"     => \$message_file,
    "debug=i"    => \$debug,
    "host=s"     => \$pop3_host,
    "user=s"     => \$pop3_user,
    "password=s" => \$pop3_pwd
    ) or die "Usage:\n\nimport-pop3.perl --debug 3 --host pop.1und1.de --user bbigboss\@tigerpond.com --password secret\n\n";



# --------------------------------------------------------
# Types of attachments to be saved to disk
my @attypes= qw(application
		audio
		image
		text
);


# --------------------------------------------------------
# Define the date format for debugging messages
$date = `/bin/date +"%Y%m%d.%H%M"` || 
    die "common_constants: Unable to get date.\n";
chomp($date);



# --------------------------------------------------------
# Establish the database connection
# The parameters are defined in common_constants.pm
$dbh = DBI->connect($db_datasource, $db_username, $db_pwd) ||
    die "import-pop3: Unable to connect to database.\n";


# --------------------------------------------------------
# Get parameters from database
#
if ("" eq $pop3_host) {
    $sth = $dbh->prepare("SELECT attr_value FROM apm_parameters ap, apm_parameter_values apv WHERE ap.parameter_id = apv.parameter_id and ap.package_key = 'intranet-helpdesk' and ap.parameter_name = 'InboxPOP3Host'");
    $sth->execute() || die "import-pop3: Unable to execute SQL statement.\n";
    $row = $sth->fetchrow_hashref;
    $pop3_host = $row->{attr_value};
}

if ("" eq $pop3_user) {
    $sth = $dbh->prepare("SELECT attr_value FROM apm_parameters ap, apm_parameter_values apv WHERE ap.parameter_id = apv.parameter_id and ap.package_key = 'intranet-helpdesk' and ap.parameter_name = 'InboxPOP3User'");
    $sth->execute() || die "import-pop3: Unable to execute SQL statement.\n";
    $row = $sth->fetchrow_hashref;
    $pop3_user = $row->{attr_value};
}

if ("" eq $pop3_pwd) {
    $sth = $dbh->prepare("SELECT attr_value FROM apm_parameters ap, apm_parameter_values apv WHERE ap.parameter_id = apv.parameter_id and ap.package_key = 'intranet-helpdesk' and ap.parameter_name = 'InboxPOP3Pwd'");
    $sth->execute() || die "import-pop3: Unable to execute SQL statement.\n";
    $row = $sth->fetchrow_hashref;
    $pop3_pwd = $row->{attr_value};
}


print "import-pop3: host=$pop3_host, user=$pop3_user, pwd=$pop3_pwd\n" if ($debug > 9);
die "import-pop3.perl: You need to define a pop3_host" if ("" eq $pop3_host);
die "import-pop3.perl: You need to define a pop3_user" if ("" eq $pop3_user);
die "import-pop3.perl: You need to define a pop3_pwd" if ("" eq $pop3_pwd);


# --------------------------------------------------------
# Establish a connection to the POP3 server
#
$pop3_conn = Net::POP3->new($pop3_host, Timeout => 60) 
    || die "import-pop3: Unable to connect to POP3 server $pop3_host: Timeout\n";

$n = $pop3_conn->login($pop3_user,$pop3_pwd) 
    || die "import-pop3: Unable to connect to POP3 server $pop3_host: Bad Password\n"; 

if (0 == $n) { 
    print "import-pop3: No messages on server.\n";
    exit 0; 
}

# Get the list of messages
$msgList = $pop3_conn->list(); 
print "import-pop3: Reading pop3 message list:\n" if ($debug >= 1);
print "import-pop3: Reading pop3 message list: ", keys(%$msgList), "\n" if ($debug >= 2);


# MIME Parser initialization
my $mime_parser = new MIME::Parser;
$mime_parser->ignore_errors(1);
$mime_parser->output_to_core(1);
$mime_parser->tmp_to_core(1);
# $wd = supported MIME::WordDecoder "ISO-8859-1";
$wd = supported MIME::WordDecoder "UTF-8";

# Initialize attachment arrays
my @attachment = ();
my @attname = ();


# --------------------------------------------------------
# Recursively deal with MIME parts
# --------------------------------------------------------

sub process_parts {
    my ($part, $name) = @_;
    defined($name) or $name = "'anonymous'";
    my $IO;
    my $i;
    my $result = "";

    my $mime_type = $part->mime_type;
    my ($main_type, $sub_type) = split('/', $mime_type);
    my $bodyh = $part->bodyhandle;
    my @parts = $part->parts;

    print "import-pop3: process_parts: name=", $name, "\n" if ($debug >= 1);
    print "import-pop3: process_parts: mime_type=", $mime_type, "\n" if ($debug >= 1);
    print "import-pop3: process_parts: main=", $main_type, ", sub=", $sub_type, "\n" if ($debug >= 1);

    if ($mime_type eq "text/plain") {
	
	print "import-pop3: process_parts: text/plain: adding to result\n" if ($debug >= 1);
	print "import-pop3: process_parts: text/plain: ", $bodyh, "\n" if ($debug >= 2);

	$bodyh->is_encoded(1);
	$result .= $part->body_as_string();
	if (@parts) { foreach $i (0 .. $#parts) { $result .= process_parts($parts[$i], ("$name, part ".(1+$i))); }} 

    } elsif ($mime_type eq "text/html") {

	print "import-pop3: process_parts: text/html: adding to result\n" if ($debug >= 1);
	print "import-pop3: process_parts: text/html: ", $bodyh, "\n" if ($debug >= 2);
	$bodyh->is_encoded(1);
	$result .= $part->body_as_string();
	if (@parts) { foreach $i (0 .. $#parts) { $result .= process_parts($parts[$i], ("$name, part ".(1+$i))); }} 

    } elsif ($mime_type eq "message/delivery-status") {

	print "import-pop3: process_parts: message/delivery-status: ignoring\n" if ($debug >= 1);
	print "import-pop3: process_parts: message/delivery-status: ", $bodyh, "\n" if ($debug >= 2);
	if (@parts) { foreach $i (0 .. $#parts) { $result .= process_parts($parts[$i], ("$name, part ".(1+$i))); }} 

    } elsif ($mime_type eq "multipart/alternative") {

	print "import-pop3: process_parts: multipart/alternative: \n" if ($debug >= 1);
	if (0+$part->parts() == 2 and $part->parts(0)->effective_type eq "text/plain") {
	    print "import-pop3: process_parts: multipart/alternative: adding to result: only first (text) part\n" if ($debug >= 1);
	    @parts = $part->parts(0);
	    if (@parts) { foreach $i (0 .. $#parts) { $result .= process_parts($parts[$i], ("$name, part ".(1+$i))); }} 
	    print "import-pop3: process_parts: ", $part->parts(0)->body_as_string(), "\n" if ($debug >= 2);
	} else {
	    print "import-pop3: process_parts: multipart/alternative: alternative with wrong argument count\n" if ($debug >= 1);
	    for my $subpart ($part->parts()) {
		print "import-pop3: process_parts: multipart/alternative: subpart: adding to result\n" if ($debug >= 1);
		print "import-pop3: process_parts: multipart/alternative: subpart: ", $subpart->body_as_string(), "\n" if ($debug >= 2);
		if (@parts) { foreach $i (0 .. $#parts) { $result .= process_parts($parts[$i], ("$name, part ".(1+$i))); }} 
	    }
	}

    } else {

	print "import-pop3: process_parts: unknown MIME type: $mime_type\n" if ($debug >= 1);
	my $mime_main_type = "";
	if ($mime_type =~ /^(\w+)\/(\w+)/) {
	    $mime_main_type = $1;
	}
	print "import-pop3: process_parts: trying to identify attachment for mime_main_type=$mime_main_type\n" if ($debug >= 2);
	foreach $x (@attypes){
	    if ($mime_main_type =~ m/$x/i){
		print "import-pop3: process_parts: found attachment for $mime_main_type\n" if ($debug >= 2);
		$bh = $part->bodyhandle;
		$attachment = $bh->as_string;
		push @attachment, $attachment;
		push @attname, $part->head->mime_attr('content-disposition.filename');
	    }
	}
	if (@parts) { foreach $i (0 .. $#parts) { $result .= process_parts($parts[$i], ("$name, part ".(1+$i))); }} 
    }

    return $result
}


# --------------------------------------------------------
# Loop for each of the mails

print "import-pop3: Starting to import messages:\n" if ($debug >= 1);
foreach $msg_num (keys(%$msgList)) {
   # Get the mail as a file handle
    $message = $pop3_conn->get($msg_num);
    print "import-pop3: message=$message\n" if ($debug >= 3);

    exit 0;

    # Parse the MIME email
    my $mime_entity = $mime_parser->parse_data($message);
    my $error = ($@ || $mime_parser->last_error);
    print "import-pop3: error:$error\n" if ("" ne $error);
    # $mime_entity->dump_skeleton();
    my $header = $mime_entity->head();
    my $subject = $wd->decode($header->get('Subject'));
    my $subject_q = $dbh->quote($subject);
    my $to = $header->get('To');
    my $from = $header->get('From');
    my $id = $header->get('Message-ID');
    my $content_type = $header->get('Content-Type');
    chomp($from);
    chomp($to);
    chomp($subject);
    chomp($id);
    chomp($content_type);

    print "import-pop3: \n" if ($debug >= 1);
    print "import-pop3: from:\t$from\n" if ($debug >= 1);
    print "import-pop3: to:\t$to\n" if ($debug >= 1);
    print "import-pop3: subject:\t$subject_q\n" if ($debug >= 1);
    print "import-pop3: content-type:\t$content_type\n" if ($debug >= 1);

    if ($debug >= 3) {
	my $dir = dir("/tmp");
	my $file = $dir->file("email-".$id);
	my $file_handle = $file->openw();        # Get a file_handle (IO::File object) you can write to
	$file_handle->print(@$message);
    }

    # Parse the email
    my $body = process_parts($mime_entity, "main");
    my $body_q = $dbh->quote($body);
    print "import-pop3\n" if ($debug >= 1);
    print "import-pop3: body=$body\n" if ($debug >= 1);

    # --------------------------------------------------------
    # Calculate ticket database fields
    
    # Ticket Nr: Take current number from the im_ticket_seq sequence
    $sth = $dbh->prepare("SELECT nextval('im_ticket_seq') as ticket_nr");
    $sth->execute() || die "import-pop3: Unable to execute SQL statement.\n";
    my $row = $sth->fetchrow_hashref;
    my $ticket_nr = $row->{ticket_nr};
    
    # Ticket Name: Ticket Nr + Mail Subject
    my $ticket_name = "$ticket_nr - $subject";
    my $ticket_name_q = $dbh->quote($ticket_name);

    # Customer ID: Who should pay to fix the ticket?
    # Let's take the "internal" company (=the company running this server).
    $sth = $dbh->prepare("SELECT company_id as company_id from im_companies where company_path = 'internal'");
    $sth->execute() || die "import-pop3: Unable to execute SQL statement.\n";
    $row = $sth->fetchrow_hashref;
    my $ticket_customer_id = $row->{company_id};

    # SLA: Just get the first open SLA for the customer as an example.
    # Customers may want to use more complex logic and assign the
    # ticket to different SLAs depending on the sender domain etc.
    $sth = $dbh->prepare("SELECT min(project_id) as sla_id from im_projects where company_id = '$ticket_customer_id' and project_type_id = 2502 and project_status_id = 76");
    my $rv = $sth->execute() || die "import-pop3: Unable to execute SQL statement.\n";
    my $ticket_sla_id = "NULL";
    if ($rv >= 0) {
	$row = $sth->fetchrow_hashref;
	my $ticket_sla_id = $row->{sla_id};
    }
    
    # --------------------------------------------------------
    # Deal with the Customer's contact: 
    # Check database for "From" email
    # Example: "Frank Bergmann" <frank.bergmann@project-open.com>

    # Decompose the "From;" field
    my $from_name = "";
    my $from_email = "";
    if ("" eq $from_email && $from =~ /^([^\<]+)\<(.+)\>/) { $from_name = $1; $from_email = $2; }
    if ("" eq $from_email && $from =~ /^\"([^\<]+)\"\<(.+)\>/) { $from_name = $1; $from_email = $2; }
    if ("" eq $from_email && $from =~ /(\S+\@\S+\.\S+)/) { $from_name = ""; $from_email = $1; }

    $from_name =~ s/^\s+|\s+$//g;				# remove both leading and trailing whitespace
    $from_email =~ s/^\s+|\s+$//g;				# remove both leading and trailing whitespace

    print "import-pop3: from: '$from_name' <$from_email>\n" if ($debug >= 1);

    my $ticket_customer_contact_id = 0;
    my $sql = "select party_id from parties where lower(trim(email)) = lower(trim('$from_email'))";
    $sth = $dbh->prepare($sql);
    $rv = $sth->execute() || die "import-pop3: Unable to execute SQL statement: \n$sql\n";
    if ($rv >= 0) {
	$row = $sth->fetchrow_hashref;
	$ticket_customer_contact_id = $row->{party_id};
    }

    # Empty strings for the contact will lead to an SQL error further below.
    if (!defined $ticket_customer_contact_id) { $ticket_customer_contact_id = 0; }
    if ("" eq $ticket_customer_contact_id) { $ticket_customer_contact_id = 0; }
    print "import-pop3: from: #$ticket_customer_contact_id\n" if ($debug >= 1);

    # Ticket Type:
    #  30102 | Purchasing request
    #  30104 | Workplace move request
    #  30106 | Telephony request
    #  30108 | Project request
    #  30110 | Bug request
    #  30112 | Report request
    #  30114 | Permission request
    #  30116 | Feature request
    #  30118 | Training request
    my $ticket_type_id = 30110;
    
    # Ticket Status:
    #    30000 | Open
    #    30001 | Closed
    #    30010 | In review
    #    30011 | Assigned
    #    30012 | Customer review
    #    30090 | Duplicate
    #    30091 | Invalid
    #    30092 | Outdated
    #    30093 | Rejected
    #    30094 | Won't fix
    #    30095 | Can't reproduce
    #    30096 | Resolved
    #    30097 | Deleted
    #    30098 | Canceled
    my $ticket_status_id = 30000;
    
    # Ticket Prio
    # 30201 |	 	1 - Highest
    # 30202	|		2 
    # 30203 |		3 	
    # 30204 |		4 	
    # 30205 |		5 	
    # 30206 |		6 	
    # 30207 |		7 	
    # 30208 |		8 	
    # 30209 |		9 - Lowest
    my $ticket_prio_id = 30205;


    # --------------------------------------------------------
    # Insert the basis ticket into the SQL database
    print "import-pop3: before im_ticket__new\n" if ($debug >= 1);
    $sth = $dbh->prepare("
		SELECT im_ticket__new (
			nextval('t_acs_object_id_seq')::integer, -- p_ticket_id
			'im_ticket'::varchar,			-- object_type
			now(),					-- creation_date
			0::integer,				-- creation_user
			'0.0.0.0'::varchar,			-- creation_ip
			null::integer,				-- (security) context_id
	
			$ticket_name_q,
			'$ticket_nr'::varchar,
			'$ticket_customer_id'::integer,
			'$ticket_type_id'::integer,
			'$ticket_status_id'::integer
		) as ticket_id
    ");
    $sth->execute() || die "import-pop3: Unable to execute SQL statement.\n";
    $row = $sth->fetchrow_hashref;
    my $ticket_id = $row->{ticket_id};
    
    # Update ticket field stored in the im_tickets table
    print "import-pop3: before im_tickets update\n" if ($debug >= 1);
    $sql = "
		update im_tickets set
			ticket_type_id			= '$ticket_type_id',
			ticket_status_id		= '$ticket_status_id',
			ticket_customer_contact_id	= '$ticket_customer_contact_id',
			ticket_prio_id			= '$ticket_prio_id'
		where
			ticket_id = $ticket_id
    ";
    $sth = $dbh->prepare($sql);
    $sth->execute() || die "import-pop3: Unable to execute SQL statement: \n$sql\n";
    
    # Update ticket field stored in the im_projects table
    print "import-pop3: before im_projects update\n" if ($debug >= 1);
    $sth = $dbh->prepare("
		update im_projects set
			project_name		= $ticket_name_q,
			project_nr		= '$ticket_nr',
			parent_id		= $ticket_sla_id
		where
			project_id = $ticket_id;
    ");
    $sth->execute() || die "import-pop3: Unable to execute SQL statement: \n$sql\n";


    # --------------------------------------------------------
    # Add a Forum Topic Item into the ticket
    
    # Get the next topic ID
    print "import-pop3: before nextval\n" if ($debug >= 1);
    $sth = $dbh->prepare("SELECT nextval('im_forum_topics_seq') as topic_id");
    $sth->execute() || die "import-pop3: Unable to execute SQL statement.\n";
    $row = $sth->fetchrow_hashref;
    my $topic_id = $row->{topic_id};
    
    my $topic_type_id = 1108; # Note
    my $topic_status_id = 1200; # open
    
    # Insert a Forum Topic into the ticket container
    print "import-pop3: before im_forum_topics insert\n" if ($debug >= 1);
    $sql = "
		insert into im_forum_topics (
			topic_id, object_id, parent_id,
			topic_type_id, topic_status_id, owner_id,
			subject, message
		) values (
			'$topic_id', '$ticket_id', null,
			'$topic_type_id', '$topic_status_id', '$ticket_customer_contact_id',
			$subject_q, $body_q
		)
    ";
    $sth = $dbh->prepare($sql);
    $sth->execute() || die "import-pop3: Unable to execute SQL statement: \n$sql\n";


    # --------------------------------------------------------
    # Start a new dynamic workflow around the ticket
    
    # Get the next topic ID
    print "import-pop3: before aux_string1\n" if ($debug >= 1);
    $sth = $dbh->prepare("SELECT aux_string1 from im_categories where category_id = '$ticket_type_id'");
    $sth->execute() || die "import-pop3: Unable to execute SQL statement: \n$sql\n";
    $row = $sth->fetchrow_hashref;
    my $workflow_key = $row->{aux_string1};
    defined($workflow_key) or $workflow_key = "";
    if ("" ne $workflow_key) {
	print "import-pop3: Starting workflow '$workflow_key'\n" if ($debug);
	$sql = "
		select workflow_case__new (
			null,
			'$workflow_key',
			null,
			'$ticket_id',
			now(),
			0,
			'0.0.0.0'
		) as case_id
	";
	$sth = $dbh->prepare($sql) || die "import-pop3: Unable to prepare SQL statement: \n$sql\n";
	$sth->execute() || die "import-pop3: Unable to execute SQL statement: \n$sql\n";
	$row = $sth->fetchrow_hashref;
	my $case_id = $row->{case_id};

	print "import-pop3: before workflow_case__start_case\n" if ($debug >= 1);
	$sql = "
		select workflow_case__start_case (
			'$case_id',
			'$ticket_customer_contact_id',
			'0.0.0.0',
			null
		)
	";
	$sth = $dbh->prepare($sql) || die "import-pop3: Unable to prepare SQL statement: \n$sql\n";
	$sth->execute() || die "import-pop3: Unable to execute SQL statement: \n$sql\n";
	
    }


    # --------------------------------------------------------
    # Save Attachments
    #
    $sth = $dbh->prepare("SELECT company_path from im_companies where company_id = $ticket_customer_id");
    $sth->execute() || die "import-pop3: Unable to execute SQL statement.\n";
    $row = $sth->fetchrow_hashref;
    my $customer_path = $row->{company_path};

    for($i=0; $i <= $#attname; $i++){
	my $att_name = $attname[$i];
	my $att_content = $attachment[$i];
	my $path = "$ticket_file_storage/$customer_path/$ticket_nr";
	print "import-pop3: Writing attachment to file=$path/$att_name\n" if ($debug >= 1);
	system("mkdir -p $path");
	open(OUT, ">$path/$att_name");
	print OUT $att_content;
	close(OUT);
    }

    # Remove the message from the inbox
#    $pop3_conn->delete($msg_num);
}

# --------------------------------------------------------
# Close the connection to the POP3 server
$pop3_conn->quit();

# --------------------------------------------------------
# check for problems which may have terminated the fetch early
$sth->finish;
warn $DBI::errstr if $DBI::err;

# --------------------------------------------------------
# Close the database connection
$dbh->disconnect ||
	warn "Disconnection failed: $DBI::errstr\n";


# --------------------------------------------------------
# Return a successful execution ("0"). Any other value
# indicates an error. Return code meaning still needs
# to be determined, so returning "1" is fine.
exit(0);
