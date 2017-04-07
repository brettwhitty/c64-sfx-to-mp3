#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use File::Slurp;

my $input;

GetOptions(
	'input|i=s'	=>	\$input,
);

my @source_code;

if (-f $input) {
	@source_code = read_file($input);
} else {
	die "Provide *.m input file with --input|-i flag!";
}


my $line_count = scalar @source_code;
my $vars = {};
my $subs = {};
my $opcodes = {};

my $ts = 4;
my $label;

for (my $i = 0; $i < $line_count; $i++) {
	
	my $line = $source_code[$i];
	
	## stripping comments
	$line =~ s/;.*//;

	if ($line =~ /^\s*$|^\s*#.*$/) {
		## print blank lines & comment lines
		print $line;
	} elsif ($line =~ /^\s*define\s+(\S+)\s*\=\s*(\S+)(.*)$/) {
		## replace ^define VAR = VAL with 'my $VAR = $VAL'
		my ($var, $val, $rest) = ($1, $2, $3);

		## ensure whitespace around operators
		## for easier token replacement
		$val =~ s/\s*([\+\-\*]+)\s*/ $1 /;

		## store this for regex replacement later
		$vars->{$var} = $val;

		$val = label_replace($vars, $val);

		print "my \$$var = $val;  $rest\n";

	} elsif ($line =~ /^\s*(\w+)[:]+\s*(.*)$/) {
		($label, my $rest) = ($1, $2);
		
		$rest =~ s/^\s+|\s+$//g;

		if (length($rest) > 0) {
			if ($rest =~ /^byte\s*(\S+)/) {
				$rest = "return ($1);";
			}
			push(@{$subs->{$label}}, $rest);
		}
	} elsif ($label) {
		$line =~ s/^\s*|\s*$//g;
		$line =~ s/\s+/ /g;

		if ($line =~ /^byte\s*(\S+)/) {
			$line = "return ($1);";
		} elsif ($line =~ /\{$/) {
			## indent + ts
		} elsif ($line =~ /^\}/) {
			## indent - ts
		} else {
			my ($operator, $operand) = split(/ /, $line);
	
			if ($operand) {	
				$operand = label_replace($vars, $operand);
			}

			$line = opdecode($operator, $operand);

			$line .= ';';
		}
		push(@{$subs->{$label}}, $line);
	}
		
}

sub opdecode {
	my ($operator, $operand) = @_;


	my $line;

	if ($operator =~ /^rts$/) {
		$line = 'return';
	} elsif ($operator eq 'sta') {
		if ($operand =~ /[a-z]+\[/) {
		    $operand =~ s/([a-z]+\[)/\$$1/g;
		    $operand =~ s/\$\$/\$/g;
		}
		$line = "$operand = \$a";
	} elsif ($operator =~ /^dex$/) {
		$line = '$x--';
	} elsif ($operator =~ /^dey$/) {
		$line = '$y--';
	} elsif ($operator =~ /^lsr$/) {
		$line = "$operator >> $operand";
	} else {
		$line = $operator;
		if ($operand) {
			$line .= " $operand";
		}
		$opcodes->{$operator} = 1;
	}


	return $line;
}


sub label_replace {
	my ($vars, $val) = @_;

	foreach my $v(keys %{$vars}) {
		if ($val =~ /\s*$v\s*/) {
			$val =~ s/(\s*)$v(\s*)/$1\$$v$2/g;
		};
	}

	return $val;
}


use Data::Dumper;
print Dumper $subs;
print Dumper $opcodes;
