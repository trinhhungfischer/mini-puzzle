#!/usr/bin/perl
# PROTOTYPE - NOT FOR PRODUCTION
# Generator script for the level set: writes the auto-generated levels that
# come right after the tutorials (random polyomino tiling — ports
# generateRandomPieces() from prototype.html so they match the engine's own
# randoms) and index.json (which also lists levels 1-7, the hand-authored
# tutorials — see @TUTORIALS below). Numbering and count follow @SIZES/
# @COUNTS below. Re-run after changing them; never touches the tutorial
# files, and wipes+rewrites every non-tutorial level-*.json in $out_dir each
# run (delete stale files by hand first if you shrink @COUNTS — this script
# only overwrites the numbers it's about to (re)write, it doesn't know which
# old numbers should no longer exist).
use strict;
use warnings;

my @DEFAULT_COLORS = ("#ff6b6b", "#ffd93d", "#4f8cff", "#35c98f", "#c084fc");
my $MIN_PIECE_SIZE = 1;
my $MAX_PIECE_SIZE = 4;

my @SIZES  = (4, 5, 6, 7, 8);
my @COUNTS = (5, 8, 8, 8, 8); # sums to 37 — 3x3 dropped entirely and 4x4 cut
                              # from 9 to 5 (removed what used to be levels
                              # 8-20 in the old 1-7-tutorial + 50-generated
                              # numbering: all nine 3x3s plus the first four
                              # 4x4s)

sub neighbors_of {
    my ($i, $w, $h) = @_;
    my $x = $i % $w;
    my $y = int($i / $w);
    my @list;
    push @list, $i - 1 if $x > 0;
    push @list, $i + 1 if $x < $w - 1;
    push @list, $i - $w if $y > 0;
    push @list, $i + $w if $y < $h - 1;
    return @list;
}

# Random-growth polyomino tiling: identical logic to generateRandomPieces()
# in prototype.html. Returns (next_id, \@piece_id).
sub generate_pieces {
    my ($w, $h) = @_;
    my $total = $w * $h;
    my @piece_id = (-1) x $total;
    my $next_id = 0;

    for (my $start = 0; $start < $total; $start++) {
        next if $piece_id[$start] != -1;
        my $id = $next_id++;
        $piece_id[$start] = $id;
        my $target_size = $MIN_PIECE_SIZE + int(rand($MAX_PIECE_SIZE - $MIN_PIECE_SIZE + 1));
        my @frontier = grep { $piece_id[$_] == -1 } neighbors_of($start, $w, $h);
        my $size = 1;
        while ($size < $target_size && @frontier) {
            my $pos = int(rand(scalar @frontier));
            my $pick = splice(@frontier, $pos, 1);
            next if $piece_id[$pick] != -1;
            $piece_id[$pick] = $id;
            $size++;
            for my $n (neighbors_of($pick, $w, $h)) {
                if ($piece_id[$n] == -1 && !(grep { $_ == $n } @frontier)) {
                    push @frontier, $n;
                }
            }
        }
    }
    return ($next_id, \@piece_id);
}

# Greedy graph colouring so no two touching pieces share a colour (mirrors
# editor.html's randomizeGrid() fix) — otherwise two adjacent same-colour
# pieces look like one accidental bigger piece instead of two.
sub assign_colors {
    my ($piece_id_ref, $next_id, $w, $h, $color_count) = @_;
    my @adj = map { {} } (0 .. $next_id - 1);
    my $total = $w * $h;
    for (my $i = 0; $i < $total; $i++) {
        for my $n (neighbors_of($i, $w, $h)) {
            if ($piece_id_ref->[$n] != $piece_id_ref->[$i]) {
                $adj[$piece_id_ref->[$i]]{$piece_id_ref->[$n]} = 1;
                $adj[$piece_id_ref->[$n]]{$piece_id_ref->[$i]} = 1;
            }
        }
    }
    my @color_of;
    for (my $p = 0; $p < $next_id; $p++) {
        my %used;
        for my $nb (keys %{$adj[$p]}) {
            $used{$color_of[$nb]} = 1 if defined $color_of[$nb];
        }
        my @available = grep { !$used{$_} } (0 .. $color_count - 1);
        if (@available) {
            $color_of[$p] = $available[int(rand(scalar @available))];
        } else {
            # Only possible when a piece has more distinct-colour neighbours
            # than the palette has colours — an unavoidable rare clash.
            $color_of[$p] = int(rand($color_count));
        }
    }
    return @color_of;
}

sub write_level {
    my ($path, $name, $w, $h, $max_moves, $colors_ref, $piece_map_ref, $piece_colors_ref) = @_;
    my $colors_json = join(",\n    ", map { "\"$_\"" } @$colors_ref);
    my $piece_map_json = join(",", @$piece_map_ref);
    my $piece_colors_json = join(",", @$piece_colors_ref);
    open(my $fh, '>', $path) or die "Cannot write $path: $!";
    print $fh <<"JSON";
{
  "name": "$name",
  "gridWidth": $w,
  "gridHeight": $h,
  "maxMoves": $max_moves,
  "startIndex": 0,
  "colors": [
    $colors_json
  ],
  "pieceMap": [$piece_map_json],
  "pieceColors": [$piece_colors_json]
}
JSON
    close($fh);
}

# Levels 1-7 are hand-authored tutorial levels (built in editor.html, not by
# this script) — level-01_2x2_c3.json .. level-07_5x5_c5.json already live
# in this directory and are never touched here. This table only exists so
# their manifest entries can be written alongside the auto-generated ones;
# edit it if a tutorial file's name/size/moves/piece count ever changes.
my @TUTORIALS = (
    { file => "level-01_2x2_c3.json", name => "Tutorial 01 (2x2, 3 mau)", w => 2, h => 2, colors => 3, maxMoves => 3, pieces => 3 },
    { file => "level-02_3x3_c5.json", name => "Tutorial 02 (3x3, 5 mau)", w => 3, h => 3, colors => 5, maxMoves => 4, pieces => 7 },
    { file => "level-03_3x5_c5.json", name => "Tutorial 03 (3x5, 5 mau)", w => 3, h => 5, colors => 5, maxMoves => 5, pieces => 7 },
    { file => "level-04_3x5_c4.json", name => "Tutorial 04 (3x5, 4 mau)", w => 3, h => 5, colors => 4, maxMoves => 5, pieces => 8 },
    { file => "level-05_3x5_c3.json", name => "Tutorial 05 (3x5, 3 mau)", w => 3, h => 5, colors => 3, maxMoves => 4, pieces => 6 },
    { file => "level-06_5x5_c5.json", name => "Tutorial 06 (5x5, 5 mau)", w => 5, h => 5, colors => 5, maxMoves => 5, pieces => 11 },
    { file => "level-07_5x5_c5.json", name => "Tutorial 07 (5x5, 5 mau)", w => 5, h => 5, colors => 5, maxMoves => 6, pieces => 14 },
);
my $NUMBER_OFFSET = scalar @TUTORIALS; # auto-generated levels start right after the tutorials

my $out_dir = $ARGV[0] // '.';
my @manifest = @TUTORIALS;
my $global_index = 0; # 0-based, drives the color-count ramp across all auto-generated levels

my $TOTAL_GENERATED = 0;
$TOTAL_GENERATED += $_ for @COUNTS;
# Ceil-divide the generated levels into 4 tiers (2/3/4/5 colours) so the ramp
# always reaches 5 colours by the last level regardless of how many levels
# there are in total — a fixed divisor (e.g. "13 levels per tier", sized for
# the original 50) would silently cap out below 5 colours once the set gets
# smaller than 4x that divisor.
my $TIER_SIZE = int(($TOTAL_GENERATED + 3) / 4);

for (my $s = 0; $s < @SIZES; $s++) {
    my $size = $SIZES[$s];
    my $count = $COUNTS[$s];
    for (my $k = 0; $k < $count; $k++) {
        my $level_num = $global_index + 1 + $NUMBER_OFFSET; # 1-based for filenames/names, after the tutorials
        my $color_count = 2 + int($global_index / $TIER_SIZE);
        $color_count = 5 if $color_count > 5;
        my @colors = @DEFAULT_COLORS[0 .. $color_count - 1];

        my ($next_id, $piece_id_ref) = generate_pieces($size, $size);
        my @piece_colors = assign_colors($piece_id_ref, $next_id, $size, $size, $color_count);
        my $max_moves = int(($size * $size) / $color_count + 0.5) + $color_count;

        my $fname = sprintf("level-%02d_%dx%d_c%d.json", $level_num, $size, $size, $color_count);
        my $name = sprintf("Level %02d (%dx%d, %d mau)", $level_num, $size, $size, $color_count);
        write_level("$out_dir/$fname", $name, $size, $size, $max_moves, \@colors, $piece_id_ref, \@piece_colors);

        push @manifest, {
            file => $fname, name => $name, w => $size, h => $size,
            colors => $color_count, maxMoves => $max_moves, pieces => $next_id
        };
        $global_index++;
    }
}

# Manifest for quick reference / potential future wiring into gameplay.
open(my $mf, '>', "$out_dir/index.json") or die "Cannot write index.json: $!";
print $mf "[\n";
for (my $i = 0; $i < @manifest; $i++) {
    my $m = $manifest[$i];
    my $comma = ($i < @manifest - 1) ? "," : "";
    print $mf sprintf(
        "  { \"file\": \"%s\", \"name\": \"%s\", \"gridWidth\": %d, \"gridHeight\": %d, \"colors\": %d, \"maxMoves\": %d, \"pieceCount\": %d }%s\n",
        $m->{file}, $m->{name}, $m->{w}, $m->{h}, $m->{colors}, $m->{maxMoves}, $m->{pieces}, $comma
    );
}
print $mf "]\n";
close($mf);

print "Generated " . scalar(@manifest) . " levels into $out_dir\n";
