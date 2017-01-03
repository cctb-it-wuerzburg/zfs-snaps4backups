#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($INFO);

use File::Spec;
use File::Path;

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

# sort the dataset based on the mountpoint directory level, to asure the existance of required folders
@dataset = sort { int(@{$a->{dirs}}) <=> int(@{$b->{dirs}}) || $a->{mountpoint} cmp $b->{mountpoint} || $a->{zpool} cmp $b->{zpool} || $a->{zfs} cmp $b->{zfs} } @dataset;

foreach my $current_dataset (@dataset)
{
    # create snapshot
    DEBUG "Trying to do a snapshot of '$current_dataset->{zfs}' with the name '$backup_snapshot_name'";
    my $snapshot_name = create_snapshot($current_dataset->{zfs}, $backup_snapshot_name);
    INFO "Created snapshot '$snapshot_name'";

    # check if folder exists for mounting the clone
    my $clone_mountpoint = check_or_create_folder($current_dataset->{mountpoint}, $clone_mount_point);
    INFO "Created folder '$clone_mountpoint'";
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

# sub create_snapshot
#
# creates a snapshot of a zfs and returns the complete name bases on the name of a zfs and a snapshot name

sub create_snapshot
{
    my $zfs = shift;

    unless (defined $zfs)
    {
	LOGDIE("No value for zfs is given, but you need to provide one!");
    }

    my $snapshotname = shift;

    unless (defined $snapshotname)
    {
	LOGDIE("No value for snapshotname is given, but you need to provide one!");
    }

    my $snap = join("@", ($zfs, $snapshotname));

    # check if the snapshot exists
    my $cmd = "zfs list -t snapshot $snap";

    DEBUG "Running command '$cmd'";

    my $output = qx($cmd);

    if ($? == 0)
    {
	# snapshot exists
	INFO "Snapshot '$snap' exists. Assuming an interrupted backup and returning old snapshot";
    } else {
	# snapshot not yet exists, create it
	$cmd = "zfs snapshot $snap";

	DEBUG "Running command '$cmd'";

	$output = qx($cmd);

	if ($? != 0)
	{
	    LOGDIE("Unable to run command '$cmd'\n");
	}
    }

    return $snap;
}

# sub check_or_create_folder
#
# creates folder structure if it does not exist

sub check_or_create_folder
{
    my $mountpoint = shift;

    unless (defined $mountpoint)
    {
	LOGDIE("No value for mountpoint is given, but you need to provide one!");
    }

    my $backupfolder = shift;

    unless (defined $backupfolder)
    {
	LOGDIE("No value for backupfolder is given, but you need to provide one!");
    }

    my $path = File::Spec->catdir( $backupfolder, $mountpoint );

    DEBUG "Will try to create folder '$path'";
    File::Path->make_path($path, { error => \my $err } );
    if (@$err) {
	for my $diag (@$err) {
	    my ($file, $message) = %$diag;
	    if ($file eq '') {
		LOGDIE("general error: $message");
	    }
	    else {
		LOGDIE("problem creating $file: $message");
	    }
	}
    }

    return $path;
}

# sub clone_snapshot_ro_with_mountpoint
#
# creates a readonly clone of a backup snapshot and mounts it to a specified mountpoint

sub clone_snapshot_ro_with_mountpoint
{
    my $snapshotname = shift;

    unless (defined $snapshotname)
    {
	LOGDIE("No value for snapshotname is given, but you need to provide one!");
    }

    my $mountpoint = shift;

    unless (defined $mountpoint)
    {
	LOGDIE("No value for mountpoint is given, but you need to provide one!");
    }

    my $zfs_clone = $snapshotname;
    unless ($zfs_clone =~ tr/@/@/ != 0)
    {
	LOGDIE "More than one @ in snapshotname '$snapshotname'";
    }

    $zfs_clone =~ s/@/_4_backup_/;

    DEBUG "Trying to clone '$snapshotname' to '$zfs_clone' as readonly set with mountpoint '$mountpoint'";
    my $cmd = "zfs clone -o readonly=on -o mountpoint=$mountpoint $snapshotname $zfs_clone";

    DEBUG "Running command '$cmd'";
    my $output = qx($cmd);

    if ($? != 0)
    {
	LOGDIE("Unable to run command '$cmd'\n");
    }

    return $zfs_clone;
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
