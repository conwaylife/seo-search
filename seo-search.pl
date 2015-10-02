#
# Switch engine puffer orbit search script.
# For Golly (Cellular automata application)
# By Jason Summers, 1/2012.
#
# This script searches for unknown single-engine "switch engine" puffers in
# Conway's Game of Life.
#
# Instructions:
#
# Install and configure Perl scripting support for Golly, if necessary.
#
# Put this file somewhere in Golly's "Scripts" directory.
#
# Open Golly, view the scripts (File -> Show Scripts), and select this script
# file (seo-search.pl) to start it.
#
# Let it run as long as you want. Press the Stop button or the Escape key to
# stop it.
#
# Unidentified patterns will be written to the "out" subdirectory. Most of
# them will be unidentified because of long-lived smoke that managed to slip
# though our filters. A few of them will be because a second switch engine
# spontaneously formed. Both of these results are false positives.
#
# The script will try to create the "out" subdirectory if it doesn't exist.
# If that fails, you may have to create it manually.
#
# NOTE: This script is single-threaded. If your computer has multiple CPU
# cores, then for best results, run multiple instances of Golly (one for each
# core), and leave this script running in each instance.
# For Windows users: To make sure you're using all your CPU cores, open the
# Task Manager (Ctrl+Shift+Esc) and look at the "Performance" tab.
#
# NOTE: This script probably does not do anything to prevent your computer
# from going into sleep mode, so you may need to configure your computer not
# to do that.
# For Windows users: Set your Power settings to "High Performance". In
# Windows 7, this setting can be found in Control Panel -> "Power Options".
#
# NOTE: If you're serious about this, you may want to tweak some of the
# parameters, and maybe find a way to reduce the number of false positives.
#

use strict;

# Output directory, relative to the directory containing the script.
my $output_dir = "out";

# A quantum is the number of generations we will run at a time. After each
# quantum, we'll look at the pattern to see if it's still alive, etc.
my $gens_per_quantum = 96;
# Puffer engine movement per quantum (positive is to the lower right).
my $x_movement_per_quantum = -8;
my $y_movement_per_quantum = -8;

my $max_quantums = 100;
# At two designated quantums, we'll "reset" the pattern by clearing all cells
# too far from the engine. By doing this, we hope to get rid of the mess
# created by the initial random cells, leaving only a puffer with predictable
# behavior.
my @quanta_for_reset = (16, 40, 80);

my $protect_size = 180;
my $runs_per_update = 1024; # how often to update the status line

# The size and position of the field of random cells that will perturb the
# puffer engine.
my $rnd_xpos = 0;
my $rnd_ypos = 16;
my $rnd_xsize = 23;
my $rnd_ysize = 13;

# ----------------------------------------

my $engine;
my $q; # current quantum number
my $bm_count = 0; # block-maker count
my $gm_count1 = 0; # glider-maker count (left-handed)
my $gm_count2 = 0; # glider-maker count (right-handed)
my $run_count = 0;
my $found_count = 0;
my $starttime;
my @population; # population at each quantum
my @pd; # population difference at each quantum
my $script_title = "Switch engine orbit search";

sub obs_pause {
	g_update();
	while (g_getkey() eq '') { }
}

sub obs_main_init {
	g_show("Tesing to make sure output directory ($output_dir) exists...");
	if(!(-d $output_dir)) {
		mkdir($output_dir);
	}

	g_new($script_title);
	g_save("$output_dir/test.lif", "rle");
	unlink("$output_dir/test.lif");

	g_setname($script_title);
	g_show("Running switch engine orbit search...");

	g_setmag(0);
	$engine = g_parse('bobo$o$bo2bo$3b3o!');
	$starttime = time();
}

# Pattern ran to our limit without being identified. Save it.
sub obs_found_something {
	$found_count++;
	g_update();
	g_save("$output_dir/$run_count.lif", "rle");
	g_setname($script_title);
}

sub obs_do_1_run {

	g_setgen(0);

	# Clear the whole universe, except for (0,0).
	# I don't know how to clear the whole universe at once, but the cell at
	# (0,0) will always be set, so I'll select it and clear everything else.
	#   [g_new() has side effects, like changing the magnification.]
	#   [g_select(); g_clear(1) gives an error.]
	g_select(0,0,1,1);
	g_clear(1);

	# Must be placed so that cell (0,0) is ON.
	g_putcells($engine,0,-1);

	# Place some random cells behind the engine.
	# Note that we add some jitter to the size of the random field, to try to
	# increase variety and randomness.
	g_select($rnd_xpos-3, $rnd_ypos-2,
	         $rnd_xsize-3+$run_count%7, $rnd_ysize-2+$run_count%5);
	g_randfill(34);
	g_select();
	#obs_pause();

	$q=0;
	$population[0] = 0;
	$pd[0] = 0;

	while (1) {
		$q++;
		g_run($gens_per_quantum);
		#obs_pause();

		# Look at one key cell to figure out if the engine is still alive.
		if (!g_getcell($q*$x_movement_per_quantum,$q*$y_movement_per_quantum)) {
			return; # Engine has died.
		} 

		# Record the population
		$population[$q] = 0 + g_getpop();
		$pd[$q] = $population[$q] - $population[$q-1];

		#g_show('pop: ' . $pd[$q] . ' ' . $pd[$q-1] . ' ' . $pd[$q-2]);
		#obs_pause();

		if ($q>=3) {
			# Have we fallen into a loop?
			# Look for signature population diffs for a block maker:
			if ($pd[$q]==  29 && $pd[$q-1]==   5 && $pd[$q-2]==  -2) { $bm_count++; return; }
			if ($pd[$q]==   5 && $pd[$q-1]==  -2 && $pd[$q-2]==  29) { $bm_count++; return; }
			if ($pd[$q]==  -2 && $pd[$q-1]==  29 && $pd[$q-2]==   5) { $bm_count++; return; }

			# glider-maker (left-handed)
			if ($pd[$q]==   3 && $pd[$q-1]==  25 && $pd[$q-2]==  77) { $gm_count1++; return; }
			if ($pd[$q]==  25 && $pd[$q-1]==  77 && $pd[$q-2]== -46) { $gm_count1++; return; }
			if ($pd[$q]==  77 && $pd[$q-1]== -46 && $pd[$q-2]==   3) { $gm_count1++; return; }
			if ($pd[$q]== -46 && $pd[$q-1]==   3 && $pd[$q-2]==  25) { $gm_count1++; return; }

			# glider-maker (right-handed)
			if ($pd[$q]== 106 && $pd[$q-1]==   6 && $pd[$q-2]==   1) { $gm_count2++; return; }
			if ($pd[$q]==   6 && $pd[$q-1]==   1 && $pd[$q-2]== -54) { $gm_count2++; return; }
			if ($pd[$q]==   1 && $pd[$q-1]== -54 && $pd[$q-2]== 106) { $gm_count2++; return; }
			if ($pd[$q]== -54 && $pd[$q-1]== 106 && $pd[$q-2]==   6) { $gm_count2++; return; }
		}

		if (grep { $q == $_ } @quanta_for_reset) {
			g_select(-80+$q*$x_movement_per_quantum,-80+$q*$y_movement_per_quantum,
				$protect_size,$protect_size);
			#obs_pause();
			g_clear(1); # clear everything outside selection
			g_select(); # remove selection
		}

		if ($q>=$max_quantums) { last; }
	}

	# Unidentified pattern.
	obs_found_something();
}

sub obs_update_status {

	my $secs = time() - $starttime;
	if ($secs<1) { return; }
	if ($run_count<1) { return; }

	my $gm_count = $gm_count1+$gm_count2;
	my $rps = sprintf("%.1f", $run_count/$secs);
	my $bmp = sprintf("%.1f%%", 100.0*($bm_count/$run_count));
	my $gmp = sprintf("%.1f%%", 100.0*($gm_count/$run_count));
	my $gmp1 = sprintf("%.1f%%", 100.0*($gm_count1/$run_count));
	my $gmp2 = sprintf("%.1f%%", 100.0*($gm_count2/$run_count));
	g_show("Runs:$run_count bm:$bmp gm:$gmp ($gmp1,$gmp2) runs/sec:$rps found:$found_count");
	g_update();
}

sub obs_main_loop {
	while (1) {
		obs_do_1_run();
		$run_count++;
		if (($run_count%$runs_per_update)==0) {
			obs_update_status();
		}
	}
}

obs_main_init();
obs_main_loop();
