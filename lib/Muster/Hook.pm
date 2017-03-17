package Muster::Hook;
use Mojo::Base -base;
use Muster::LeafFile;

use Carp 'croak';

=encoding utf8

=head1 NAME

Muster::Hook - Muster hook base class

=head1 SYNOPSIS

  # CamelCase plugin name
  package Muster::Hook::MyHook;
  use Mojo::Base 'Muster::Hook';

  sub register {
      my $self = shift;

      return $self;
  }

  sub scan {
    my ($self, $leaf) = @_;

    # Magic here! :)

    return $leaf;
  }

  sub modify {
    my ($self, $leaf) = @_;

    # Magic here! :)

    return $leaf;
  }

=head1 DESCRIPTION

L<Muster::Hook> is an abstract base class for L<Muster> hooks.

I was thinking of separating out "scanner" hooks and "modification" hooks,
but for some, you want to have everything together (such as processing links);
the data collected in the scanning pass will be used in the assembly pass.

=head1 METHODS

L<Muster::Hook> inherits all methods from L<Mojo::Base> and implements
the following new ones.

=head2 register_scan

Initialize, and register hooks.

=cut
sub register_scan {
    my $self = shift;
    my $scanner = shift;
    my $conf = shift;

    return $self;
} # register_scan

=head2 register_modify

Initialize, and register hooks.

=cut
sub register_modify {
    my $self = shift;
    my $assembler = shift;
    my $conf = shift;

    return $self;
} # register_modify

=head2 scan

Scans a leaf object, updating it with meta-data.
It may also update the "content" attribute of the leaf object, in order to
prevent earlier-scanned things being re-scanned by something else later in the
scanning pass.
May leave the leaf untouched.

  my $new_leaf = $self->scan($leaf);

=cut
sub scan { 
    my ($self, $leaf) = @_;

    return $leaf;
}

=head2 modify

Modifies the content attribute of a leaf object, as part of its processing.
May leave the leaf untouched.

  my $new_leaf = $self->modify($leaf);

=cut

sub modify { 
    my ($self, $leaf) = @_;

    return $leaf;
}

1;
