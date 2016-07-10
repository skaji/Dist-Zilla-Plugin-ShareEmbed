package Dist::Zilla::Plugin::ShareEmbed 0.003;
use 5.14.0;
use warnings;

use File::pushd ();
use MIME::Base64 ();
use Moose;
use Path::Tiny ();
use namespace::autoclean;
use B ();

with qw(
    Dist::Zilla::Role::AfterBuild
    Dist::Zilla::Role::FilePruner
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

my $HEAD = <<'___';
use strict;
use warnings;
use MIME::Base64 ();

my %file;

___

my $FOOT = <<'___';
sub file {
    my $class = shift;
    @_ ? $file{$_[0]} : \%file;
}

1;
___

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
    print {$fh} $HEAD;
    for my $name (sort keys %file) {
        my $quoted = B::perlstring($name);
        print {$fh} "\$file{$quoted} = MIME::Base64::decode_base64(<<'___');\n";
        print {$fh} $file{$name};
        print {$fh} "___\n\n";
    }
    print {$fh} $FOOT;
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
