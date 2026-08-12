#!/usr/bin/perl
# PROTOTYPE - NOT FOR PRODUCTION
# One-off generator script for the 50-level starter set. Ports the exact
# polyomino-tiling algorithm from prototype.html's generateRandomPieces() so
# generated levels match the engine's own random levels. Not wired into the
# game at runtime — run manually, then delete or keep for regenerating.
use strict;
use warnings;

my @DEFAULT_COLORS = ("#ff6b6b", "#ffd93d", "#4f8cff", "#35c98f", "#c084fc");
my $MIN_PIECE_SIZE = 1;
my $MAX_PIECE_SIZE = 4;

my @SIZES  = (3, 4, 5, 6, 7, 8);
my @COUNTS = (9, 9, 8, 8, 8, 8); # sums to 50

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

my $out_dir = $ARGV[0] // '.';
my @manifest;
my $global_index = 0; # 0-based, drives the color-count ramp across all 50 levels

for (my $s = 0; $s < @SIZES; $s++) {
    my $size = $SIZES[$s];
    my $count = $COUNTS[$s];
    for (my $k = 0; $k < $count; $k++) {
        my $level_num = $global_index + 1; # 1-based for filenames/names
        my $color_count = 2 + int($global_index / 13);
        $color_count = 5 if $color_count > 5;
        my @colors = @DEFAULT_COLORS[0 .. $color_count - 1];

        my ($next_id, $piece_id_ref) = generate_pieces($size, $size);
        my @piece_colors;
        for (my $p = 0; $p < $next_id; $p++) {
            push @piece_colors, int(rand($color_count));
        }
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
