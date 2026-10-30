#!/usr/bin/env bash

source test/init

if [[ $(uname -s) != Linux ]]; then
  plan skip-all "Socket mediation requires Linux"
fi

real_nono=$(
  PKIO_CONFIG_MK='' make --no-print-directory -s -f "$ROOT/Makefile" \
    shell CMD='command -v nono'
)
real_nono=${real_nono##*$'\n'}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Use a mock agent so no real credentials or network services are contacted.
output=$(perl - "$real_nono" "$ROOT/etc/cmd/codex/profile.json" "$tmp" \
  <<'PERL'
use strict;
use warnings;
use File::Basename qw(dirname);
use File::Path qw(make_path);
use IO::Socket::UNIX;
use JSON::PP;
use Socket qw(SOCK_STREAM);

my ($nono, $profile, $tmp) = @ARGV;
my $socket_path = "$tmp/ssh-agent.sock";
my $server = IO::Socket::UNIX->new(
    Type => SOCK_STREAM, Local => $socket_path, Listen => 5,
) or die "listen: $!";

open my $source, '<', $profile or die "read profile: $!";
my $policy = decode_json(do { local $/; <$source> });
delete $policy->{environment};
delete $policy->{linux};
open my $control, '>', "$tmp/control.json" or die "write profile: $!";
print {$control} encode_json($policy);
close $control or die "close profile: $!";

open my $probe, '>', "$tmp/probe.pl" or die "write probe: $!";
print {$probe} <<'PROBE';
use strict;
use warnings;
use Errno qw(EACCES EPERM);
use IO::Socket::INET;
use Socket qw(AF_UNIX SOCK_STREAM sockaddr_un);

my ($path, $mode) = @ARGV;
my $expected_env = $mode eq 'control' ? 1 : 0;
die "agent environment leaked\n"
    if exists($ENV{SSH_AUTH_SOCK}) != $expected_env
    || exists($ENV{SSH_AGENT_PID}) != $expected_env;
print "$mode: environment ok\n";

# Supplying the socket path directly must not bypass the restriction.
socket(my $client, AF_UNIX, SOCK_STREAM, 0) or die "socket: $!";
my $connected = connect($client, sockaddr_un($path));
if ($mode eq 'blocked') {
    die "agent socket accessible\n" if $connected;
    die "unexpected connect error: $!" unless $! == EACCES || $! == EPERM;
} else {
    die "connect: $!" unless $connected;
}
print "$mode: socket ok\n";

open my $file, '>', 'local-file' or die "local write: $!";
print {$file} "local work\n";
close $file or die "local close: $!";
open $file, '<', 'local-file' or die "local read: $!";
die "local content changed\n" unless <$file> eq "local work\n";
my $listener = IO::Socket::INET->new(
    LocalAddr => '127.0.0.1', LocalPort => 0, Listen => 1, Proto => 'tcp',
) or die "TCP listen: $!";
my $tcp = IO::Socket::INET->new(
    PeerAddr => '127.0.0.1', PeerPort => $listener->sockport, Proto => 'tcp',
) or die "TCP connect: $!";
print "$mode: local files and TCP ok\n";
PROBE
close $probe or die "close probe: $!";

local $ENV{SSH_AUTH_SOCK} = $socket_path;
local $ENV{SSH_AGENT_PID} = '12345';
local $ENV{HOME} = "$tmp/home";
make_path($ENV{HOME}, "$tmp/project");
chdir "$tmp/project" or die "chdir: $!";
for my $mode (qw(control blocked allowed)) {
    my @grants = $mode eq 'allowed'
        ? ('--allow-unix-socket', $socket_path) : ();
    system $nono, 'run', '--silent', '--no-rollback',
        '--profile', $mode eq 'control' ? "$tmp/control.json" : $profile,
        '--allow-cwd', '--read', dirname(dirname($^X)), @grants,
        '--read-file', "$tmp/probe.pl",
        '--', $^X, "$tmp/probe.pl", $socket_path, $mode;
    die "$mode sandbox failed: $?\n" if $?;
}
PERL
)
ok $? "Codex socket policy runs under real nono"
like "$output" 'control: socket ok' \
  "control confirms the mock agent is reachable without mediation"
like "$output" 'blocked: environment ok' \
  "Codex does not inherit SSH agent environment variables"
like "$output" 'blocked: socket ok' \
  "Codex cannot connect even with an explicit agent socket path"
like "$output" 'blocked: local files and TCP ok' \
  "Codex can still read and write local files and use TCP"
like "$output" 'allowed: socket ok' \
  "explicit socket grants preserve required local services"

done-testing
