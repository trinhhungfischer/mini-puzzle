#!/usr/bin/perl
# PROTOTYPE - NOT FOR PRODUCTION
# Generator script for the level set: writes the auto-generated levels that
# come right after the tutorials (random polyomino tiling — ports
# generateRandomPieces() from prototype.html so they match the engine's own
# randoms) and index.json (which also lists levels 1-7, the hand-authored
# tutorials — see @TUTORIALS below). Which level number gets which board
# size and colour count is now an explicit table (@GENERATED_SPEC) rather
# than a size-list + auto-ramped-colour formula — that made it easy to
# generate a smooth curve but hard to hand-tune specific ranges (e.g. "levels
# 11-17 should be 3 colours") without fighting the ramp math. Re-run after
# editing the table; never touches the tutorial files, and wipes+rewrites
# every non-tutorial level-*.json in $out_dir each run (delete stale files by
# hand first if a level's filename changes, e.g. a different colour count —
# this script only overwrites the exact filenames it's about to (re)write).
use strict;
use warnings;

# 6 colours now (red/yellow/blue/green/purple + orange) since some levels
# below ask for a 6-colour tier. Only this script's own palette grew — the
# game/editor's shared DEFAULT_COLORS were deliberately left at 5 so their
# unrelated random-generation paths (gameplay's fallback pack, editor's
# "Ngẫu nhiên") don't change behaviour; every generated level file carries
# its own full "colors" array anyway, so this is enough on its own.
my @DEFAULT_COLORS = ("#ff6b6b", "#ffd93d", "#4f8cff", "#35c98f", "#c084fc", "#ffa94d");
my $MIN_PIECE_SIZE = 1;
my $MAX_PIECE_SIZE = 4;

# One row per generated level (numbers continue right after the tutorials,
# so row 1 here is level 8). `colors` is however many of @DEFAULT_COLORS
# (in order) that level uses.
my @GENERATED_SPEC = (
    # levels 8-10: unchanged (2 colours, 4x4)
    { w => 4, h => 4, colors => 2 }, { w => 4, h => 4, colors => 2 }, { w => 4, h => 4, colors => 2 },
    # levels 11-17: 3 colours (11-12 still 4x4, 13-17 5x5 per the existing size table)
    { w => 4, h => 4, colors => 3 }, { w => 4, h => 4, colors => 3 },
    { w => 5, h => 5, colors => 3 }, { w => 5, h => 5, colors => 3 }, { w => 5, h => 5, colors => 3 },
    { w => 5, h => 5, colors => 3 }, { w => 5, h => 5, colors => 3 },
    # levels 18-27: 4 colours (18-20 5x5, 21-27 6x6)
    { w => 5, h => 5, colors => 4 }, { w => 5, h => 5, colors => 4 }, { w => 5, h => 5, colors => 4 },
    { w => 6, h => 6, colors => 4 }, { w => 6, h => 6, colors => 4 }, { w => 6, h => 6, colors => 4 },
    { w => 6, h => 6, colors => 4 }, { w => 6, h => 6, colors => 4 }, { w => 6, h => 6, colors => 4 },
    { w => 6, h => 6, colors => 4 },
    # levels 28-38: 5 colours (28 6x6, 29-36 7x7, 37-38 8x8)
    { w => 6, h => 6, colors => 5 },
    { w => 7, h => 7, colors => 5 }, { w => 7, h => 7, colors => 5 }, { w => 7, h => 7, colors => 5 },
    { w => 7, h => 7, colors => 5 }, { w => 7, h => 7, colors => 5 }, { w => 7, h => 7, colors => 5 },
    { w => 7, h => 7, colors => 5 }, { w => 7, h => 7, colors => 5 },
    { w => 8, h => 8, colors => 5 }, { w => 8, h => 8, colors => 5 },
    # level 39: unchanged (5 colours, 8x8 — not part of any requested range)
    { w => 8, h => 8, colors => 5 },
    # levels 40-44: 6 colours (8x8)
    { w => 8, h => 8, colors => 6 }, { w => 8, h => 8, colors => 6 }, { w => 8, h => 8, colors => 6 },
    { w => 8, h => 8, colors => 6 }, { w => 8, h => 8, colors => 6 },
);

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

# Levels that must stay byte-for-byte identical because they weren't part of
# the requested regeneration range (their size/colour count is unchanged, but
# regenerating would still reshuffle their exact piece layout, which nobody
# asked for). Read back the existing file's own fields instead of writing a
# new one, so the manifest matches what's actually still on disk.
my %PRESERVE_LEVELS = map { $_ => 1 } (8, 9, 10, 39);

sub read_existing_manifest_entry {
    my ($path) = @_;
    open(my $fh, '<', $path) or die "Cannot read existing $path: $!";
    local $/;
    my $text = <$fh>;
    close($fh);
    my ($file) = $path =~ m{([^/\\]+)$};
    my ($name) = $text =~ /"name":\s*"([^"]+)"/;
    my ($w) = $text =~ /"gridWidth":\s*(\d+)/;
    my ($h) = $text =~ /"gridHeight":\s*(\d+)/;
    my ($max_moves) = $text =~ /"maxMoves":\s*(\d+)/;
    my ($colors_block) = $text =~ /"colors":\s*\[(.*?)\]/s;
    my @color_count = ($colors_block =~ /#[0-9a-fA-F]{6}/g);
    my ($piece_map_block) = $text =~ /"pieceMap":\s*\[([^\]]*)\]/;
    my @ids = split(/,/, $piece_map_block);
    my $pieces = 0;
    for my $id (@ids) { $pieces = $id + 1 if $id + 1 > $pieces; }
    return {
        file => $file, name => $name, w => $w, h => $h,
        colors => scalar(@color_count), maxMoves => $max_moves, pieces => $pieces
    };
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

for (my $i = 0; $i < @GENERATED_SPEC; $i++) {
    my $spec = $GENERATED_SPEC[$i];
    my ($size_w, $size_h, $color_count) = ($spec->{w}, $spec->{h}, $spec->{colors});
    my $level_num = $i + 1 + $NUMBER_OFFSET; # 1-based for filenames/names, after the tutorials

    if ($PRESERVE_LEVELS{$level_num}) {
        my ($existing) = glob("$out_dir/level-" . sprintf("%02d", $level_num) . "_*.json");
        push @manifest, read_existing_manifest_entry($existing);
        next;
    }

    my @colors = @DEFAULT_COLORS[0 .. $color_count - 1];

    my ($next_id, $piece_id_ref) = generate_pieces($size_w, $size_h);
    my @piece_colors = assign_colors($piece_id_ref, $next_id, $size_w, $size_h, $color_count);
    my $max_moves = int(($size_w * $size_h) / $color_count + 0.5) + $color_count;

    my $fname = sprintf("level-%02d_%dx%d_c%d.json", $level_num, $size_w, $size_h, $color_count);
    my $name = sprintf("Level %02d (%dx%d, %d mau)", $level_num, $size_w, $size_h, $color_count);
    write_level("$out_dir/$fname", $name, $size_w, $size_h, $max_moves, \@colors, $piece_id_ref, \@piece_colors);

    push @manifest, {
        file => $fname, name => $name, w => $size_w, h => $size_h,
        colors => $color_count, maxMoves => $max_moves, pieces => $next_id
    };
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
