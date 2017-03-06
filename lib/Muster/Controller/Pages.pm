package Muster::Controller::Pages;

#ABSTRACT: Muster::Controller::Pages - Pages controller for Muster
=head1 NAME

Muster::Controller::Pages - Pages controller for Muster

=head1 SYNOPSIS

    use Muster::Controller::Pages;

=head1 DESCRIPTION

Pages controller for Muster

=cut

use Mojo::Base 'Mojolicious::Controller';

sub options {
    my $c  = shift;
    $c->muster_set_options();
    $c->render(template => 'settings');
}

sub pagelist {
    my $c  = shift;
    $c->render(template=>'pagelist');
}

sub page {
    my $c  = shift;
    $c->muster_serve_page();
}

sub scan {
    my $c  = shift;
    my $path = $c->param('cpath');
    if ($path)
    {
        $c->muster_scan_page(path=>$path);
    }
    else
    {
        $c->muster_scan_all();
    }
}

sub debug {
    my $c  = shift;
    my $path = $c->param('cpath');
    $c->reply->exception("Debug" . (defined $path ? " $path" : ''));
}

1;
