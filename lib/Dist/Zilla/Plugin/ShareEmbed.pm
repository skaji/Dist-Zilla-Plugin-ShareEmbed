package Dist::Zilla::Plugin::ShareEmbed 0.001;
use 5.14.0;
use warnings;

use File::pushd ();
use List::MoreUtils ();
use MIME::Base64 ();
use Moose;
use Path::Tiny ();
use namespace::autoclean;

with qw(
    Dist::Zilla::Role::AfterBuild
    Dist::Zilla::Role::FilePruner
    Dist::Zilla::Role::PrereqSource
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

if (exists $INC{"Dist/Zilla/Dist/Builder.pm"}) {
    # XXX I don't know the best way to do this :)
    package
        Dist::Zilla::Dist::Builder;
    no warnings 'redefine';
    sub _build_share_dir_map {
        return +{};
    }
}

sub has_share {
    my $self = shift;
    $self->zilla->root->child("share")->is_dir;
}

sub after_build {
    my $self = shift;
    return unless $self->has_share;

    $self->embed_share;
}

sub prune_files {
    my $self = shift;
    return unless $self->has_share;

    # XXX This copy is needed.
    # because $self->zilla->prune_file splices $self->zilla->files
    my @file = @{ $self->zilla->files };

    for my $file (@file) {
        if ($file->name =~ m{^share/}) {
            $self->zilla->prune_file($file);
        }
    }
    return;
}

sub register_prereqs {
    my $self = shift;
    return unless $self->has_share;

    $self->zilla->register_prereqs(
        { phase => 'runtime' },
        'Data::Section::Simple' => 0,
    );
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

__PACKAGE__->meta->make_immutable;

1;
__END__

=encoding utf-8

=for stopwords pm

=head1 NAME

Dist::Zilla::Plugin::ShareEmbed - Embed share files to .pm file

=head1 SYNOPSIS

In your dist.ini:

  [ShareEmbed]

Then

  > dzil build

  > find lib -type f
  lib/Your/Module.pm
  lib/Your/Module/Share.pm <=== Created!

=head1 DESCRIPTION

Dist::Zilla::Plugin::ShareEmbed embeds share files to C<lib/Your/Module/Share.pm>,
so that you can use share files like:

  use Your::Module::Share;

  # returns content of share/foo/bar.txt
  my $bar = Your::Module::Share->file("foo/bar.txt");

  # returns all contens of files in share directory
  my $all = Your::Module::Share->file;

This plugin may be useful when you intend to fatpack your modules.

=head1 AUTHOR

Shoichi Kaji <skaji@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2016 Shoichi Kaji <skaji@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
