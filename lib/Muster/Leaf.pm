package Muster::Leaf;

#ABSTRACT: Muster::Leaf - a leaf of the tree, one abstract page
=head1 NAME

Muster::Leaf - a leaf of the tree, one abstract page

=head1 SYNOPSIS

    use Muster::Leaf;

=head1 DESCRIPTION

Content Management System - a leaf of the tree, one abstract page

=cut
use Mojo::Base -base;

use Carp;

has parent_node => undef;
has path        => '';
has path_prefix => '';
has name        => sub { shift->build_name };
has meta        => sub { {} };
has title       => sub { shift->build_title };

# Since this needs to be able to be cleared,
# don't use the Mojo mechanism
sub raw {
    my $self = shift;
    my $value = shift;
    if (!exists $self->{raw})
    {
        $self->{raw} = $self->build_raw();
    }
    return $self->{raw};
}

# Since this needs to be able to be cleared,
# don't use the Mojo mechanism
# Especially don't let the html be set,
# because it needs to be built from the raw source
sub html {
    my $self = shift;
    if (!exists $self->{html})
    {
        $self->{html} = $self->build_html();
    }
    return $self->{html};
}

sub decache {
    my $self = shift;
    
    delete $self->{raw};
    delete $self->{html};
}

sub build_name {
    my $self = shift;
    croak 'build_name needs to be overwritten by subclass';
}

sub build_html {
    my $self = shift;
    croak 'build_html needs to be overwritten by subclass';
}

sub build_raw {
    my $self = shift;
    croak 'build_raw needs to be overwritten by subclass';
}

sub build_title {
    my $self = shift;

    # try to extract title
    return $self->meta->{title} if exists $self->meta->{title};
    return $1 if defined $self->html and $self->html =~ m|<h1>(.*?)</h1>|i;
    return $self->name;
}

sub find {
    my ($self, $path) = @_;

    # no search
    return $self unless $path;

    # not found
    return;
}

1;
