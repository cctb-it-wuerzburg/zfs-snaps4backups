#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;

my $backup_snapshot_name   = "backup-snap";
my $clone_mount_point      = "/backup";
my $create_required_folder = 1;

GetOptions(
    'backup-snapshot-name|b=s'  => \$backup_snapshot_name,
    'clone-mount-point|c=s'     => \$clone_mount_point,
    'create-required-folder|f!' => \$create_required_folder
    );

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
