#!/usr/bin/env perl

# Copyright (c) 2008 - Axiombox - http://www.axiombox.com/
#	David Moreno Garza <david@axiombox.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#

package Vitacilina;

use strict;
use warnings;

use URI;
use Template;
use XML::Feed;
use YAML::Syck;
use Data::Dumper;
use Carp;

use Vitacilina::Config qw/$FORMAT $OUTPUT $TITLE $LIMIT/;

# Constant: VERSION
#
# Vitacilina version
our $VERSION = '0.1';

my $params = {
	required => [qw{config template}],
	optional => [qw/title format/],
};

# Function: new
#
# Vitacilina constructor
#
# Parameters:
#
#  config => [ path_to_file ] - YAML configuration file path for the feeds
#  template => [ path_to_file ] - TT file path
#  output => [ path_to_file  ] - HTML file path where the output will be written
#  limit => [ n ] - Number of items to display 
#  tt_absolute => [0|1] - TT absolute paths
#  tt_relative => [0|1] - TT relative paths, overrides <tt_absolute>
sub new {
	my($self, %opts) = @_;
	
	my $o = \%opts;

	my $filter = {
		title	=> $opts{filter}->{title} || '',
		content => $opts{filter}->{content} || '',
	};
	
	my $ua = LWP::UserAgent->new(
		agent => qq{Vitacilina $VERSION},
	);
	
	# welcome to retarded; please someone fix this
	my($rel, $abs);
	$opts{tt_absolute} ? $rel = 0 : $rel = 1;
	$opts{tt_relative} ? $abs = 0 : $abs = 1;

	return bless {
		ua				=> $ua,
		format			=> $opts{format} || $FORMAT,
		output			=> $opts{output} || $OUTPUT,
		config			=> $opts{config} || '',
		limit			=> $opts{limit} || $LIMIT,
		filter			=> { 
			title => qr/$filter->{title}/i,
			content => qr/$filter->{content}/i,
		},
		title 			=> $opts{title} || $TITLE,
		template		=> $opts{template} || '',
		tt_relative		=> $rel,
		tt_absolute		=> $abs,
	}, $self;
}

# Function: render
#
# Vitacilina launcher
sub render {
  my($self) = shift;

  my $tt = Template->new(
    RELATIVE => $self->tt_relative,
    ABSOLUTE => $self->tt_absolute,
  );

  $self->{feedsData} = $self->_feedsData;

  $tt->process(
    $self->template,
    {
      feeds => $self->_feeds,
      data => $self->_data,
      title => $self->title,
    },
    $self->output,
    binmode => ':utf8',
  ) or die $tt->error;

}

# Class variables accesors
sub config {
	my($self, $config) = @_;
	$self->{config} = $config if $config;
	$self->{config};
}

sub tt_relative {
	my($self, $tt) = @_;
	$self->{tt_relative} = $tt if $tt;
	$self->{tt_relative};
}

sub tt_absolute {
	my($self, $tt) = @_;
	$self->{tt_absolute} = $tt if $tt;
	$self->{tt_absolute};
}

sub title {
	my($self, $title) = @_;
	$self->{title} = $title if $title;
	$self->{title};
}

sub template {
	my($self, $t) = @_;
	$self->{template} = $t if $t;
	$self->{template};
}

sub limit {
	my($self, $l) = @_;
	$self->{limit} = $l if $l;
	$self->{limit};
}

sub format {
	my($self, $f) = @_;
	$self->{format} = $f if $f;
	$self->{format};
}

sub output {
	my($self, $o) = shift;
	$self->{output} = $o if $o;
	$self->{output};
}

# Internal method to get the feed information
sub _feeds {
	my($self) = shift;
	
	my @feeds;
	
	foreach my $f(@{$self->{feedsData}}) {
		push @feeds, {
			blogUrl => $f->{feed}->link,
			feedUrl => $f->{url},
			author => $f->{info}->{name},
		};
	}
	
	@feeds = sort { $a->{author} cmp $b->{author} } @feeds;
	
	return \@feeds;
		
}

# Internal method to get all posts and entries by the feeds
sub _feedsData {
	my($self) = shift;
	
	my $c = LoadFile($self->{config});

	my @feeds;

	while(my($k, $v) = each %{$c}) {
		next if $k eq 'Planet' or $k eq 'DEFAULT';
		
		my $res = $self->{ua}->get($k);
		
		unless($res->is_success) {
			print STDERR qq{ERROR: $k: $res->status_line\n};
			next;
		}
		
		my $feed = XML::Feed->parse(\$res->decoded_content);
		
		unless($feed) {
			print STDERR 
				'ERROR: ',
				XML::Feed->errstr, 
				': ',
				$k, "\n";
			next;
		};
		
		push @feeds, { feed => $feed, info => $v, url => $k };
	}
	return \@feeds;
}

# Internal method to get posts.
sub _data {
	my($self) = shift;
	
	foreach (@{$params->{required}}) {
		croak "No $_ was defined" unless $self->{$_};
	}
	
	my $c = LoadFile($self->{config});
	
	my @entries;
	
	FeedsData: foreach my $f(@{$self->{feedsData}}) {
		for($f->{feed}->entries) {
			
			my $content = $_->content->body || q{};
			my $title = $_->title || q{};
			
			if($content =~ $self->{filter}->{content} and $title =~ $self->{filter}->{title}) {
				push @entries, {
					author 			=> $f->{info}->{name} || '',
					face 			=> $f->{info}->{face} || '',
					content 		=> $content,
					title 			=> $title,
					date 			=> $_->issued || '',
					permalink 		=> $_->link || '',
					channelUrl 		=> $f->{feed}->link || '',
					date_modified 	=> $_->modified || '',
				}
			}
		}
	}

	my $zero = DateTime->from_epoch(epoch => 0);
		
	@entries = sort {
		($b->{date} || $b->{date_modified} || $zero)
		<=>
		($a->{date} || $b->{date_modified} || $zero)
	} @entries;
	
	delete @entries[$self->limit .. $#entries];
	
	return \@entries;
	
}

1;

# Eso es to-, eso es to-, eso es todo amigos.
