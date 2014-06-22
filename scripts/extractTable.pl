#!/usr/bin/perl
# The MIT License (MIT) Copyright (c) 2014 Stephen A Jazdzewski
# Filter  SQLFairy XML file for specific tables
# Arguments <XML file> <table> [...]
# Output is XML to stdout
# This can be piped to sqlt functions
use XML::Twig;

my $twig_handlers = {'table' =>  \&table};

# Pickup file name
my $file=shift(@ARGV);

# Add the passed table names to hash
foreach my $value (@ARGV) {
        $tables{$value}=1;
}

# Define table tag handler
my $twig= new XML::Twig(TwigRoots => {'table' => 1},
        TwigHandlers => $twig_handlers);

# Parse the passed XML file
# Deleting any table that was not passed on the command line
$twig->parsefile($file);

# Out with an XML file only containing passed tables
$twig->print;

# Handle every table we find
# Delete it from XML Tree if it was not in $tables
sub table {
        my ($twig, $table) = @_;
        my $name=$table->att('name');
        if (!exists $tables{$name}) {
                $table->delete;
        }
}

