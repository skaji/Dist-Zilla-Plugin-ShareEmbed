requires 'perl', '5.008005';
requires 'Dist::Zilla', '6.000';

on test => sub {
    requires 'Test::More', '0.98';
};
