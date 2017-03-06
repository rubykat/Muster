package Muster::Leaf::File::mdwn;

#ABSTRACT: Muster::Leaf::File::mdwn - a Markdown file in a Muster content tree
=head1 NAME

Muster::Leaf::File::mdwn - a Markdown file in a Muster content tree

=head1 SYNOPSIS

    use Muster::Leaf::File;
    my $file = Muster::Leaf::File->new(
        filename => 'foo.md'
    );
    my $html = $file->html;

=head1 DESCRIPTION

File nodes represent files in a Muster::Content content tree.
This is a markdown file.

=cut

use Mojo::Base 'Muster::Leaf::File';

use Carp;
use Mojo::Util      'decode';
use Text::MultiMarkdown  'markdown';
use YAML::Any;

sub build_meta {
    my $self = shift;

    my $extracted_yml = $self->extract_yml();
    if (defined $extracted_yml
	and defined $extracted_yml->{yml})
    {
	my $parsed_yml = $self->parse_yml($extracted_yml->{yml});
        return $parsed_yml;
    }
    return undef;
}

sub build_html {
    my $self = shift;

    my $extracted_yml = $self->extract_yml();
    if (defined $extracted_yml
	and defined $extracted_yml->{content})
    {
        return markdown($extracted_yml->{content});
    }
    return undef;
}

# extract the YAML data from the given content
# Expects page, content
# Returns { yml=>$yml_str, content=>$content } or undef
# if undef is returned, there is no YAML
# but if $yml_str is undef then there was YAML but it was not legal
sub extract_yml {
    my $self = shift;
    my $content = $self->raw();

    my $start_of_content = '';
    my $yml_str = '';
    my $rest_of_content = '';
    if ($content)
    {
        if ($content =~ /^---[\n\r](.*?[\n\r])---[\n\r](.*)$/s)
        {
            $yml_str = $1;
            $rest_of_content = $2;
        }
    }
    if ($yml_str) # possible YAML
    {
	my $ydata;
	eval {$ydata = Load(encode('UTF-8', $yml_str));};
	if ($@)
	{
	    warn __PACKAGE__, " Load of data failed: $@";
	    return { yml=>undef, content=>$content };
	}
	if (!$ydata)
	{
	    warn __PACKAGE__, " no legal YAML";
	    return { yml=>undef, content=>$content };
	}
	return { yml=>$yml_str,
	    content=>$start_of_content . $rest_of_content};
    }
    return { yml=>undef, content=>$content };
} # extract_yml

# parse the YAML data from the given string
# Expects data
# Returns \%yml_data or undef
sub parse_yml {
    my $self = shift;
    my $yml_str = shift;

    if ($yml_str)
    {
	my $ydata;
	eval {$ydata = Load(encode('UTF-8', $yml_str));};
	if ($@)
	{
	    warn __PACKAGE__, " Load of data failed: $@";
	    return undef;
	}
	if (!$ydata)
	{
	    warn __PACKAGE__, " no legal YAML";
	    return undef;
	}
	if ($ydata)
	{
	    my %lc_data = ();

	    # make lower-cased versions of the data
	    foreach my $fn (keys %{$ydata})
	    {
		my $fval = $ydata->{$fn};
		my $lc_fn = $fn;
		$lc_fn =~ tr/A-Z/a-z/;
		$lc_data{$lc_fn} = $fval;
	    }
	    return \%lc_data;
	}
    }
    return undef;
} # parse_yml

1;

__END__

