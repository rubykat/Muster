package Muster::LeafFile::md;

#ABSTRACT: Muster::LeafFile::md - a Markdown file in a Muster content tree

=head1 NAME

Muster::LeafFile::md - a Markdown file in a Muster content tree

=head1 DESCRIPTION

File nodes represent files in a Muster::Content content tree.
This is a markdown file. This uses the '.md' extension for
compatibility with Obsidian.

=cut

use Mojo::Base 'Muster::LeafFile::mdwn';

use Carp;

1;

__END__

