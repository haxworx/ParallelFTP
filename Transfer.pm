#! /usr/bin/perl

use strict;
use warnings;

use Net::FTP;
use Net::SCP qw/scp iscp/;
use LWP::UserAgent;

our $CPU_COUNT = 4;
package Transfer;

sub new {
	my ($self, $hostname, $username, $password) = @_;
	
	my $CLASS = "";

	if ($hostname =~ m/\Aftp:\/\/(.+)\z/) {
		$hostname = $1;
		$CLASS = 'Net::FTP';
	} elsif ($hostname =~ m/\Ascp:\/\/(.+)\z/) {
		$hostname = $1;
		$CLASS = 'Net::SCP';
	} elsif ($hostname =~ m/\Ahttps?:\/\/(.+)\z/) {
		$hostname = $1;
		$CLASS = 'LWP::UserAgent';
	} else {
		die "Unknown protocol prefix!";
	}

	my %args = (
		'Host' => $hostname,
		'user' => $username,
		'host' => $hostname,
		'password' => $password,
		'cwd' => '.',
		'Debug'  => 0,
		'type' => $CLASS,
	);

	if ($CLASS eq "Net::SCP") {
		$args{'handle'} = $CLASS->new(\%args) || 	
				die "new()". $args{'handle'}->{errstr} . "\n";
	} elsif ($CLASS eq "Net::FTP") {
		$args{'handle'} = $CLASS->new($hostname);
		$args{'handle'}->login($username, $password) ||
                        die "login() $args{'handle'}->{errstr}";
	} elsif ($CLASS eq "LWP::UserAgent") {
		$args{'handle'} = $CLASS->new() ||
			die "UserAgent()";
	}
	
	return bless \%args;
}

sub folder {
	my $self = shift;
	return $self->{'folder'};
}

sub username {
	my $self = shift;
	return $self->{'username'};
}

sub password {
	my $self = shift;
	return $self->{'password'};
}
sub handle {
	my $self = shift;
	return bless $self->{'handle'}, $self->{'type'};
}

sub type {
	my $self = shift;
	return $self->{'type'};
}

sub post {
	my ($self, %args) = @_;

	my $url = $self->hostname();
	if (!defined $url) {
		$url = $args{'url'};
	}
		
	my $response = $self->handle->post($url,	
		[ 'name'  => $args{'name'}, 
		  'value' => $args{'value'}
		]
	);

	die "post()\n" unless $response->is_success;
}

sub put_files {
	my ($self, @file_list) = @_;	

	foreach (@file_list) {
		$self->handle->put($_) || die "put()";
	}

	$self->handle->close();
}

sub get_files {
	my ($self, @file_list) = @_;

	foreach (@file_list) {
		$self->handle->get($_);
	}

	$self->handle->close();
}

1;

=cut

#! /usr/bin/perl

use Transfer;

my $ftp_transfer = Transfer->new('ftp://ftp.kernel.org', 'anonymous', 'al@al.com');
my @list = ("a.pl");

$ftp_transfer->get_files(@list);


my $sftp_transfer = Transfer->new('scp://nipl.net', 'username', 'password');

$sftp_transfer->put_files(@list);

my $http_transfer = Transfer->new("http://haxlab.org");
$http_transfer->post( ( name => 'song', value => '100' ) );

exit 0;
