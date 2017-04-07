#!/usr/bin/perl

use strict;
use warnings;


## filter_voice = 3
#

my $file = $ARGV[0];
## was 'box_opening.bin';

my $cmd_byte_flags = {
	'gate'		=>	0b00000001,
	'stop'		=>	0b00000010,
	'ramp'		=>	0b00000100,
	'adsr'		=>	0b00001000,
	'extended'	=>	0b00010000,
	'wave'		=>	0b00100000,
	'_BREF_'	=>	0b01000000, ## WHAT IS 'bref'???
	'loop'		=>	0b10000000,
};

my $extd_cmd_flags = {
	'duration'	=>	0b00000100,
};

my @data_raw;
my @data_hex;

{
   open(my $input, $file) or die $!;
   binmode($input);

   local $/ = \1;

   while ( my $byte_raw = <$input> ) {
      my $byte_hex = unpack( 'H*', $byte_raw );

      push(@data_raw, $byte_raw);
      push(@data_hex, $byte_hex);
   }

   close $file;
}

my $cmds = [];
my $cmds_count = 0;
while (my $cmd_byte = shift @data_hex) {

	my $flags = set_flags($cmd_byte);

	my $cmd_data = {};
	
	if ($flags->{'extended'}) {
		# special cases
		#
		# Extd
		#  + Gate
		#  + Gate + Ramp bref
		
		if ($flags->{'ramp'}) {
			my @data = splice(@data_hex, 0, 2);
			
			$cmd_data->{'freq_lo'} 		= $data[0];
			$cmd_data->{'freq_hi'} 		= $data[1];
		
			## see 'zap_duration'
			$cmd_data->{'duration_lo'} 	= '00';
			$cmd_data->{'duration_hi'} 	= '00';
			$cmd_data->{'increment_lo'} 	= '00';
			$cmd_data->{'increment_hi'} 	= '00';

		}

		## retrieve extended command byte
		my $extd_cmd_byte = shift @data_hex;
		## set extended command flags
		my $extd_flags = set_extended_flags($extd_cmd_byte);

		if ($extd_flags->{'duration'}) {
			## extended command has duration
			my @data = splice(@data_hex, 0, 2);
			
			$cmd_data->{'duration_lo'} = $data[0];
			$cmd_data->{'duration_hi'} = $data[1];
		
			if ($flags->{'gate'}) {
				#
				## what happens here?
				#
				$cmd_data->{'gate_bit'} = 1;
			}
		}

	} else {
		if ($flags->{'ramp'}) {
			my @data = splice(@data_hex, 0, 6);
			
			$cmd_data->{'freq_lo'} 		= $data[0];
			$cmd_data->{'freq_hi'} 		= $data[1];
			$cmd_data->{'duration_lo'} 	= $data[2];
			$cmd_data->{'duration_hi'} 	= $data[3];
			$cmd_data->{'increment_lo'} 	= $data[4];
			$cmd_data->{'increment_hi'} 	= $data[5];
			
			if ($flags->{'gate'}) {
				##
				## **** => what's different with gate flag?
				##
				
				$cmd_data->{'gate_bit'} = 1;

			}
		}
		if ($flags->{'adsr'}) {
			## byte1: A/D, byte2: S/R
			##
			## A/D
			## b11110000	## attack mask
			## b00001111	## decay mask
			## S/R
			## b11110000	## sustain mask
			## b00001111	## release mask
			##
			my @data = splice(@data_hex, 0, 2);

			$cmd_data->{'attack_decay'} 	= $data[0];
			#$cmd_data->{'attack_value'} 	= get_left_value($data[0]);
			#$cmd_data->{'decay_value'} 	= get_right_value($data[0]);
			$cmd_data->{'sustain_release'}	= $data[1];
			#$cmd_data->{'sustain_value'} 	= get_left_value($data[1]);
			#$cmd_data->{'release_value'}	= get_right_value($data[1]);

		}
		if ($flags->{'wave'}) {
			my @data = splice(@data_hex, 0, 1);
			
			$cmd_data->{'waveform'} 	= $data[0];
		}
		if ($flags->{'loop'}) {
			my @data = splice(@data_hex, 0, 2);
			
			$cmd_data->{'reverse_rel_branch'} 	= $data[0];
			$cmd_data->{'loop_count'}	 	= $data[1];
		}
		if ($flags->{'stop'}) {
			print "1 bytes for stop\n";
			my @data = splice(@data_hex, 0, 1);
			
			$cmd_data->{'next_sfx_number'} = $data[0];
		}

	}

	$cmds->[$cmds_count++] = {'flags' => $flags, 'data' => $cmd_data};
}
use Data::Dumper;
print Dumper $cmds;
print STDERR "## Read '$cmds_count' commands.\n";

sub set_flags {
    my ($hex_byte) = @_;
    
    my $cmd_byte = hex($hex_byte);

    my $flags = {};

    foreach my $flag(keys %{$cmd_byte_flags}) {

	if ($cmd_byte & $cmd_byte_flags->{$flag}) {
	    $flags->{$flag} = 1;
	}

    }
    return $flags;
}

sub get_left_value {
	my ($byte) = @_;

	return bit_val(hex_byte_left_bits($byte, 4));
}

sub get_right_value {
	my ($byte) = @_;

	return bit_val(hex_byte_right_bits($byte, 4));
}

sub set_extended_flags {
    my ($hex_byte) = @_;

    my $flags = {};
    
    my $cmd_byte = hex($hex_byte);

    foreach my $flag(keys %{$extd_cmd_flags}) {

	if ($cmd_byte & $extd_cmd_flags->{$flag}) {
	    $flags->{$flag} = 1;
	}

    }
    return $flags;

}

sub bit_val {
	my ($bits) = @_;

	return eval("0b$bits");
}

sub hex_byte_left_bits {
	my ($byte, $n_bits) = @_;

	unless ($n_bits) {
		$n_bits = 4;
	}

	my $bits = hex_byte_to_bits($byte);
	
	return substr($bits, 0, $n_bits) . substr('00000000', 0, 8 - $n_bits);
}

sub hex_byte_right_bits {
	my ($byte, $n_bits) = @_;

	unless ($n_bits) {
		$n_bits = 4;
	}

	my $bits = hex_byte_to_bits($byte);
	
	return substr('00000000', 0, 8 - $n_bits) . substr($bits, 8 - $n_bits, $n_bits);
}


sub hex_byte_to_bits {
	my ($byte) = @_;

	return sprintf("%08b", hex($byte));
}
