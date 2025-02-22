use 5.008;
package base;

use strict 'vars';
our $VERSION = '2.27';
$VERSION =~ tr/_//d;

sub base::__inc::unhook { @INC = grep !(ref eq 'CODE' && $_ == $_[0]), @INC }
sub base::__inc::scope_guard::DESTROY { base::__inc::unhook $_ for @{$_[0]} }

sub SUCCESS () { 1 }

sub PUBLIC     () { 2**0  }
sub PRIVATE    () { 2**1  }
sub INHERITED  () { 2**2  }
sub PROTECTED  () { 2**3  }


my $Fattr = \%fields::attr;

sub has_fields {
    my($base) = shift;
    my $fglob = ${"$base\::"}{FIELDS};
    return( ($fglob && 'GLOB' eq ref($fglob) && *$fglob{HASH}) ? 1 : 0 );
}

sub has_attr {
    my($proto) = shift;
    my($class) = ref $proto || $proto;
    return exists $Fattr->{$class};
}

sub get_attr {
    $Fattr->{$_[0]} = [1] unless $Fattr->{$_[0]};
    return $Fattr->{$_[0]};
}

if ($] < 5.009) {
    *get_fields = sub {
        # Shut up a possible typo warning.
        () = \%{$_[0].'::FIELDS'};
        my $f = \%{$_[0].'::FIELDS'};

        # should be centralized in fields? perhaps
        # fields::mk_FIELDS_be_OK. Peh. As long as %{ $package . '::FIELDS' }
        # is used here anyway, it doesn't matter.
        bless $f, 'pseudohash' if (ref($f) ne 'pseudohash');

        return $f;
    }
}
else {
    *get_fields = sub {
        # Shut up a possible typo warning.
        () = \%{$_[0].'::FIELDS'};
        return \%{$_[0].'::FIELDS'};
    }
}

if ($] < 5.008) {
    *_module_to_filename = sub {
        (my $fn = $_[0]) =~ s!::!/!g;
        $fn .= '.pm';
        return $fn;
    }
}
else {
    *_module_to_filename = sub {
        (my $fn = $_[0]) =~ s!::!/!g;
        $fn .= '.pm';
        utf8::encode($fn);
        return $fn;
    }
}


sub import {
    my $class = shift;

    return SUCCESS unless @_;

    # List of base classes from which we will inherit %FIELDS.
    my $fields_base;

    my $inheritor = caller(0);

    my @bases;
    foreach my $base (@_) {
        if ( $inheritor eq $base ) {
            warn "Class '$inheritor' tried to inherit from itself\n";
        }

        next if grep $_->isa($base), ($inheritor, @bases);

        # Following blocks help isolate $SIG{__DIE__} and @INC changes
        {
            my $sigdie;
            {
                local $SIG{__DIE__};
                my $fn = _module_to_filename($base);
                my $dot_hidden;
                eval {
                    my $guard;
                    if ($INC[-1] eq '.' && %{"$base\::"}) {
                        # So:  the package already exists   => this an optional load
                        # And: there is a dot at the end of @INC  => we want to hide it
                        # However: we only want to hide it during our *own* require()
                        # (i.e. without affecting nested require()s).
                        # So we add a hook to @INC whose job is to hide the dot, but which
                        # first checks checks the callstack depth, because within nested
                        # require()s the callstack is deeper.
                        # Since CORE::GLOBAL::require makes it unknowable in advance what
                        # the exact relevant callstack depth will be, we have to record it
                        # inside a hook. So we put another hook just for that at the front
                        # of @INC, where it's guaranteed to run -- immediately.
                        # The dot-hiding hook does its job by sitting directly in front of
                        # the dot and removing itself from @INC when reached. This causes
                        # the dot to move up one index in @INC, causing the loop inside
                        # pp_require() to skip it.
                        # Loaded coded may disturb this precise arrangement, but that's OK
                        # because the hook is inert by that time. It is only active during
                        # the top-level require(), when @INC is in our control. The only
                        # possible gotcha is if other hooks already in @INC modify @INC in
                        # some way during that initial require().
                        # Note that this jiggery hookery works just fine recursively: if
                        # a module loaded via base.pm uses base.pm itself, there will be
                        # one pair of hooks in @INC per base::import call frame, but the
                        # pairs from different nestings do not interfere with each other.
                        my $lvl;
                        unshift @INC,        sub { return if defined $lvl; 1 while defined caller ++$lvl; () };
                        splice  @INC, -1, 0, sub { return if defined caller $lvl; ++$dot_hidden, &base::__inc::unhook; () };
                        $guard = bless [ @INC[0,-2] ], 'base::__inc::scope_guard';
                    }
                    require $fn
                };
                if ($dot_hidden && (my @fn = grep -e && !( -d _ || -b _ ), $fn.'c', $fn)) {
                    require Carp;
                    Carp::croak(<<ERROR);
Base class package "$base" is not empty but "$fn[0]" exists in the current directory.
    To help avoid security issues, base.pm now refuses to load optional modules
    from the current working directory when it is the last entry in \@INC.
    If your software worked on previous versions of Perl, the best solution
    is to use FindBin to detect the path properly and to add that path to
    \@INC.  As a last resort, you can re-enable looking in the current working
    directory by adding "use lib '.'" to your code.
ERROR
                }
                # Only ignore "Can't locate" errors from our eval require.
                # Other fatal errors (syntax etc) must be reported.
                #
                # changing the check here is fragile - if the check
                # here isn't catching every error you want, you should
                # probably be using parent.pm, which doesn't try to
                # guess whether require is needed or failed,
                # see [perl #118561]
                die if $@ && $@ !~ /^Can't locate \Q$fn\E .*? at .* line [0-9]+(?:, <[^>]*> (?:line|chunk) [0-9]+)?\.\n\z/s
                          || $@ =~ /Compilation failed in require at .* line [0-9]+(?:, <[^>]*> (?:line|chunk) [0-9]+)?\.\n\z/;
                unless (%{"$base\::"}) {
                    require Carp;
                    local $" = " ";
                    Carp::croak(<<ERROR);
Base class package "$base" is empty.
    (Perhaps you need to 'use' the module which defines that package first,
    or make that module available in \@INC (\@INC contains: @INC).
ERROR
                }
                $sigdie = $SIG{__DIE__} || undef;
            }
            # Make sure a global $SIG{__DIE__} makes it out of the localization.
            $SIG{__DIE__} = $sigdie if defined $sigdie;
        }
        push @bases, $base;

        if ( has_fields($base) || has_attr($base) ) {
            # No multiple fields inheritance *suck*
            if ($fields_base) {
                require Carp;
                Carp::croak("Can't multiply inherit fields");
            } else {
                $fields_base = $base;
            }
        }
    }
    # Save this until the end so it's all or nothing if the above loop croaks.
    push @{"$inheritor\::ISA"}, @bases;

    if( defined $fields_base ) {
        inherit_fields($inheritor, $fields_base);
    }
}


sub inherit_fields {
    my($derived, $base) = @_;

    return SUCCESS unless $base;

    my $battr = get_attr($base);
    my $dattr = get_attr($derived);
    my $dfields = get_fields($derived);
    my $bfields = get_fields($base);

    $dattr->[0] = @$battr;

    if( keys %$dfields ) {
        warn <<"END";
$derived is inheriting from $base but already has its own fields!
This will cause problems.  Be sure you use base BEFORE declaring fields.
END

    }

    # Iterate through the base's fields adding all the non-private
    # ones to the derived class.  Hang on to the original attribute
    # (Public, Private, etc...) and add Inherited.
    # This is all too complicated to do efficiently with add_fields().
    while (my($k,$v) = each %$bfields) {
        my $fno;
        if ($fno = $dfields->{$k} and $fno != $v) {
            require Carp;
            Carp::croak ("Inherited fields can't override existing fields");
        }

        if( $battr->[$v] & PRIVATE ) {
            $dattr->[$v] = PRIVATE | INHERITED;
        }
        else {
            $dattr->[$v] = INHERITED | $battr->[$v];
            $dfields->{$k} = $v;
        }
    }

    foreach my $idx (1..$#{$battr}) {
        next if defined $dattr->[$idx];
        $dattr->[$idx] = $battr->[$idx] & INHERITED;
    }
}


1;

__END__

