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
use Encode qw(decode encode);
use Encode::Guess;
use Getopt::Long;
use Data::Dumper;

# --------------------------------------------------------
# Debug? 0=no output, 10=very verbose
$debug = 3;
MIME::Tools->debugging(0);

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
$pop3_limit = 0;					# 0=no limit, otherwise limit to N messages
$pop3_no_create = 0;					# 0=normal operations, 1=don't create tickets
$pop3_ticket_status_id = "30000";			# 30000 for ticket status "Open"

# --------------------------------------------------------
# Check for command line options
#
my $message_file = "";
my $result = GetOptions (
    "file=s"     => \$message_file,
    "debug=i"    => \$debug,
    "no-create"  => \$pop3_no_create,
    "limit=i"    => \$pop3_limit,
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
$dbh = DBI->connect($db_datasource, $db_username, $db_pwd, {pg_enable_utf8 => 1, PrintWarn => 0, PrintError => 1}) ||
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

$sth = $dbh->prepare("SELECT attr_value FROM apm_parameters ap, apm_parameter_values apv WHERE ap.parameter_id = apv.parameter_id and ap.package_key = 'intranet-helpdesk' and ap.parameter_name = 'DefaultNewTicketStatus'");
$sth->execute() || die "import-pop3: Unable to execute SQL statement.\n";
$row = $sth->fetchrow_hashref;
my $value  = $row->{attr_value};
if (defined $value) { 
    print "import-pop3: DefaultNewTicketStatus=$value\n";
    $pop3_ticket_status_id = $value; 
}



print "import-pop3: host=$pop3_host, user=$pop3_user, pwd=$pop3_pwd\n" if ($debug > 9);
die "import-pop3.perl: You need to define a pop3_host" if ("" eq $pop3_host);
die "import-pop3.perl: You need to define a pop3_user" if ("" eq $pop3_user);
die "import-pop3.perl: You need to define a pop3_pwd" if ("" eq $pop3_pwd);


# --------------------------------------------------------
# Establish a connection to the POP3 server
#


# MIME Parser initialization
my $mime_parser = new MIME::Parser;
$mime_parser->ignore_errors(1);
$mime_parser->output_to_core(1);
$mime_parser->tmp_to_core(1);

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
	$result .= decode_body($part);
	if (@parts) { foreach $i (0 .. $#parts) { $result .= process_parts($parts[$i], ("$name, part ".(1+$i))); }} 

    } elsif ($mime_type eq "text/html") {

	print "import-pop3: process_parts: text/html: adding to result\n" if ($debug >= 1);
	print "import-pop3: process_parts: text/html: ", $bodyh, "\n" if ($debug >= 2);
	$result .= decode_body($part);
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
	    print "import-pop3: process_parts: multipart/alternative: added to result\n" if ($debug >= 2);
	} else {
	    print "import-pop3: process_parts: multipart/alternative: alternative with wrong argument count\n" if ($debug >= 1);
	    for my $subpart ($part->parts()) {
		print "import-pop3: process_parts: multipart/alternative: subpart: adding to result\n" if ($debug >= 1);
		if (@parts) { foreach $i (0 .. $#parts) { $result .= process_parts($parts[$i], ("$name, part ".(1+$i))); }} 
		print "import-pop3: process_parts: multipart/alternative: subpart: added to result\n" if ($debug >= 1);
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
# Decode a MIME body in order to deal with Outlook and Gmail
# --------------------------------------------------------

sub decode_body {
    my ($part) = @_;
    print "import-pop3: decode_body: part='", Dumper($part), "'\n" if ($debug >= 1);
   
    my $result = "";
    eval {
	$result = decode_body_helper($part);
    };
    if (my $err = $@) {
	print "import-pop3: decode_body: cought error: $err\n";
    }
    return $result
}

sub decode_body_helper {
    my ($part) = @_;
    print "import-pop3: decode_body_helper: part='", Dumper($part), "'\n" if ($debug >= 1);
    my $utf8 = "";
    my $latin1 = "";
    my $body = "";

    # Convert body to Perl String
    my $bh = $part->bodyhandle;
    $bh->is_encoded(1);
    my $output = '';
    my $fh = IO::File->new( \$output, '>:' ) or croak("Cannot open in-memory file: $!");
    $part->print_bodyhandle($fh);
    $fh->close;
    print "import-pop3: decode_body: output='", $output, "'\n" if ($debug >= 7);

    # Decode and deal with Latin-1 from Outlook vs. UTF-8 from Google
    my $enc = guess_encoding($output, qw/utf8 latin1/);
    if (!ref($enc)) {
	print "import-pop3: decode_body: guess_encoding didn't find encoding\n" if ($debug >= 1);
	print "import-pop3: decode_body: output='", unpack("H*", $output), "'\n" if ($debug >= 7);
	$body = decode("iso-8859-1", $output);
	$body = Encode::encode("UTF-8", $body);    # Make sure there are no invalid UTF-8 sequences in body
    } else {
	print "import-pop3: decode_body: encoding=", $enc->name, "'\n" if ($debug >= 1);
	$utf8 = $enc->decode($output);
	$body = decode("iso-8859-1", $utf8);
	print "import-pop3: decode_body: utf8='", $utf8, "'\n" if ($debug >= 7);
	print "import-pop3: decode_body: utf8='", unpack("H*", $utf8), "'\n" if ($debug >= 7);
    }

    my $unistr = decode("utf8", $body);
    my $latin1str = encode('iso-8859-1', $unistr );
    $body = $latin1str;

#    $body = $body . "\n" . unpack("H*", $body);
#    $body = encode("iso-8859-1", $body);

    return $body;
}


# --------------------------------------------------------
# Decode a MIME subject line in order to deal with Outlook
# --------------------------------------------------------

sub decode_subject_line {
    my ($subject, $x_mailer) = @_;
    my $decoded_subject = "undefined";
    print "import-pop3: decode_subject_line: Subject='", $subject, "', X-Mailer=", $x_mailer, "\n" if ($debug >= 1);

    # Check if the subject is "B" or "Q" encoded
    # if ($subject =~ /\=\?([a-zA-Z0-9_\-]+)\?([^\?]+)\?\=/) {
    if ($subject =~ /\=\?([a-zA-Z0-9_\-]+)\?([BQ])\?([^\?]+)\?\=$/) {
	print "import-pop3: decode_subject_line: Using mime_to_perl_string to decode =?...?.?.......?= format.\n" if ($debug >= 1);
	$decoded_subject = mime_to_perl_string($subject);
	print "import-pop3: decode_subject_line: hex=", unpack("H*", $decoded_subject), "\n" if ($debug >= 1);
	return $decoded_subject;
    }

    # Outlook and other mailers may just send Latin-1 encoded subjects
    # We need to convert these strings to UTF-8 for the database
    print "import-pop3: decode_subject_line: Did not find any specific encoding in subject - converting to UTF-8.\n" if ($debug >= 1);
    $decoded_subject = decode("iso-8859-1", $subject);
    print "import-pop3: decode_subject_line: hex=", unpack("H*", $decoded_subject), "\n" if ($debug >= 1);

    # Old style WordDecode - deprecated
    # $wd = supported MIME::WordDecoder "ISO-8859-1";
    # $wd = supported MIME::WordDecoder "UTF-8";
    # $subject = $wd->decode($subject);

    return $decoded_subject;
}

# --------------------------------------------------------
# Process a single message
# --------------------------------------------------------

sub process_message {
    my ($message) = @_;

    print "import-pop3: process_message: message=", $message, "\n" if ($debug >= 7);

    # Parse the MIME email
    my $mime_entity = $mime_parser->parse_data($message);
    my $error = ($@ || $mime_parser->last_error);
    print "import-pop3: error: $error\n" if ("" ne $error);
    my $header = $mime_entity->head();

    my $to = $header->get('To');
    my $from = $header->get('From');
    my $email_id = $header->get('Message-ID');
    my $in_reply_to_email_id = $header->get('In-Reply-To');
    defined($in_reply_to_email_id) or $in_reply_to_email_id = "";
    my $content_type = $header->get('Content-Type');
    defined($content_type) or $content_type = "";
    my $x_mailer = $header->get('X-Mailer');
    defined($x_mailer) or $x_mailer = "";
    my $subject_raw = $header->get('Subject');
    if (!defined $subject_raw) { $subject_raw = 'No Subject'; }

    if (!defined $from && !defined $to && !defined $email_id) { 
	print "import-pop3: Found an email without from, to or id fields - skipping\n" if ($debug >= 1);
	return; 
    }

    chomp($from);
    chomp($to);
    chomp($email_id);
    $email_id =~ s/[^ _a-zA-Z0-9\@\<\>\=\+\-\.]//g;
    chomp($in_reply_to_email_id);
    chomp($content_type);
    chomp($x_mailer);
    chomp($subject_raw);

    my $subject = decode_subject_line($subject_raw, $x_mailer);
    $subject =~ s/[\000-\037]/ /g;                 # Replace control characters by spaces
    $subject = substr $subject, 0, 100;            # maximum length
    my $subject_q = $dbh->quote($subject);

    print "import-pop3: \n" if ($debug >= 1);
    print "import-pop3: id:\t$email_id\n" if ($debug >= 1);
    print "import-pop3: in-reply-to:\t$in_reply_to_email_id\n" if ($debug >= 1);
    print "import-pop3: from:\t$from\n" if ($debug >= 1);
    print "import-pop3: to:\t$to\n" if ($debug >= 1);
    print "import-pop3: subject:\t$subject_q\n" if ($debug >= 1);
    print "import-pop3: content-type:\t$content_type\n" if ($debug >= 1);

    # Save the email in the /tmp directory with Message-ID
    if ("" eq $message_file && $debug >= 3) {
	my $dir = dir("/tmp");
	my $file = $dir->file("email-".$email_id);
	my $file_handle = $file->openw();        # Get a file_handle (IO::File object) you can write to
	$file_handle->print(@$message);
    }

    # Parse the email
    my $body = process_parts($mime_entity, "main");
    print "import-pop3: body=$body\n" if ($debug >= 1);
    print "import-pop3: hex(body)=", unpack("H*", $body), "\n" if ($debug >= 7);

    my $body_q = $dbh->quote($body);

    # --------------------------------------------------------
    # Check for duplicates
    
    $sth = $dbh->prepare("SELECT min(ticket_id) as duplicate_ticket_id from im_tickets where ticket_email_id = '$email_id'");
    $sth->execute() || die "import-pop3: Unable to execute SQL statement.\n";
    my $row = $sth->fetchrow_hashref;
    my $duplicate_ticket_id = $row->{duplicate_ticket_id};

    if (defined $duplicate_ticket_id) {
	# We have found a ticket with the same mail-id!!!
	print "import-pop3: error: Found an email with a duplicate Message-Id\n";
	print "import-pop3: error: Duplicate Message-ID: $email_id\n";
	print "import-pop3: error: Duplicate From: $from\n";
	print "import-pop3: error: Duplicate To: $to\n";
	print "import-pop3: error: Duplicate Subject: $subject_raw\n";
	print "import-pop3: error: Duplicate ticket_id: $duplicate_ticket_id\n";
	return;
    }

    # --------------------------------------------------------
    # Calculate ticket database fields
    
    # Ticket Nr: Take current number from the im_ticket_seq sequence
    $sth = $dbh->prepare("SELECT nextval('im_ticket_seq') as ticket_nr");
    $sth->execute() || die "import-pop3: Unable to execute SQL statement.\n";
    $row = $sth->fetchrow_hashref;
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
    $sth = $dbh->prepare("SELECT min(project_id) as sla_id from im_projects where company_id = '$ticket_customer_id' and project_type_id = 2502 and project_status_id in (select im_sub_categories(76))");
    my $rv = $sth->execute() || die "import-pop3: Unable to execute SQL statement.\n";
    my $ticket_sla_id = "NULL";
    if ($rv >= 0) {
	$row = $sth->fetchrow_hashref;
	my $ticket_sla_id = $row->{sla_id};
    }
    if ("NULL" eq $ticket_sla_id) {
	# Didn't find an open SLA, so let's just take the first one in any state
	$sth = $dbh->prepare("SELECT min(project_id) as sla_id from im_projects where project_type_id = 2502");
	my $rv = $sth->execute() || die "import-pop3: Unable to execute SQL statement.\n";
	if ($rv >= 0) {
	    $row = $sth->fetchrow_hashref;
	    my $ticket_sla_id = $row->{sla_id};
	}
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
    my $ticket_status_id = $pop3_ticket_status_id;
    
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
		SELECT im_ticket__new_with_email_id (
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
			'$ticket_status_id'::integer,

			'$email_id',
			'$in_reply_to_email_id'
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
    # Add the customer contact to the list of "members" of the ticket
    if (0 ne $ticket_customer_contact_id) {


	# Create a business relationship between the ticket and the user
	print "import-pop3: before im_biz_object_member__new\n" if ($debug >= 1);
	$sth = $dbh->prepare("
		select im_biz_object_member__new(
			null,
			'im_biz_object_member',
			$ticket_id,
			'$ticket_customer_contact_id',
			1300,
			0,
			'0.0.0.0'
		);
        ");
	$sth->execute() || die "import-pop3: Unable to execute SQL statement: \n$sql\n";
    }

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
    $sth->execute();

    # Check if there was an error inserting. This usually happens
    # because of wrong UTF8-Encoding. In this case just try again
    # after fixing the encoding.
    if ($sth->err) {
	$body = Encode::encode("UTF-8", $body);    # Make sure there are no invalid UTF-8 sequences in body
	$body_q = $dbh->quote($body);
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
    }

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
	if (!defined $att_name) { next; }
	my $att_content = $attachment[$i];
	my $path = "$ticket_file_storage/$customer_path/$ticket_nr";
	print "import-pop3: Writing attachment to file=$path/$att_name\n" if ($debug >= 1);
	system("mkdir -p $path");
	open(OUT, ">$path/$att_name");
	print OUT $att_content;
	close(OUT);
    }
}




# --------------------------------------------------------
# Loop for each of the mails
#
if ("" ne $message_file) {
    # The user specified a file at the command line
    print "import-pop3: Reading input from message_file='$message_file'\n" if ($debug >= 1);
    open my $fh, '<', $message_file or die "import-pop3: Error opening $message_file: $!";
    my $message = do { local $/; <$fh> };
    process_message($message);

} else {

    # Establish a connection to the POP3 server
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
    my $cnt = 1;
    foreach $msg_num (keys(%$msgList)) {
	# Get the mail as a file handle
	$message = $pop3_conn->get($msg_num);

	if (0 eq $pop3_no_create) {
	    process_message($message);
	} else {
	    print "import-pop3: Skipping message:\n" if ($debug >= 1);
	}
       
	# Remove the message from the inbox
	$pop3_conn->delete($msg_num);

	$cnt++;
	if (0 ne $pop3_limit && $cnt > $pop3_limit) { last; }
    }

    # Close the connection to the POP3 server
    $pop3_conn->quit();

}

# --------------------------------------------------------
# Close connections to the DB and exit
#
$sth->finish;
warn $DBI::errstr if $DBI::err;
$dbh->disconnect || warn "Disconnection failed: $DBI::errstr\n";
exit(0);
