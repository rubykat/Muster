package Muster::LeafFile::jpg;

#ABSTRACT: Muster::LeafFile::jpg - a JPEG file in a Muster content tree
=head1 NAME

Muster::LeafFile::jpg - a JPEG file in a Muster content tree

=head1 DESCRIPTION

File nodes represent files in a Muster::Content content tree.
This is a JPEG file.

=cut

use Mojo::Base 'Muster::LeafFile::EXIF';

use Carp;

sub is_this_a_binary {
    my $self = shift;

    return 1;
}

1;

__END__

