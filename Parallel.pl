#! /usr/bin/perl

#
#  Copyright (c) 2015, Al Poole <netstar@gmail.com>
#
#
#  Permission to use, copy, modify, and/or distribute this software for any 
#  purpose with or without fee is hereby granted, provided that the above 
#  copyright notice and this permission notice appear in all copies.
#
#  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
#  REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY 
#  AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, 
#  INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM 
#  LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
#  OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR 
#  PERFORMANCE OF THIS SOFTWARE.

#  I once worked for a company whih used FTP to transfer loads of files
#  concurrently. For phun I wrote this using an untested Transfer.pm
#  Supports SCP and FTP transfers at the moment...OK!


use strict;
use warnings;

use Net::FTP;
use Net::SCP qw/scp iscp/;
use LWP::UserAgent;

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

package main;



sub GetFilesList {
	my ($directory, $bunches) = @_;
	my @files = ();

	opendir DIR, $directory or die "opendir()";

	while (my $file = readdir(DIR)) {
		my $path = $directory . '/' . $file;
		if ($file eq "." || $file eq "..") { next; }
		if (-d $path) { next; };
		push @files, $path;
	}

	closedir DIR;


	my $total_files = $#files;

	my $chunk_size = $total_files / $bunches;
	my $remainder = $total_files % $bunches;
	my @chunks = (); 

	$chunks[$bunches][$chunk_size] = (); # MAX_CPUs
	my $index = 0;

	# average chunks of files 

	my $y = 0;

	for (my $i = 0; $i < $bunches; $i++) {
		for ($y = 0; $y < $chunk_size; $y++) {
			$chunks[$i][$y] = $files[$index++];					
		}
	}

	# remainder

	for (my $i = 0; $i < $remainder; $i++) {
		$chunks[$bunches - 1][$y++] =  $files[$index++];
	}

	return @chunks;
}


sub GetCPUCount {
	my $result = "";

	open CPU, "/proc/cpuinfo" or die "/proc/cpuinfo";
	$result = (map /^processor/, <CPU>);
	close CPU;

	return $result;
}

# FTP Parallel

sub main {
	my ($hostname, $username, $password, $directory) = @_;

	die "need args!" if (!defined $hostname || !defined $username || !defined $password || !defined $directory);

	print "Sending files in $directory to ftp://$username\@$hostname!\n";
	my @pids = ();

	my $cpu_count = GetCPUCount();

	my @files_list = GetFilesList($directory, $cpu_count);
	for (my $i = 0; $i < $cpu_count; $i++) {
		my $pid = fork();
		die "fork()" unless defined $pid;
		if ($pid == 0) {
			my $transfer = Transfer->new($hostname, $username, $password);
			my $list = $files_list[$i];
	
			$transfer->put_files(@{$list});

			exit(0);
		} else {
			push @pids, $pid;
		}
	}

	foreach (@pids) {
		waitpid($_, -1);
	}
	print "You have $cpu_count CPUs\n"; 
	print "done!";
}

main(@ARGV);

exit 0;
