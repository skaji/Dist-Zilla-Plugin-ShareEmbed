package Dist::Zilla::Plugin::ShareEmbed;
use strict;
use warnings;
our $VERSION = '0.001';

use Moose;
use Path::Tiny ();
use MIME::Base64 ();

with qw(
  Dist::Zilla::Role::AfterBuild
  Dist::Zilla::Role::AfterRelease
);

has module => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $name = $self->zilla->name;
        $name =~ s{-}{::}g;
        "$name\::Share";
    },
);

has path => (
    is => 'rw',
    isa => 'Path::Tiny',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $name = $self->zilla->name;
        $name =~ s{-}{/}g;
        Path::Tiny->new("lib/$name/Share.pm");
    },
);

sub after_build {
    my $self = shift;
    $self->embed_share;
}

sub after_release {
    my $self = shift;
    $self->embed_share;
}

my $TEMPLATE = <<'---';
use strict;
use warnings;
use Data::Section::Simple ();
use MIME::Base64 ();

my $file;

sub file {
    my $class = shift;
    if (@_) {
        my $all = $class->file;
        return unless $all;
        return $all->{ $_[0] };
    } else {
        return $file if $file;
        $file = Data::Section::Simple->new->get_data_section;
        return unless $file;
        for my $value (values %$file) {
            $value = MIME::Base64::decode_base64($value);
        }
        return $file;
    }
}

1;

__DATA__
---

sub embed_share {
    my $self = shift;
    my $share = $self->zilla->root->child("share");
    unless ($share->is_dir) {
        $self->log("Cannot find share/ directory");
        return;
    }

    my %file;
    {
        my $guard = File::pushd::pushd("$share");
        my $visit = sub {
            my ($path, $state) = @_;
            return if $path->is_dir;
            my $content = $path->slurp_raw;
            $file{ "$path" } = MIME::Base64::encode_base64($content);
        };
        Path::Tiny->new(".")->visit($visit, {recurse => 1});
    }
    my $path = $self->path;
    $path->parent->mkpath unless $path->parent->is_dir;
    $self->log("Embedding share/ to $path");
    my $fh = $path->openw_raw;
    print {$fh} "package " . $self->module . ";\n";
    print {$fh} $TEMPLATE;
    for my $name (sort keys %file) {
        print {$fh} "\n\@\@ $name\n";
        print {$fh} $file{$name};
    }
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
__END__

=encoding utf-8

=head1 NAME

Dist::Zilla::Plugin::ShareEmbed - Blah blah blah

=head1 SYNOPSIS

  use Dist::Zilla::Plugin::ShareEmbed;

=head1 DESCRIPTION

Dist::Zilla::Plugin::ShareEmbed is

=head1 AUTHOR

Shoichi Kaji <skaji@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2016 Shoichi Kaji <skaji@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
