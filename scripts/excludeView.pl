#!/usr/bin/env perl
# The MIT License (MIT) Copyright (c) 2014 Stephen A Jazdzewski
# Filter  SQLFairy XML file for specific tables
# Arguments <XML file> <table> [...]
# Output is XML to stdout
# This can be piped to sqlt functions
use XML::Twig;

my $twig_handlers = {'view' =>  \&view};

# Pickup file name
my $file=shift(@ARGV);

# Add the passed view names to hash
foreach my $value (@ARGV) {
        $views{$value}=1;
}

# Define view tag handler
my $twig= new XML::Twig(TwigRoots => {'schema' => 1},
        TwigHandlers => $twig_handlers);

# Parse the passed XML file
# Deleting any view that was passed on the command line
$twig->parsefile($file);

# Out with an XML file only containing passed views
$twig->print;

# Handle every view we find
# Delete it from XML Tree if it was not in $views
sub view {
        my ($twig, $view) = @_;
        my $name=$view->att('name');
        if (exists $views{$name}) {
                $view->delete;
        }
}

