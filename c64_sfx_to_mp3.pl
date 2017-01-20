#!/usr/bin/env perl

$| = 1;

use strict;
use warnings;

##
## This script will create a C=64 BASIC program
## that generates sound using POKEs and DATA.
## 
## The program is created and written to a D64
## image file for subsequent execution in VICE.
##
## Its intended purpose is to translate sound data
## from the open-source "Lucasfilm's Habitat" macross
## source files into new formats for use with
## Hugh Manatee.
##
## Brett Whitty, Jan. 2017
## brett@gnomatix.com
##
## References:
##
##     C=64 Users Manual, Ch. 4, pp. 183-208
##     via: http://www.commodore.ca/manuals/c64_programmers_reference/c64-programmers_reference_guide-04-programming_sound.pdf
## 
##     "Lucasfilm's Habitat" sound effects source code
##     via: https://github.com/Museum-of-Art-and-Digital-Entertainment/habitat/blob/master/sources/c64/Main/sfx.m
##

use Cwd qw{cwd abs_path};
use Encode;
use Encode::Encoder qw(encoder);
use File::Basename;
use File::Copy;
use File::Slurp;
use File::Spec::Functions;
use File::Temp;
use File::Which;
use Getopt::Long;
use IPC::Open2;

my $tok64_bin   = 'tok64';
my $c1541_bin 	= 'c1541';
my $vice_bin 	= 'x64sc'; 	## accurate
my $ffmpeg_bin  = 'ffmpeg';

my $script_abs_path 	= abs_path($0);
my $script_dir 		= dirname($script_abs_path);
my $script_base 	= basename($script_abs_path, '.pl');

my $vice_pid;

my $cwd = cwd();

my $tmp_name = tmpnam();

## tok64 needs filename to be lowercase
my $tmp_base = catfile(dirname($tmp_name), lc(basename($tmp_name)));

my $tmp_txt = $tmp_base . '.txt';  ## BASIC program in ASCII
my $tmp_prg = $tmp_base . '.prg';  ## BASIC program PETSCII + tokenized
my $tmp_dsk = $tmp_base . '.dsk';  ## D64 image to store program
my $tmp_mp3 = $tmp_base . '.mp3';  ## MP3 file audio recording target
my $tmp_log = $tmp_base . '.log';  ## VICE log file

my $debug;		## flag to prevent temp files from being deleted
my $disk_image;		## allow using an existing disk image
my $output_mp3; 	## final output is a trimmed MP3 file of sound
my $accurate;		## use "accurate" VICE emulation ('x64sc')
my $super;		## use "superCPU" VICE emulation ('xscpu64')
my $normal;		## use "normal" VICE emulation ('x64')

GetOptions(
	'disk|d=s'	=>	\$disk_image,
	'output|o=s'	=>	\$output_mp3,
	'debug!'	=>	\$debug,
	'normal!'	=>	\$normal,
	'accurate!'	=>	\$accurate,
	'super!'	=>	\$super,
);

## C=64 emulation
if ($normal) {
	$vice_bin 	= 'x64';
}
## Accurate C=64 emulation
if ($accurate) {
	$vice_bin 	= 'x64sc';
}
## SuperCPU C=64 emulation
if ($super) {
	$vice_bin 	= 'xscpu64';
}

print STDERR "####\n";
print STDERR "##\n";
print STDERR "## C=64 Sound Effect to MP3 Converter Pipeline\n";
print STDERR "## Brett Whitty <brett\@gnomatix.com>, Jan. 2017\n";
print STDERR "##\n";

## use VICE $vice_version emulator
$vice_bin = which $vice_bin;

## provided by VICE C=64 emulator
$c1541_bin = which $c1541_bin;

## src is under script dir...
$tok64_bin = which $tok64_bin;

## used for trimming silence from the mp3 output produced by VICE
$ffmpeg_bin = which $ffmpeg_bin;

## ...look for compiled binary in bin
unless ($tok64_bin) {
	$tok64_bin = catfile($script_dir, 'bin', 'tok64');
}

my $missing_bin = 0;
if (-x $vice_bin) {
	print STDERR "## Found '".basename($vice_bin)."' binary at:\n##  $vice_bin\n";
	print STDERR "##\n";
} else {
	print STDERR "## ERROR: No '".basename($vice_bin)."' binary available found in PATH.\n";
	print STDERR "##\n";
	$missing_bin = 1;
}

if (-x $c1541_bin) {
	print STDERR "## Found 'c1541' binary at:\n##  $c1541_bin\n";
	print STDERR "##\n";
} else {
	print STDERR "## ERROR: No 'c1541' binary available found in PATH.\n";
	print STDERR "##\n";
	$missing_bin = 1;
}

if (-x $tok64_bin) {
	print STDERR "## Found 'tok64' binary at:\n##  $tok64_bin\n";
	print STDERR "##\n";
} else {
	print STDERR "## ERROR: No 'tok64' binary found in PATH.\n";
	print STDERR "##\n";
	$missing_bin = 1;
}
if (-x $ffmpeg_bin) {
	print STDERR "## Found '".basename($ffmpeg_bin)."' binary at:\n##  $ffmpeg_bin\n";
	print STDERR "##\n";
} else {
	print STDERR "## ERROR: No '".basename($ffmpeg_bin)."' binary available found in PATH.\n";
	print STDERR "##\n";
	$missing_bin = 1;
}

if ($missing_bin) {
	print STDERR "## See script source or 'README' for details on binary dependencies.\n";
	print STDERR "##\n";
	
	exit(1);
}

if ($disk_image) {
	print STDERR "## OPTIONS: disk   = '$disk_image'\n";
} else {
	$disk_image = $tmp_dsk;
	print STDERR "## DEFAULT: disk   = '$disk_image'\n";
}
if ($output_mp3) {
	$output_mp3 = abs_path($output_mp3);
	print STDERR "## OPTIONS: output = '$output_mp3'\n";
}

print STDERR "##\n";
  
my $basic = <<BASIC;
10 S=54272
20 FORL=0TO24:POKES+L,0:NEXT
30 POKES+1,130
40 POKES+5,9
50 POKES+15,30
60 POKES+24,15
70 FORL=1TO12:POKES+4,21
80 FORT=1TO1000:NEXT:POKES+4,20
90 FORT=1TO1000:NEXT:NEXT
BASIC
#70 FORL=1TO12:POKES+4,21

my $basic_too = <<BASIC_TOO;
5 S=54272
10 FORL=STOS+24:POKEL,0:NEXT
15 POKES+22,128:POKES+21,0:POKES+23,1
20 POKES+5,9:POKES+6,0
30 POKE+24,79
40 READHF,LF,DR
50 IFHF<0THENEND
60 POKES+1,HF:POKES,LF
70 POKES+4,33
80 FORT=1TODR:NEXT
90 POKES+4,32:FORT=1TO50:NEXT
100 GOTO40
110 DATA25,177,250,28,214,250
120 DATA25,177,250,25,177,250
130 DATA25,177,125,28,214,125
140 DATA32,94,750,25,177,250
150 DATA28,214,250,19,63,250
160 DATA19,63,250,19,63,250
170 DATA21,154,63,24,63,63
180 DATA25,177,250,24,63,125
190 DATA19,63,250,-1,-1,-1
BASIC_TOO

my $basic_three = <<BASIC_THREE;
10 S=54272: FORL=STOS+24: POKEL,0:NEXT
20 DIMH(2,200),L(2,200),C(2,200)
30 DIMFQ(11)
40 V(0)=17:V(1)=65:V(2)=33
50 POKES+10,8:POKES+22,128:POKES+23,244
60 FORI=0TO11:READFQ(I):NEXT
100 FORK=0TO2
110 I=0
120 READNM
130 IFNM=0THEN250
140 WA=V(K):WB=WA-1:IFNM<0THENNM=-NM:WA=0:WB=0
150 DR%=NM/128:OC%=(NM-128*DR%)/16
160 NT=NM-128*DR%-16*OC%
170 FR=FQ(NT)
180 IFOC%=7THEN200
190 FORJ=6TOOC%STEP-1:FR=FR/2:NEXT
200 HF%=FR/256:LF%=FR-256*HF%
210 IFDR%=1THENH(K,I)=HF%:L(K,I)=LF%:C(K,I)=WA:I=I+1:GOTO120
220 FORJ=1TODR%-1:H(K,I)=HF%:L(K,I)=LF%:C(K,I)=WA:I=I+1:NEXT
230 H(K,I)=HF%:L(K,I)=LF%:C(K,I)=WB
240 I=I+1:GOTO120
250 IFI>IMTHENIM=I
260 NEXT
500 POKES+5,0:POKES+6,240
510 POKES+12,85:POKES+13,133
520 POKES+19,10:POKES+20,197
530 POKES+24,31
540 FORI=0TOIM
550 POKES,L(0,I):POKES+7,L(1,I):POKES+14,L(2,I)
560 POKES+1,H(0,I):POKES+8,H(1,I):POKES+15,H(2,I)
570 POKES+4,C(0,I):POKES+11,C(1,I):POKES+18,C(2,I)
580 FORT=1TO80:NEXT:NEXT
590 FORT=1TO200:NEXT:POKES+24,0
600 DATA34334,36376,38539,40830
610 DATA43258,45830,48556,51443
620 DATA54502,57743,61176,64814
1000 DATA594,594,594,596,596
1010 DATA1618,587,592,587,585,331,336
1020 DATA1097,583,585,585,585,587,587
1030 DATA1609,585,331,337,594,594,593
1040 DATA1618,594,596,594,592,587
1050 DATA1616,587,585,331,336,841,327
1060 DATA1607
1999 DATA0
2000 DATA583,585,583,583,327,329
2010 DATA1611,583,585,578,578,578
2020 DATA196,198,583,326,578
2030 DATA326,327,329,327,329,326,578,583
2040 DATA1606,582,322,324,582,587
2050 DATA329,327,1606,583
2060 DATA327,329,587,331,329
2070 DATA329,328,1609,578,834
2080 DATA324,322,327,585,1602
2999 DATA0
3000 DATA567,566,567,304,306,308,310
3010 DATA1591,567,311,310,567
3020 DATA306,304,299,308
3030 DATA304,171,176,306,291,551,306,308
3040 DATA310,308,310,306,295,297,299,304
3050 DATA1586,562,567,310,315,311
3060 DATA308,313,297
3070 DATA1586,567,560,311,309
3080 DATA308,309,306,308
3090 DATA1577,299,295,306,310,311,304
3100 DATA562,546,1575
3999 DATA0
BASIC_THREE

## trying to make sure the string is latin1 (1 byte chars) not UTF8
$basic_three = encoder($basic_three)->latin1;

## write the basic program to a temp file
write_file($tmp_txt, ($basic_three));


## use 'tok64' to convert to CBM basic tokenized (save) file
## tok64 appends '.prg' to output file name
chdir(dirname($tmp_txt)); ## input file needs to be in cwd
my $cmd_txt_to_prg = "$tok64_bin ".basename($tmp_txt)." 1>/dev/null 2>&1";

print STDERR "## $cmd_txt_to_prg\n";
system($cmd_txt_to_prg);

print STDERR "##\n";


## create the disk image
my $cmd_format_d64 = "$c1541_bin -format sound-maker,bw d64 $tmp_dsk 1>/dev/null 2>&1";

print STDERR "## $cmd_format_d64\n";
system($cmd_format_d64);

print STDERR "##\n";

## write the program file to disk
my $cmd_prg_to_d64 = "$c1541_bin -attach $tmp_dsk -write $tmp_prg sound-maker 1>/dev/null 2>&1";

print STDERR "## $cmd_prg_to_d64\n";
system($cmd_prg_to_d64);

print STDERR "##\n";

## run the program using vice and dump mp3 to file
#my $vice_cmd = "$vice_bin -console -autostart $disk_image -sounddev mp3 -soundarg $tmp_mp3 -soundsync 2 -soundoutput 2 -soundvolume 100";


#### WORKS my $vice_cmd = "$vice_bin -console -autostart $disk_image -soundsync 2 -soundoutput 2 -soundvolume 100 -soundrate 48000 -soundbufsize 200 -soundfragsize 0 -soundrecdev mp3 -soundrecarg $tmp_mp3";

my $vice_cmd = "$vice_bin -console -autostart $disk_image -soundsync 2 -soundoutput 2 -soundvolume 100 -soundrate 44100 -soundbufsize 100 -soundfragsize 0 -soundrecdev mp3 -soundrecarg $tmp_mp3";

print STDERR "## $vice_cmd\n";

## using IPC::Open2 here to run VICE so we can easily kill it later...
$vice_pid = open2(undef, undef, $vice_cmd);

print STDERR "##\n";

## ...program is running in VICE, so used ffmpeg's silence detection
## to check the output file periodically for the sound generation to
## complete; this should look like a period of silence at the start
## of the file, some sound, then another period of silence.
my ($mp3_file_trimmed, $mp3_file_duration) = get_final_mp3($vice_pid, $tmp_mp3);

## if an output file name was specified, move/rename the trimmed 
## MP3 file from its temp file location to the location specified
if ($output_mp3) {
	move($mp3_file_trimmed, $output_mp3)
} else {
	$output_mp3 = $mp3_file_trimmed;
}

print STDERR "## MP3 file: '$output_mp3', duration: ${mp3_file_duration}s\n";
print "$output_mp3\t$mp3_file_duration\n";

  END {
	 unless ($debug) {
		unlink($tmp_txt);
		unlink($tmp_prg);
		unlink($tmp_dsk);
		unlink($tmp_mp3);
		unlink($tmp_log);
 	}
	print STDERR "####\n";

	if ($vice_pid) {
 		kill 'KILL', $vice_pid;
	}

   }


 sub get_final_mp3 {
 	my ($vice_pid, $mp3_file) = @_;

	my $mp3_file_trimmed = $mp3_file;
	$mp3_file_trimmed =~ s/\.mp3$/\.trimmed\.mp3/;

	## allow tweaking the results of silence detection
	## by padding the detected start and end positions a bit
	my $cut_start_pad = 	-0.5; 	## adjust start 0.5s earlier 
	my $cut_end_pad	  = 	 0.0;	## no padding on end

	## dB level for silence detection
	my $db_cutoff 		= -50;
	## silence duration cutoff
	my $duration_cutoff 	=   2;

	my $cmd = "sleep 5 && $ffmpeg_bin -i $mp3_file -af silencedetect=n=${db_cutoff}dB:d=${duration_cutoff} -f null - 2>&1 | grep silencedetect";

	my $cut_start;		## start of sound effect
	my $cut_end;		## end of sound effect
	my $cut_duration;	## duration of sound effect (s)
	
	print STDERR "## Program is running...";
	my $done = 0;
	do {
		my $silence_detect = `$cmd`;
		my $silent_segs = () = $silence_detect =~ /silence_start/g;
		
		print STDERR '.';

		if ($silent_segs == 2) {
			print STDERR "DONE!\n";
			print STDERR "##\n";
			
			$silence_detect =~ /silence_end: ([0-9.]+).*silence_duration: ([0-9.]+).*silence_start: ([0-9.]+)/s;
			$cut_start = $1 + $cut_start_pad; 	## pad start
			$cut_end   = $3 + $cut_end_pad;	## pad end
			$cut_duration = $cut_end - $cut_start;
			
			print STDERR "## FFMPEG silence detection:\n";
			print STDERR "##   sound_start: $cut_start\n";
			print STDERR "##   sound_end:   $cut_end\n";
			print STDERR "##   duration:    $cut_duration\n";
			print STDERR "##\n";

			my $cmd_trim = "ffmpeg -ss $cut_start -t $cut_duration -i $mp3_file -acodec copy $mp3_file_trimmed 1>/dev/null 2>&1";

			print STDERR "## $cmd_trim\n";
			system($cmd_trim);
			print STDERR "##\n";

			$done = 1;
		}
	} until ($done);

 	kill 'KILL', $vice_pid;
	print STDERR "## Sent KILL signal to PID '$vice_pid'\n";
	print STDERR "##\n";
	$vice_pid = undef;

	return ($mp3_file_trimmed, $cut_duration);
 }
