#!/usr/bin/env perl

use inc::Module::Install;

name 'Vitacilina';
all_from 'lib/Vitacilina.pm';

requires 'XML::Feed' => '0.41';
no_index directory => 'examples';
# license_from 'LICENSE';

WriteAll;
