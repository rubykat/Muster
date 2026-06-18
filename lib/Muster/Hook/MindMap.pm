package Muster::Hook::MindMap;

=head1 NAME

Muster::Hook::MindMap - Muster hook for mind maps

=head1 SYNOPSIS

  # CamelCase plugin name
  package Muster::Hook::MindMap;
  use Mojo::Base 'Muster::Hook';

=head1 DESCRIPTION

L<Muster::Hook::MindMap> does mind maps:
transforming a tagged unordered list into a connected graph.
Base mind-maps on lists, cross-linked.
Depends on GraphViz plugin to display the maps as maps.

The pattern for mind maps is "* mindmap"

=cut

use Mojo::Base 'Muster::Hook';
use Muster::Hooks;
use Muster::LeafFile;
use YAML::Any;

our $DEBUG = '';

=head1 METHODS

=head2 register

Initialize, and register hooks.

=cut
sub register {
    my $self = shift;
    my $hookmaster = shift;
    my $conf = shift;

    # we need to be able to look things up in the database
    $self->{metadb} = $hookmaster->{metadb};

    $hookmaster->add_hook('mindmap' => sub {
            my %args = @_;

            return $self->process(%args);
        },
    );
    return $self;
} # register

=head2 process

Process (modify) a leaf object.
In scanning phase, this will do nothing.
In assembly phase, this will detect matching lists,
and create a graphviz directive (to later be processed by the graphviz plugin).

  my $new_leaf = $self->process(%args);

=cut
sub process {
    my $self = shift;
    my %args = @_;

    my $leaf = $args{leaf};
    my $phase = $args{phase};

    if ($phase ne $Muster::Hooks::PHASE_BUILD)
    {
        return $leaf;
    }

    my $content = $leaf->cooked();

    # Look for a "mindmap" list, and create a graphviz directive for it.
    $content =~ s/\n[*]\s*mindmap\s*\((.*?)\)\n(.*?)\n\n/$self->create_mindmap($leaf,$2,$1)/sieg;
    $content =~ s/\n[*]\s*mindmap\n(.*?)\n\n/$self->create_mindmap($leaf,$1)/sieg;

    $leaf->{cooked} = $content;
    return $leaf;
} # process

sub build_map_levels ($%);

=head2 create_mindmap

Create a mindmap from the given list

=cut
sub create_mindmap ($$$;$) {
    my $self = shift;
    my $leaf = shift;
    my $list_str = shift;

    # Optional parameters
    my $params = (@_ ? shift : '');
    my %params;
    while ($params =~ m{
        (?:([-.\w]+)=)?		# 1: named parameter key?
        (?:
         """(.*?)"""	# 2: triple-quoted value
         |
         "([^"]*?)"	# 3: single-quoted value
         |
         '''(.*?)'''     # 4: triple-single-quote
         |
         <<([a-zA-Z]+)\n # 5: heredoc start
         (.*?)\n\5	# 6: heredoc value
         |
         (\S+)		# 7: unquoted value
        )
            (?:\s+|$)		# delimiter to next param
    }msgx) {
        my $key=$1;
        my $val;
        if (defined $2) {
            $val=$2;
            $val=~s/\r\n/\n/mg;
            $val=~s/^\n+//g;
            $val=~s/\n+$//g;
        }
        elsif (defined $3) {
            $val=$3;
        }
        elsif (defined $4) {
            $val=$4;
        }
        elsif (defined $7) {
            $val=$7;
        }
        elsif (defined $6) {
            $val=$6;
        }

        if (defined $key) {
            $params{$key} = $val;
        }
        else {
            $params{$val} = '';
        }
    }

    my $prog = (exists $params{'prog'} ? $params{'prog'} : 'dot');
    $params{top} = 'Mindmap' if !defined $params{top};
    $params{legend} = 'Map Legend' if !defined $params{legend};

    my $map =<<EOT;
[[!graph
prog=$prog
src="""
rankdir=LR;
node [ fontsize = 10 ];
edge [ color = grey30 ];
EOT
    my @lines       = split(/^/, $list_str);
    my %terms = ();
    my %xref = ();
    my %inverted = ();
    my @ret = $self->parse_lines(lines=>\@lines,
        terms=>\%terms,
        xref=>\%xref,
        inverted=>\%inverted,
        prev_indent=>0,
        parent=>'');
    my %legend = $self->extract_legend(%params, list=>\@ret, terms=>\%terms);
    $self->apply_legend(terms=>\%terms, legend=>\%legend, inverted=>\%inverted);
    my %derived = $self->derive_xrefs(terms=>\%terms, inverted=>\%inverted);
    $map .= $self->start_map(terms=>\%terms);
    $map .= $self->build_map_levels(%params, list=>\@ret, level=>0);
    $map .= $self->build_xrefs(xref=>\%xref, edge_color=>'blue3');
    $map .= $self->build_xrefs(xref=>\%derived, edge_colour=>'green3');

    $map .=<<EOT;
"""]]
EOT

    my $out = "\n\n" . $list_str . "\n\n" . $map . "\n\n";
    if ($DEBUG)
    {
        my $dump1 = Dump(\@ret);
        my $dump2 = Dump(\%legend);
        $out .= "<pre>\\$map\n\n$dump1\n\n$dump2</pre>\n\n";
    }
    return $out;
} # create_mindmap

=head2 parse_lines

Parse the lines of a list, including recursing down the levels.

=cut
sub parse_lines ($%) {
    my $self = shift;
    my %args = @_;

    my $lines_ref = $args{lines};
    my $terms_ref = $args{terms};
    my $xref_ref = $args{xref};
    my $inverted_ref = $args{inverted};
    my $prev_indent = $args{prev_indent};
    my $parent = $args{parent};

    if (@{$lines_ref})
    {
        my @siblings = ();
        my $this_indent = 0;
        my $next_line = undef;
        my $next_indent = -1;

        my $this_line = (@{$lines_ref} ? $lines_ref->[0] : undef);
        my ($ws) = $this_line =~ /^( *)[^ ]/;
        $this_indent = length($ws);

        if ($this_indent < $prev_indent)
        {
            # higher-level list
            return ();
        }

        do {
            $this_line = shift @{$lines_ref};
 
            # Labels are going to be in double-quotes, so replace all double-quotes with single quotes
            $this_line =~ tr{"}{'};

            my ($term, $rest_of_line, $number) = $self->listprefix($this_line);
            while ($rest_of_line =~ /\(See ([-\s\w]+)\)/)
            {
                my $xref = $1;
                $rest_of_line =~ s/\s*\(See [-\s\w]+\)\s*//;
                if (!$xref_ref->{$term})
                {
                    $xref_ref->{$term} = {};
                }
                if (!defined $xref_ref->{$term}->{$xref})
                {
                    $xref_ref->{$term}->{$xref} = 0;
                }
                $xref_ref->{$term}->{$xref}++;
            }
            while ($rest_of_line =~ /\(Ref ([-\s\w]+)\)/)
            {
                my $xref = $1;
                $rest_of_line =~ s/\s*\(Ref [-\s\w]+\)\s*//;
                if (!$xref_ref->{$xref})
                {
                    $xref_ref->{$xref} = {};
                }
                if (!defined $xref_ref->{$xref}->{$term})
                {
                    $xref_ref->{$xref}->{$term} = 0;
                }
                $xref_ref->{$xref}->{$term}++;
            }
            push @siblings, {term => $term,
                line => $rest_of_line,
                parent => $parent,
                number => $number};
            $terms_ref->{$term} = {
                line=>$rest_of_line,
            };
            $inverted_ref->{$term} = $parent;

            # count the number of leading spaces
            my ($ws) = $this_line =~ /^( *)[^ ]/;
            $this_indent = length($ws);

            $next_line = (@{$lines_ref} ? $lines_ref->[0] : undef);
            if ($next_line)
            {
                ($ws) = $next_line =~ /^( *)[^ ]/;
                $next_indent = length($ws);
            }
        } until (!$next_line
                 or $next_indent != $this_indent);

        # okay, no more siblings
        # next line must be (a) parent, (b) child, (c) empty

        if ($next_indent > $this_indent)
        {
            # next item is a child
            my @children = $self->parse_lines(lines=>$lines_ref,
                terms=>$terms_ref,
                xref=>$xref_ref,
                inverted=>$inverted_ref,
                prev_indent=>$this_indent,
                parent=>$siblings[$#siblings]->{term});
            $siblings[$#siblings]->{children} = \@children;
            return (@siblings, $self->parse_lines(lines=>$lines_ref,
                    terms=>$terms_ref,
                    xref=>$xref_ref,
                    inverted=>$inverted_ref,
                    prev_indent=>$this_indent,
                    parent=>$parent));
        }
        else
        {
            # coming to the end of a sub-list
            return @siblings;
        }
    }
    return ();
} # parse_lines

=head2 listprefix

Process one line, doing list-prefix stuff?

=cut
sub listprefix ($$) {
    my $self = shift;
    my $line = shift;

    my ($number, $term);
    my $rest_of_line = $line;
    my $fg = '';
    my $bg = '';

    my $bullets         = '*';
    my $bullets_ordered = '';
    my $number_match    = '(\d+|[^\W\d])';
    if ($bullets_ordered)
    {
        $number_match = '(\d+|[[:alpha:]]|[' . "${bullets_ordered}])";
    }
    return ('', $rest_of_line, 0)
      if ( !($line =~ /^\s*[${bullets}]\s+\S/)
        && !($line =~ /^\s*${number_match}[\.\)\]:]\s+\S/));

    if ($line =~ /^\s*${number_match}[\.\)\]:]\s+(\S.*)/)
    {
        $number = $1;
        $rest_of_line = $2;
    }
    $number = 0 unless defined($number);
    if (   $bullets_ordered
        && $number =~ /[${bullets_ordered}]/)
    {
        $number = 1;
    }

    if (!$number)
    {
        if ($line =~ /^(\s*[${bullets}].)\s*(.*)/)
        {
            $rest_of_line = $2;
        }
    }
    my $term_match = '(\w\w+)';
    if (!$term)
    {
        ($term)   = $rest_of_line =~ /^\s*${term_match}:/;
        $rest_of_line =~ s/^\s*${term_match}:\s*//;
    }

    if (!$term)
    {
        $term = $rest_of_line;
    }
    ($term, $rest_of_line, $number, $fg, $bg);
} # listprefix

=head2 derive_xrefs

Search for references to existing terms inside other nodes

=cut
sub derive_xrefs ($%) {
    my $self = shift;
    my %args = @_;

    my $terms_ref = $args{terms};
    my $inverted_ref = $args{inverted};

    my %derived = ();

    # search for references to existing terms
    # inside other nodes
    # but don't link a child to a parent
    foreach my $term (sort keys %{$terms_ref})
    {
        foreach my $term2 (sort keys %{$terms_ref})
        {
            if ($term2 ne $term)
            {
                my $line = $terms_ref->{$term2}->{line};
                if ($line =~ /\b$term\b/i)
                {
                    if ($inverted_ref->{$term2} ne $term)
                    {
                        if (!$derived{$term2})
                        {
                            $derived{$term2} = {};
                        }
                        if (!defined $derived{$term2}->{$term})
                        {
                            $derived{$term2}->{$term} = 0;
                        }
                        $derived{$term2}->{$term}++;
                    }
                }
            }
        }
    }

    return %derived;
} # derive_xrefs

=head2 extract_legend

Extract the legend information.

=cut
sub extract_legend ($%) {
    my $self = shift;
    my %args = @_;

    my $list_ref = $args{list};
    my $terms_ref = $args{terms};

    # If there is a top-level item which is a map-legend
    # it will tell us what colours to put for matching nodes

    my %legend = ();
    my $legend = $args{legend};
    my $found = 0;
    for (my $i = 0; !$found and $i < @{$list_ref}; $i++)
    {
        my $item = $list_ref->[$i];
        my $term = $item->{term};
        my $line = $item->{line};
        if ($term eq $legend) # this is the legend
        {
            $found = 1;
            # The children of the legend contain terms and colours
            if ($item->{children})
            {
                for (my $j = 0; $j < @{$item->{children}}; $j++)
                {
                    my $child = $item->{children}->[$j];
                    my $ch_term = $child->{term};
                    my $ch_line = $child->{line};
                    my $fg = '';
                    my $bg = '';

                    if ($ch_line =~ /\b(\w\w+)\/(\w\w+)\b/)
                    {
                        $fg = $1;
                        $bg = $2;
                    }
                    elsif ($ch_line =~ /\b(\w\w+)\b/)
                    {
                        $fg = $1;
                    }
                    $legend{$ch_term} = {
                        fg => $fg,
                        bg => $bg
                    };
                    delete $terms_ref->{$ch_term};
                }
                # now we need to remove the legend from the map
                delete $list_ref->[$i];
            }
        }
    }
    return %legend;
} # extract_legend

=head2 apply_legend

Apply the legend information.

=cut
sub apply_legend ($%) {
    my $self = shift;
    my %args = @_;

    my $terms_ref = $args{terms};
    my $legend_ref = $args{legend};
    my $inverted_ref = $args{inverted};

    # search for references to Legend terms
    # inside other nodes
    # and add the appropriate colours
    foreach my $lterm (sort keys %{$legend_ref})
    {
        foreach my $term (sort keys %{$terms_ref})
        {
            my $line = $terms_ref->{$term}->{line};
            if (($line =~ /\b${lterm}s?\b/i)
                or ($term =~ /^${lterm}s?$/i)
                )
            {
                $terms_ref->{$term}->{fg} = $legend_ref->{$lterm}->{fg};
                $terms_ref->{$term}->{bg} = $legend_ref->{$lterm}->{bg};
            }
        }
    }

    # make terms have the colours of their parent
    # if they don't already have a colour
    foreach my $term (sort keys %{$terms_ref})
    {
        my $iterm = $inverted_ref->{$term};
        if ($iterm and $term and !$terms_ref->{$term}->{fg})
        {
            if ($terms_ref->{$iterm}->{fg})
            {
                $terms_ref->{$term}->{fg} = $terms_ref->{$iterm}->{fg};
            }
            if ($terms_ref->{$iterm}->{bg})
            {
                $terms_ref->{$term}->{bg} = $terms_ref->{$iterm}->{bg};
            }
        }
    }

} # apply_legend

=head2 start_map

Start the map.

=cut
sub start_map ($%) {
    my $self = shift;
    my %args = @_;

    my $terms_ref = $args{terms};

    my $map = '';
    # first do all the terms + labels
    local $Text::Wrap::columns = 20;
    foreach my $term (sort keys %{$terms_ref})
    {
        my $fg = $terms_ref->{$term}->{fg};
        my $bg = $terms_ref->{$term}->{bg};
        my @nodeargs = ();
        push @nodeargs, "fontcolor = $fg" if $fg;
        push @nodeargs, "fillcolor = $bg, style = filled" if $bg;
        my $line = $terms_ref->{$term}->{line};
        if ($term ne $line)
        {
            my $label = wrap('', '', $line);
            $label =~ s/\n/\\n/sg; # replace newlines with newline escapes
            push @nodeargs, 'label="' . $label . '"';
        }
        if (@nodeargs > 0)
        {
            $map .= '"' . $term . '" [ ' . join(',', @nodeargs) . " ];\n";
        }
    }
    return $map;
} # start_map

=head2 build_xrefs

Build the xrefs.

=cut
sub build_xrefs ($%) {
    my $self = shift;
    my %args = @_;

    my $xref_ref = $args{xref};
    my $xref_edge_colour = $args{edge_colour};

    my $map = '';
    # do the cross-references
    foreach my $term (sort keys %{$xref_ref})
    {
        foreach my $xref (sort keys %{$xref_ref->{$term}})
        {
            $map .= '"' . $term . '" -> "' . $xref . '"' . " [ color=$xref_edge_colour ];\n";
        }
    }
    return $map;
} # build_xrefs

=head2 build_map_levels

Build the map levels.

=cut
sub build_map_levels ($%) {
    my $self = shift;
    my %args = @_;

    my $list_ref = $args{list};
    my $level = $args{level};

    my $map = '';

    my $ordered_colour = 'red3';
    my $top = $args{top};
    for (my $i = 0; $i < @{$list_ref}; $i++)
    {
        my $item = $list_ref->[$i];
        my $term = $item->{term};
        my $line = $item->{line};

        next if !$term;

        if ($level == 0)
        {
            if ($top)
            {
                $map .= '"' . $top . '"' . " [ fontsize = 14 ];\n";
            }
            $map .= '"' . $term . '"' . " [ fontsize = 12 ];\n";
            if ($top)
            {
                $map .= '"' . $top . '" -> "' . $term . '"' . ";\n";
            }
        }
        # do child-items
        if ($item->{children})
        {
            # Link to the children
            # If the children are an ordered list,
            # link to the first and link them to each other
            my $firstchild = $item->{children}->[0];
            if ($firstchild->{number})
            {
                $map .= '"' . $term . '" -> "' . $firstchild->{term} . '"' . ";\n";
            }
            for (my $j = 0; $j < @{$item->{children}}; $j++)
            {
                my $child = $item->{children}->[$j];
                if ($firstchild->{number})
                {
                    $map .= '"' . $child->{term} . '"' . " [ shape = box ];\n";
                    if ($j + 1 < @{$item->{children}})
                    {
                        $map .= '"' . $child->{term} . '" -> "' . $item->{children}->[$j+1]->{term} . '"' . " [ color = $ordered_colour ];\n";
                    }
                }
                else
                {
                    $map .= '"' . $term . '" -> "' . $child->{term} . '"' . ";\n";
                }
            }
            $map .= build_map_levels(%args, list=>$item->{children}, level=>$level + 1);
        }
    }

    return $map;
} # build_map_levels

1;
