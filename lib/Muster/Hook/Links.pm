package Muster::Hook::Links;

=head1 NAME

Muster::Hook::Links - Muster hook for links

=head1 SYNOPSIS

  # CamelCase plugin name
  package Muster::Hook::Links;
  use Mojo::Base 'Muster::Hook';

=head1 DESCRIPTION

L<Muster::Hook::Links> processes for links.

=cut

use Mojo::Base 'Muster::Hook';
use Muster::Leaf::File;
use YAML::Any;

# ---------------------------------------------
# Class Variables

# taken from IkiWiki code
my $Link_Regexp = qr{
		\[\[(?=[^!])            # beginning of link
		(?:
			([^\]\|]+)      # 1: link text
			\|              # followed by '|'
		)?                      # optional
		
		([^\n\r\]#]+)           # 2: page to link to
		(?:
			\#              # '#', beginning of anchor
			([^\s\]]+)      # 3: anchor text
		)?                      # optional
		
		\]\]                    # end of link
	}x;

my $Email_Regexp = qr/^.+@.+\..+$/;
my $Url_Regexp = qr/^(?:[^:]+:\/\/|mailto:).*/i;

=head1 METHODS

=head2 init

Initializes the object

=cut
sub init {
    my $self = shift;

    return $self;
} # init

=head2 scan

Scans a leaf object, updating it with meta-data.
May leave the leaf untouched.

  my $new_leaf = $self->scan($leaf);

=cut
sub scan {
    my $self = shift;
    my $leaf = shift;

    if (!$leaf->pagetype())
    {
        return $leaf;
    }
 
    my $content = $leaf->raw();
    my $page = $leaf->pagename();
    # fudge the content by replacing {{$page}} with the pagename
    $content =~ s!\{\{\$page\}\}!$page!g;
    my %links = ();

    while ($content =~ /(?<!\\)$Link_Regexp/g)
    {
        my $link = $2;
        my $anchor = $3;
        if (! $self->is_externallink($page, $link, $anchor)) {
            $links{$link}++;
        }
    }
    my @links = sort keys %links;
    if (scalar @links)
    {
        $leaf->{meta}->{links} = \@links;
    }
    return $leaf;
} # scan

=head2 modify

Modifies the "cooked" attribute of a leaf object, as part of its processing.
May leave the leaf untouched.

  my $new_leaf = $self->modify($leaf);

=cut
sub modify {
    my $self = shift;
    my $leaf = shift;

    return $leaf;
} # modify

sub is_externallink {
    my $self = shift;
    my $page = shift;
    my $url = shift;
    my $anchor = shift;

    if (defined $anchor) {
        $url.="#".$anchor;
    }

    return ($url =~ /$Url_Regexp|$Email_Regexp/)
}

sub linkpage {
    my $self = shift;
    my $link=shift;
    #my $chars = defined $config{wiki_file_chars} ? $config{wiki_file_chars} : "-[:alnum:]+/.:_";
    my $chars = "-[:alnum:]+/.:_";
    $link=~s/([^$chars])/$1 eq ' ' ? '_' : "__".ord($1)."__"/eg;
    return $link;
}

sub externallink {
    my $self = shift;
    my $url = shift;
    my $anchor = shift;
    my $pagetitle = shift;

    if (defined $anchor) {
        $url.="#".$anchor;
    }

    # build pagetitle
    if (! $pagetitle) {
        $pagetitle = $url;
        # use only the email address as title for mailto: urls
        if ($pagetitle =~ /^mailto:.*/) {
            $pagetitle =~ s/^mailto:([^?]+).*/$1/;
        }
    }

    if ($url !~ /$Url_Regexp/) {
        # handle email addresses (without mailto:)
        $url = "mailto:" . $url;
    }

    return "<a href=\"$url\">$pagetitle</a>";
}

1;
