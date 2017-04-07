#!/usr/bin/perl

my $ws = 0;
my $bc = '';
my $bits = '';
my $byte_count = 0;
my $bcomment = '';

## See:
## 	http://www.sidmusic.org/sid/sidtech2.html

if (0) {
print "# gate_bit	0b00000001	Trigger Attack/Decay/Sustain if 1, silent if 0\n";
print "# sync_bit	0b00000010	'Hard Sync' effect\n";
print "# ring_bit	0b00000100	'Ring Modulator' effect\n";
print "# test_bit	0b00001000	Reset Oscillator 1 while set\n";
print "# triangle_wave	0b00010000	|W\n";
print "# sawtooth_wave	0b00100000	|A\n";
print "# pulse_wave	0b01000000	|V\n";
print "# noise_wave	0b10000000	|E\n";
}

while (<>) {
	if (/^\s+$|^\;/) {
		$ws = 1;
		
		if ($bc ne '') {
			$bc = sprintf("0x%02X", hex($bc));
			print "   $bc\t$bits\t$byte_count\t$bcomment\n";
			$bc = '';
			$bits = '';
			$byte_count = 0;
			$bcomment = '';
		}

		next;
	} elsif (/^\s*byte\s+(\S+)(\s+\;(.*))?/) {
		my ($byte, $comment) = ($1, $2);
		
		my @bytes = split(/,/, $byte);
		$byte_count += scalar(@bytes);
		if ($bc eq '') {
			$bc = $bytes[0];
			$bits = sprintf("%08b", hex($byte));
			$bcomment = $comment;
		}
	}
}
if ($bc){
			$bc = sprintf("0x%02X", hex($bc));
print "   $bc\t$bits\t$byte_count\t$bcomment\n";
}
