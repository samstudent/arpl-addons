package lib;


use Config;

use strict;

my $archname         = $Config{archname};
my $version          = $Config{version};
my @inc_version_list = reverse split / /, $Config{inc_version_list};


our @ORIG_INC = @INC;	# take a handy copy of 'original' value
our $VERSION = '0.64';

sub import {
    shift;

    my %names;
    foreach (reverse @_) {
	my $path = $_;		# we'll be modifying it, so break the alias
	if ($path eq '') {
	    require Carp;
	    Carp::carp("Empty compile time value given to use lib");
	}

	if ($path !~ /\.par$/i && -e $path && ! -d _) {
	    require Carp;
	    Carp::carp("Parameter to use lib must be directory, not file");
	}
	unshift(@INC, $path);
	# Add any previous version directories we found at configure time
	foreach my $incver (@inc_version_list)
	{
	    my $dir = "$path/$incver";
	    unshift(@INC, $dir) if -d $dir;
	}
	# Put a corresponding archlib directory in front of $path if it
	# looks like $path has an archlib directory below it.
	my($arch_auto_dir, $arch_dir, $version_dir, $version_arch_dir)
	    = _get_dirs($path);
	unshift(@INC, $arch_dir)         if -d $arch_auto_dir;
	unshift(@INC, $version_dir)      if -d $version_dir;
	unshift(@INC, $version_arch_dir) if -d $version_arch_dir;
    }

    # remove trailing duplicates
    @INC = grep { ++$names{$_} == 1 } @INC;
    return;
}


sub unimport {
    shift;

    my %names;
    foreach my $path (@_) {
	my($arch_auto_dir, $arch_dir, $version_dir, $version_arch_dir)
	    = _get_dirs($path);
	++$names{$path};
	++$names{$arch_dir}         if -d $arch_auto_dir;
	++$names{$version_dir}      if -d $version_dir;
	++$names{$version_arch_dir} if -d $version_arch_dir;
    }

    # Remove ALL instances of each named directory.
    @INC = grep { !exists $names{$_} } @INC;
    return;
}

sub _get_dirs {
    my($dir) = @_;
    my($arch_auto_dir, $arch_dir, $version_dir, $version_arch_dir);

    $arch_auto_dir    = "$dir/$archname/auto";
    $arch_dir         = "$dir/$archname";
    $version_dir      = "$dir/$version";
    $version_arch_dir = "$dir/$version/$archname";

    return($arch_auto_dir, $arch_dir, $version_dir, $version_arch_dir);
}

1;
__END__

