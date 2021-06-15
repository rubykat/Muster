package Muster::Hook::DeriveFields;

=head1 NAME

Muster::Hook::DeriveFields - Muster hook for field derivation

=head1 DESCRIPTION

L<Muster::Hook::DeriveFields> does field derivation;
that is, derives field values from other fields
(aka the meta-data for the Leaf).

This just does a bunch of specific calculations;
I haven't figured out a good way of defining derivations in a config file.

=cut

use Mojo::Base 'Muster::Hook';
use Muster::Hooks;
use Muster::LeafFile;
use Lingua::EN::Inflexion;
use DateTime;
use POSIX qw(strftime);
use YAML::Any;
use Carp;

=head1 METHODS

=head2 register

Initialize, and register hooks.

=cut
sub register {
    my $self = shift;
    my $hookmaster = shift;
    my $conf = shift;

    $self->{config} = $conf->{hook_conf}->{'Muster::Hook::DeriveFields'};

    $hookmaster->add_hook('derivefields' => sub {
            my %args = @_;

            return $self->process(%args);
        },
    );
    return $self;
} # register

=head2 process

Process (scan or modify) a leaf object.
This only does stuff in the scan phase.
This expects the leaf meta-data to be populated.

  my $new_leaf = $self->process(%args);

=cut
sub process {
    my $self = shift;
    my %args = @_;

    my $leaf = $args{leaf};
    my $phase = $args{phase};

    # only does derivations in scan phase
    if ($phase ne $Muster::Hooks::PHASE_SCAN)
    {
        return $leaf;
    }

    my $meta = $leaf->meta;

    # -----------------------------------------
    # Do derivations
    # -----------------------------------------

    # split the page-name on '-'
    # useful for project-types
    my @bits = split('-', $leaf->bald_name);
    for (my $i=0; $i < scalar @bits; $i++)
    {
        my $p1 = sprintf('p%d', $i + 1); # page-bits start from 1 not 0
        $meta->{$p1} = $bits[$i];
    }

    # sections being the parts of the full page name
    @bits = split(/\//, $leaf->pagename);
    # remove the actual page-file from this list
    pop @bits;
    for (my $i=0; $i < scalar @bits; $i++)
    {
        my $section = sprintf('section%d', $i + 1); # sections start from 1 not 0
        $meta->{$section} = $bits[$i];
    }

    # the first Alpha of the name; good for headers in reports
    $meta->{name_a} = uc(substr($leaf->bald_name, 0, 1));

    # name-spaced
    my $namespaced = $leaf->bald_name;
    $namespaced =~ s#_# #g;
    $namespaced =~ s#-# #g;
    $namespaced =~ s/([-\w]+)/\u\L$1/g;
    $meta->{namespaced} = $namespaced;

    # plural and singular 
    # assuming that the page-name is a noun...
    my $noun = noun($leaf->bald_name);
    if ($noun->is_plural())
    {
        $meta->{singular} = $noun->singular();
        $meta->{plural} = $leaf->bald_name;
    }
    elsif ($noun->is_singular())
    {
        $meta->{singular} = $leaf->bald_name;
        $meta->{plural} = $noun->plural();
    }
    else # neither
    {
        $meta->{singular} = $leaf->bald_name;
        $meta->{plural} = $leaf->bald_name;
    }

    # Classify the prose length for for pages which have a "words" field;
    # this assumes that this is a page which has information ABOUT
    # some piece of prose, NOT that the page itself contains a piece of prose.
    # For that, consult the "wordcount" field.
    if ($meta->{words})
    {
        my $len = '';
        if ($meta->{words} == 100)
        {
            $len = 'Drabble';
        } elsif ($meta->{words} == 200)
        {
            $len = 'Double-Drabble';
        } elsif ($meta->{words} >= 75000)
        {
            $len = 'Long-Novel';
        } elsif ($meta->{words} >= 50000)
        {
            $len = 'Novel';
        } elsif ($meta->{words} >= 25000)
        {
            $len = 'Novella';
        } elsif ($meta->{words} >= 7500)
        {
            $len = 'Novelette';
        } elsif ($meta->{words} >= 2000)
        {
            $len = 'Short-Story';
        } elsif ($meta->{words} > 500)
        {
            $len = 'Short-Short';
        } elsif ($meta->{words} <= 500)
        {
            $len = 'Flash';
        }
        $meta->{story_length} = $len;
    }

    # ============================================
    # DATE stuff
    # ============================================

    # Some date adjustments.
    # Files may have creation-date information in them;
    # use that for the "date" of the page
    if (exists $meta->{timestamp}
            and defined $meta->{timestamp}
            and $meta->{timestamp} != $meta->{mtime})
    {
        $meta->{date} = strftime('%Y-%m-%d %H:%M', localtime($meta->{timestamp}));
    }
    elsif (exists $meta->{creation_date}
            and defined $meta->{creation_date}
            and $meta->{creation_date} =~ /^\d\d\d\d-\d\d-\d\d/)
    {
        $meta->{date} = $meta->{creation_date};
    }
    elsif (exists $meta->{fetch_date}
            and defined $meta->{fetch_date}
            and $meta->{fetch_date} =~ /^\d\d\d\d-\d\d-\d\d/)
    {
        $meta->{date} = $meta->{fetch_date};
    }

    # Derived date-related info using DateTime
    # Look for existing fields which end with _date
    foreach my $fn (keys %{$meta})
    {
        if (($fn =~ /_date$/ or $fn eq 'date')
                and defined $meta->{$fn}
                and $meta->{$fn} =~ /^(\d\d\d\d)-(\d\d)-(\d\d)/)
        {
            my $year = $1;
            my $month = $2;
            my $day = $3;
            my $hour = 0;
            my $min = 0;
            # The date MAY have time info in it too
            if ($meta->{$fn} =~ /^\d\d\d\d-\d\d-\d\d (\d+):(\d\d)/)
            {
                $hour = $1;
                $min = $2;
            }
            my $dt = DateTime->new(year=>$year,month=>$month,day=>$day,
                hour=>$hour,minute=>$min);
            $meta->{"${fn}time"} = $dt->epoch();
            $meta->{"${fn}_year"} = $dt->year();
            $meta->{"${fn}_month"} = $dt->month();
            $meta->{"${fn}_monthname"} = $dt->month_name();
        }
    }

    $leaf->{meta} = $meta;

    return $leaf;
} # process


1;
