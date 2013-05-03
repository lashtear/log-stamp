#! /usr/bin/perl
# Log Stamp - a perl logging utility for slapd

# Copyright (c) 2009-2013 Symas Corporation
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
#    * Redistributions of source code must retain the above copyright
#      notice, this list of conditions and the following disclaimer.
#
#    * Redistributions in binary form must reproduce the above
#      copyright notice, this list of conditions and the following
#      disclaimer in the documentation and/or other materials provided
#      with the distribution.
#
#    * Neither the name of the author nor the names of other
#      contributors may be used to endorse or promote products derived
#      from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
# FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
# COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
# ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

# This software was originally written by Emily Backes
# <ebackes@symas.com> for Symas Corporation.

use strict;
use warnings;
use Time::HiRes qw(gettimeofday);
use POSIX qw(strftime);

unless (@ARGV) { die "usage is:\n  log-stamp.pl program [args...]\n"; }

$|=1;

my $pid = open PIPE, "-|";
if ($pid) { # parent
    warn "*** Forked child with pid $pid\n";
    foreach my $sig (qw(INT TERM QUIT)) {
	$SIG{$sig} = sub { 
	    warn "*** Sending SIG$sig to child process\n";
	    kill $sig, $pid;
	}
    }
    my $result = 1;
    my $buffer = "";
    while ($result) {
	$result = sysread PIPE,$buffer,16384,length($buffer);
	if (not defined $result) {
	    redo if ($! eq 'Interrupted system call');
	    warn "*** sysread: $!\n";
	    last;
	}
	last unless ($result > 0);
	$buffer =~ s/[\r]//g;
	my ($complete, $partial) = ($buffer =~ /^(.*\n)?([^\n]*)$/gs);
	unless ($complete) {
	    $complete = "$partial\n";
	    $partial = "";
	}
	my ($sec, $usec) = gettimeofday();
	$complete =~ s/([^ -~\n])/sprintf ("\\%03o", ord($1))/mesg;
	my $stamp = sprintf "%s.%06d: ",
	  strftime ("%Y-%m-%d %T", localtime ($sec)),
	    $usec,
	      $_;
	my $pad = " " x (length $stamp);
	$complete =~ s/\n(.)/\n$pad$1/gsm;
	print $stamp,$complete;
	$buffer = $partial;
    }
    close PIPE
      or die "*** Fork/exec returned $?\n";
    warn "*** Child exited cleanly\n";
} else { # child
    open STDERR, ">&STDOUT"
      or die "*** dup: stdout: $!\n";
    exec @ARGV
      or die "*** exec: $ARGV[0]: $!\n";
}
