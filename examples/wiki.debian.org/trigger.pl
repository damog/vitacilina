#!/usr/bin/perl

use strict;
use warnings;

use Vitacilina;
use Data::Dumper;

my $v = Vitacilina->new(
	config => 'feeds.yaml',
	template => 'wiki.tt',
	filter => {
		content => 'debian',
		title => 'debian',
	},
	limit => 20,
);

$v->render;

