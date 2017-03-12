package Muster::PagesHelper;

#ABSTRACT: Muster::PagesHelper - helping with pages
=head1 NAME

Muster::PagesHelper - helping with pages

=head1 SYNOPSIS

    use Muster::PagesHelper;

=head1 DESCRIPTION

Content management system; getting and showing pages.

=cut

use Mojo::Base 'Mojolicious::Plugin';
use Muster::Leaf;
use Muster::Leaf::File;
use Muster::MetaDb;
use common::sense;
use DBI;
use Text::NeatTemplate;
use YAML::Any;
use File::Slurper 'read_binary';
use POSIX qw(ceil);
use Mojo::URL;
use HTML::LinkList;

=head1 REGISTER

=cut

sub register {
    my ( $self, $app, $conf ) = @_;

    $self->_init($app,$conf);

    $app->helper( 'muster_total_pages' => sub {
        my $c        = shift;
        my %args = @_;

        return $self->_total_pages($c,%args);
    } );

    $app->helper( 'muster_page_related_list' => sub {
        my $c        = shift;
        my %args = @_;

        return $self->_make_page_related_list($c,%args);
    } );

    $app->helper( 'muster_pagelist' => sub {
        my $c        = shift;
        my %args = @_;

        return $self->_pagelist($c,%args);
    } );
}

=head1 Helper Functions

These are functions which are NOT exported by this plugin.

=cut

=head2 _init

Initialize.

=cut
sub _init {
    my $self = shift;
    my $app = shift;
    my $conf = shift;

    $self->{metadb} = Muster::MetaDb->new(%{$app->config});
    $self->{metadb}->init();
    return $self;
} # _init

=head2 _total_pages

Return the total number of records in this db

=cut

sub _total_pages {
    my $self  = shift;
    my $c  = shift;

    my $total = $self->{metadb}->total_pages();
    if (!defined $total)
    {
        $c->render(template => 'apperror',
            errormsg=>"UNKNOWN");
        return undef;
    }
    return $total;
} # _total_pages

=head2 _make_page_related_list

Make a list of related pages to this page.

=cut

sub _make_page_related_list {
    my $self  = shift;
    my $c  = shift;

    my $pagename = $c->param('pagename');
    my $location = $c->url_for($pagename);
    my @pagenames = $self->{metadb}->pagelist();
    my $link_list = HTML::LinkList::nav_tree(
        current_url=>$location,
        paths=>\@pagenames,
    );
    return $link_list;
} # _make_page_related_list

=head2 _pagelist

Make a pagelist

=cut

sub _pagelist {
    my $self  = shift;
    my $c  = shift;

    my $location = $c->url_for('pagelist');
    my @pagenames = $self->{metadb}->pagelist();

    my $link_list = HTML::LinkList::full_tree(
        current_url=>$location,
        paths=>\@pagenames,
    );
    return $link_list;
} # _pagelist

1; # End of Muster::PagesHelper
__END__
