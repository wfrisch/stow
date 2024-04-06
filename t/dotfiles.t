#!/usr/bin/perl
#
# This file is part of GNU Stow.
#
# GNU Stow is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# GNU Stow is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see https://www.gnu.org/licenses/.

#
# Test case for dotfiles special processing
#

use strict;
use warnings;

use Test::More tests => 10;
use English qw(-no_match_vars);

use Stow::Util qw(adjust_dotfile);
use testutil;

init_test_dirs();
cd("$TEST_DIR/target");

subtest('adjust_dotfile()', sub {
    plan tests => 9;
    my @TESTS = (
        ['file'],
        ['dot-file', '.file'],
        ['dir1/file'],
        ['dir1/dir2/file'],
        ['dir1/dir2/dot-file', 'dir1/dir2/.file'],
        ['dir1/dot-dir2/file', 'dir1/.dir2/file'],
        ['dir1/dot-dir2/dot-file', 'dir1/.dir2/.file'],
        ['dot-dir1/dot-dir2/dot-file', '.dir1/.dir2/.file'],
        ['dot-dir1/dot-dir2/file', '.dir1/.dir2/file'],
    );
    for my $test (@TESTS) {
        my ($input, $expected) = @$test;
        $expected ||= $input;
        is(adjust_dotfile($input), $expected);
    }
});

my $stow;

subtest("stow a dotfile marked with 'dot' prefix", sub {
    plan tests => 1;
    $stow = new_Stow(dir => '../stow', dotfiles => 1);
    make_path('../stow/dotfiles');
    make_file('../stow/dotfiles/dot-foo');

    $stow->plan_stow('dotfiles');
    $stow->process_tasks();
    is(
        readlink('.foo'),
        '../stow/dotfiles/dot-foo',
        => 'processed dotfile'
    );
});

subtest("ensure that turning off dotfile processing links files as usual", sub {
    plan tests => 1;
    $stow = new_Stow(dir => '../stow', dotfiles => 0);
    make_path('../stow/dotfiles');
    make_file('../stow/dotfiles/dot-foo');

    $stow->plan_stow('dotfiles');
    $stow->process_tasks();
    is(
        readlink('dot-foo'),
        '../stow/dotfiles/dot-foo',
        => 'unprocessed dotfile'
    );

});

subtest("stow folder marked with 'dot' prefix", sub {
    plan tests => 1;
    $stow = new_Stow(dir => '../stow', dotfiles => 1);

    make_path('../stow/dotfiles/dot-emacs');
    make_file('../stow/dotfiles/dot-emacs/init.el');

    $stow->plan_stow('dotfiles');
    $stow->process_tasks();
    is(
        readlink('.emacs'),
        '../stow/dotfiles/dot-emacs',
        => 'processed dotfile folder'
    );
});

subtest("process folder marked with 'dot' prefix when directory exists is target", sub {
    plan tests => 1;
    $stow = new_Stow(dir => '../stow', dotfiles => 1);

    make_path('../stow/dotfiles/dot-emacs.d');
    make_file('../stow/dotfiles/dot-emacs.d/init.el');
    make_path('.emacs.d');

    $stow->plan_stow('dotfiles');
    $stow->process_tasks();
    is(
        readlink('.emacs.d/init.el'),
        '../../stow/dotfiles/dot-emacs.d/init.el',
        => 'processed dotfile folder when folder exists (1 level)'
    );
});

subtest("process folder marked with 'dot' prefix when directory exists is target (2 levels)", sub {
    plan tests => 1;
    $stow = new_Stow(dir => '../stow', dotfiles => 1);

    make_path('../stow/dotfiles/dot-emacs.d/dot-emacs.d');
    make_file('../stow/dotfiles/dot-emacs.d/dot-emacs.d/init.el');
    make_path('.emacs.d');

    $stow->plan_stow('dotfiles');
    $stow->process_tasks();
    is(
        readlink('.emacs.d/.emacs.d'),
        '../../stow/dotfiles/dot-emacs.d/dot-emacs.d',
        => 'processed dotfile folder exists (2 levels)'
    );
});

subtest("process folder marked with 'dot' prefix when directory exists is target", sub {
    plan tests => 1;
    $stow = new_Stow(dir => '../stow', dotfiles => 1);

    make_path('../stow/dotfiles/dot-one/dot-two');
    make_file('../stow/dotfiles/dot-one/dot-two/three');
    make_path('.one/.two');

    $stow->plan_stow('dotfiles');
    $stow->process_tasks();
    is(
        readlink('./.one/.two/three'),
        '../../../stow/dotfiles/dot-one/dot-two/three',
        => 'processed dotfile 2 folder exists (2 levels)'
    );

});

subtest("dot-. should not have that part expanded.", sub {
    plan tests => 2;
    $stow = new_Stow(dir => '../stow', dotfiles => 1);

    make_path('../stow/dotfiles');
    make_file('../stow/dotfiles/dot-');

    make_path('../stow/dotfiles/dot-.');
    make_file('../stow/dotfiles/dot-./foo');

    $stow->plan_stow('dotfiles');
    $stow->process_tasks();
    is(
        readlink('dot-'),
        '../stow/dotfiles/dot-',
        => 'processed dotfile'
    );
    is(
        readlink('dot-.'),
        '../stow/dotfiles/dot-.',
        => 'unprocessed dotfile'
    );
});

subtest("simple unstow scenario", sub {
    plan tests => 3;
    $stow = new_Stow(dir => '../stow', dotfiles => 1);

    make_path('../stow/dotfiles');
    make_file('../stow/dotfiles/dot-bar');
    make_link('.bar', '../stow/dotfiles/dot-bar');

    $stow->plan_unstow('dotfiles');
    $stow->process_tasks();
    is($stow->get_conflict_count, 0);
    ok(-f '../stow/dotfiles/dot-bar');
    ok(! -e '.bar' => 'unstow a simple dotfile');
});

subtest("unstow process folder marked with 'dot' prefix when directory exists is target", sub {
    plan tests => 4;
    $stow = new_Stow(dir => '../stow', dotfiles => 1);

    make_path('../stow/dotfiles/dot-emacs.d');
    make_file('../stow/dotfiles/dot-emacs.d/init.el');
    make_path('.emacs.d');
    make_link('.emacs.d/init.el', '../../stow/dotfiles/dot-emacs.d/init.el');

    $stow->plan_unstow('dotfiles');
    $stow->process_tasks();
    is($stow->get_conflict_count, 0);
    ok(-f '../stow/dotfiles/dot-emacs.d/init.el');
    ok(! -e '.emacs.d/init.el');
    ok(-d '.emacs.d/' => 'unstow dotfile folder when folder already exists');
});
