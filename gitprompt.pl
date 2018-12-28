#!/usr/bin/perl -w

eval 'exec /usr/bin/perl -w -S $0 ${1+"$@"}'
    if 0; # not running under some shell
use strict;

=ignore
Copyright 2013 Synacor, Inc.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
=cut

use IO::Handle;
use IPC::Open3;
use Time::HiRes qw(time);

### prechecks ###
my $ps0 = $ENV{GIT_PROMPT} ? $ENV{GIT_PROMPT} : $ENV{PS0};
unless ($ps0) {
  print "!define PS0!> ";
  exit 1;
}

### global definitions ###
my %formatliteral = (
  e => "\e",
  '%' => '%',
  '[' => "\\[",
  ']' => "\\]",
);
my %formatcondkeep = (
  g => 1,
);

### definitions ###
my %opt = (
  c => 'c',
  u => 'u',
  f => 'f',
  A => 'A',
  B => 'B',
  F => 'F',
  t => '?',
  l => '?~',
  n => '??',
  g => '',
  statuscount => 0,
  keepempty => 1,
);

### read options ###
if (@ARGV) {
  foreach (@ARGV) {
    return {error=>"invalid parameter $_"} unless /^(\w+)\=(.*?)$/;
    my ($key,$val) = ($1,$2);
    $val =~ s/\%(.)/exists $formatliteral{$1} ? $formatliteral{$1} : ''/ge;
    $opt{$key} = $val;
  }
}

my %formatvalue = %{gitdata()};
my $output = "";
my @ps0 = split(/\%\{(.*?)\%\}/, $ps0);
my $conditional = 0;
foreach my $part (@ps0) {
  if ($conditional) {
    my $keep = 0;
    my $formatter = sub {
      my ($code) = @_;
      if (exists $formatliteral{$code}) {
        return $formatliteral{$code};
      } elsif (exists $formatvalue{$code} && ($opt{keepempty} || length $formatvalue{$code} || $formatcondkeep{$code})) {
        $keep = 1;
        return $formatvalue{$code};
      } else {
        return '';
      }
    };
    $part =~ s/\%(.)/$formatter->($1)/ge;
    $output .= $part if $keep;
  } else {
    $part =~ s/\%(.)/exists $formatliteral{$1} ? $formatliteral{$1} : exists $formatvalue{$1} ? $formatvalue{$1} : ''/ge;
    $output .= $part;
  }
  $conditional = !$conditional;
}
$output = "\\[\e[0;30;41m\\]! $formatvalue{error} !\\[\e[0m\\]$output" if exists $formatvalue{error};
print $output;

sub gitdata {
  ### prechecks ###
  chomp(my $headref = `git symbolic-ref HEAD 2>&1`);
  return {} if $headref =~ /fatal: Not a git repository|fatal: Unable to read current working directory/i;

  ### collect branch data ###
  chomp(my $commitid = `git rev-parse --short HEAD 2>&1`);
  my $branch = $commitid; #fallback value
  if ($headref =~ /fatal: ref HEAD is not a symbolic ref/i) {
    # find gitdir
    chomp(my $gitdir = `git rev-parse --git-dir`);

    # parse HEAD log
    open(HEADLOG, "$gitdir/logs/HEAD");
    my $lastrelevant = '';
    while (<HEADLOG>) {
      $lastrelevant = $_ if /^\s*\w+\s+$branch\w+\s/;
    }

    # if the log mentions switching to the commit id, use whatever it calls it
    $branch = $1 if $lastrelevant =~ /\scheckout\:\s+moving\s+from\s+\S+\s+to\s+(\S+)\s*$/ || $lastrelevant =~ /\smerge\s+(\S+)\:\s+Fast\-forward\s*$/;
  } elsif ($headref =~ /^refs\/heads\/(.+?)\s*$/) {
    # normal branch
    $branch = $1;
  } else {
    # unexpected input
    $headref =~ s/[^\x20-\x7e]//g;
    return {error=>$headref};
  }

  ### collect status data ###
  my ($statusexitcode, $statusout, @status);
  $SIG{CHLD} = sub { wait(); $statusexitcode = $?>>8; };
  my $statuspid = open3(undef,$statusout,undef,"git status");
  $statusout->blocking(0);
  my ($running, $waiting, $start, $valid) = (1, 1, time, 0);
  while ($running && $waiting) {
    while (<$statusout>) {
      push @status, $_;
    }

    $running = kill 0 => $statuspid;
    select undef, undef, undef, .001; #yield, actually
    $waiting = time < $start + 1;
  }

  ### parse status data ###
  my %statuscount;
  my %sectionmap = (
    'Changes to be committed' => 'c',
    'Changed but not updated' => 'u',
    'Changes not staged for commit' => 'u',
    'Untracked files' => 'f',
    'Unmerged paths' => 'u',
  );
  $statuscount{$_} = 0 foreach values %sectionmap;
  my $can_fast_forward = '';

  if (!$running) {
    # if it terminated, parse output
    my ($section);
    foreach (@status) {
      if (/^(?:\# )?(\S.+?)\:\s*$/ && exists $sectionmap{$1}) {
        $section = $sectionmap{$1};
      } elsif ($section && /^\#?\t\S/) {
        $statuscount{$section}++;
        $valid = 1;
      } elsif (/^nothing to commit\b/) {
        $valid = 1;
      } elsif (/\bis (ahead|behind) .+ by (\d+) commits?(\,? and can be fast\-forwarded)?/) {
        $statuscount{($1 eq 'ahead') ? 'A' : 'B'} = $2;
        $can_fast_forward = 1 if $3;
      } elsif (/^(?:\# )?and have (\d+) and (\d+) different commit/) {
        $statuscount{A} = $1;
        $statuscount{B} = $2;
      }
    }
  }

  my $timeout = '';
  if ($running) {
    # it was running when we stopped caring
    $timeout = $opt{t};
    kill 2 => $statuspid;
  } elsif (!$valid) {
    #determine cause of failure
    if ($status[0] =~ /\.git\/index\.lock/) {
      $timeout = $opt{l};
    } elsif ($status[0] =~ /must be run in a work tree/) {
      $timeout = $opt{n};
    } else {
      print "\\[\e[41m\\]!! gitprompt.pl: \\`git status\' returned with exit code $statusexitcode and message:\n$status[0]\\[\e[0m\\]";
      $timeout = "\\[\e[41m\\]!$statusexitcode!\\[\e[0m\\]";
    }
  }

  ### produce output ###
  my %formatvalue = (
    b => $branch,
    i => $commitid,
    t => $timeout,
    g => $opt{g},
  );
  $formatvalue{F} = $opt{F} if $can_fast_forward;
  foreach my $flag (keys %statuscount) {
    $formatvalue{$flag} = $statuscount{$flag} ? ($opt{$flag}.($opt{statuscount} ? $statuscount{$flag} : '')) : '';
  }
  return \%formatvalue;
}
