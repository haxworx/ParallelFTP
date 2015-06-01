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

use Transfer;

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

	foreach (@pid) {
		waitpid($_, -1);
	}

	print "You have $cpu_count CPUs\n"; exit;
	print "done!";
}

main(@ARGV);

exit 0;
