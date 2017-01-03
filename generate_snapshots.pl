#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($INFO);

use File::Spec;

my $VERSION = v0.1.0;

my $backup_snapshot_name   = "backup-snap";
my $clone_mount_point      = "/backup";
my $create_required_folder = 1;

GetOptions(
    'backup-snapshot-name|b=s'  => \$backup_snapshot_name,
    'clone-mount-point|c=s'     => \$clone_mount_point,
    'create-required-folder|f!' => \$create_required_folder
    );

# dataset stores all information
my @dataset = ();

# generate a list of all zpools in the system
my $zpools = get_all_zpools();

foreach my $zpool (@{$zpools})
{
    INFO "Working on zpool '$zpool'";

    my $zfs_set = get_all_zfs($zpool);

    foreach my $zfs (@{$zfs_set})
    {
	INFO "Working on zfs '$zfs'";

	my $mountpoint = get_mountstatus_and_mountpoint_for_zfs($zfs);
	my ($volume,$directories,$file) = (undef, undef, undef);
	my @dirs = ();

	if (defined $mountpoint)
	{
	    INFO "The zfs '$zfs' is currently mounted at '$mountpoint'";
	    my $no_file = 1;
	    ($volume,$directories,$file) = File::Spec->splitpath( $mountpoint, $no_file );
	    @dirs = File::Spec->splitdir( $directories );
	} else {
	    INFO "Seems that '$zfs' is currently not mounted";
	}

	push(@dataset, {
	    zpool => $zpool,
	    zfs   => $zfs,
	    mountpoint => $mountpoint,
	    mounted => (defined $mountpoint) ? 1 : undef,
	    dirs => \@dirs,
	     });
    }
}

# sub get_all_zpools
#
# returns an array of all available zpools in the system

sub get_all_zpools
{
    my $cmd = "sudo zpool list -H -o name";

    DEBUG "Running command '$cmd'";

    my $output = qx($cmd);

    if ($? != 0)
    {
	LOGDIE("Unable to run command '$cmd'\n");
    }

    my @result = split(/\n/, $output);

    return \@result;
}

# sub get_all_zfs
#
# returns an array of all available zfs for a given pool

sub get_all_zfs
{
    my $zpool = shift;

    unless (defined $zpool)
    {
	LOGDIE("No value for zpool is given, but you need to provide one!");
    }

    my $cmd = "zfs list -H -r -o name -t filesystem $zpool";

    DEBUG "Running command '$cmd'";

    my $output = qx($cmd);

    if ($? != 0)
    {
	LOGDIE("Unable to run command '$cmd'\n");
    }

    my @result = split(/\n/, $output);

    return \@result;
}

# sub get_mountstatus_and_mountpoint_for_zfs
#
# returns the mountstatus and the mountpoint for an zfs
# if returns a defined value, the zfs is mounted

sub get_mountstatus_and_mountpoint_for_zfs
{
    my $zfs = shift;

    unless (defined $zfs)
    {
	LOGDIE("No value for zfs is given, but you need to provide one!");
    }

    my $mountpoint = undef;

    my $cmd = "zfs get mounted -o value -H $zfs";

    DEBUG "Running command '$cmd'";

    my $output = qx($cmd);

    if ($? != 0)
    {
	LOGDIE("Unable to run command '$cmd'\n");
    }

    # the value should be yes in case the zfs is mounted
    if ($output =~ /^\s*yes\s*$/i)
    {
	$cmd = "zfs get mountpoint -o value -H $zfs";

	DEBUG "Running command '$cmd'";

	$output = qx($cmd);

	if ($? != 0)
	{
	    LOGDIE("Unable to run command '$cmd'\n");
	}

	$output =~ s/^\s+|\s+//g;

	$mountpoint = $output;
    }

    return $mountpoint;
}



=pod

=head1 generate_snapshots.pl

Little perl helper script to allow snapshots inside all zpools for all
mounted file systems and remount them under a specified folder as read
only clones to allow easy backup of the data set.

=head2 Parameter

=head3 --backup-snapshot-name, -b

The name of the snapshot. Default value us "backup-snap";

=head3 --clone-mount-point, -c

Where should the clones mounted into the file hierarchy. Default value
is '/backup'.

=head3 --create-required-folder, -f

If subfolder are required for mounting the clones, they will be
created if this option is set. Default value is true.

=cut
