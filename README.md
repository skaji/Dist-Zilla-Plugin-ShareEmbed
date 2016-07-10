[![Build Status](https://travis-ci.org/skaji/Dist-Zilla-Plugin-ShareEmbed.svg?branch=master)](https://travis-ci.org/skaji/Dist-Zilla-Plugin-ShareEmbed)

# NAME

Dist::Zilla::Plugin::ShareEmbed - Embed share files to .pm file

# SYNOPSIS

In your dist.ini:

    [ShareEmbed]

Then

    > dzil build

    > find lib -type f
    lib/Your/Module.pm
    lib/Your/Module/Share.pm <=== Created!

# DESCRIPTION

Dist::Zilla::Plugin::ShareEmbed embeds share files to `lib/Your/Module/Share.pm`,
so that you can use share files like:

    use Your::Module::Share;

    # returns content of share/foo/bar.txt
    my $bar = Your::Module::Share->file("foo/bar.txt");

    # returns all contens of files in share directory
    my $all = Your::Module::Share->file;

This plugin may be useful when you intend to fatpack your modules.

# AUTHOR

Shoichi Kaji <skaji@cpan.org>

# COPYRIGHT AND LICENSE

Copyright 2016 Shoichi Kaji <skaji@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
