package ES::Repo;

use strict;
use warnings;
use v5.10;

use ES::Util qw(run);

my %Repos;

#===================================
sub new {
#===================================
    my ( $class, %args ) = @_;

    my $name = $args{name} or die "No <name> specified";
    my $dir  = $args{dir}  or die "No <dir> specified for repo <$name>";
    my $url  = $args{url}  or die "No <url> specified for repo <$name>";

    my $current = $args{current}
        or die "No <current> branch specified for repo <$name>";

    my $branches = $args{branches}
        or die "No <branches> specified for repo <$name>";

    die "<branches> must be an array in repo <$name>"
        unless ref $branches eq 'ARRAY';

    die "Current branch <$current> is not in <branches> in repo <$name>"
        unless grep { $current eq $_ } @$branches;

    my $self = bless {
        name     => $name,
        dir      => $dir->subdir($name),
        git_dir  => $dir->subdir( $name, '.git' ),
        url      => $url,
        current  => $current,
        branches => $branches
    }, $class;
    $Repos{$name} = $self;
}

#===================================
sub get_repo {
#===================================
    my $class = shift;
    my $name = shift || '';
    return $Repos{$name} || die "Unknown repo name <$name>";
}

#===================================
sub update_from_remote {
#===================================
    my $self = shift;
    my $dir  = $self->dir;

    local $ENV{GIT_DIR} = $self->git_dir;

    eval {
        if ( $dir->stat ) {
            say " - Fetching ".$self->name;
            run qw(git fetch);
        }
        else {
            my $url = $self->url;
            say " - Cloning $self->name from <$url>";
            run 'git', 'clone', $url, $dir;
        }
        1;
    }
        or die "Error updating repo <$self->name>: $@";
}

#===================================
sub checkout {
#===================================
    my $self = shift;
    my ( $path, $branch ) = @_;

    my $tracker = $self->tracker_branch(@_);

    local $ENV{GIT_DIR}       = $self->git_dir;
    local $ENV{GIT_WORK_TREE} = $self->dir;

    run qw( git reset --hard );
    run qw( git clean --force );
    run qw( git checkout -B _build_docs ), "origin/$branch";
    return 1;
}

#===================================
sub has_changed {
#===================================
    my $self = shift;
    my ( $path, $branch ) = @_;

    my $tracker = $self->tracker_branch(@_);

    local $ENV{GIT_DIR} = $self->git_dir;

    my $new = $self->_sha_for("refs/remotes/origin/$branch")
        or die "Remote branch <origin/$branch> doesn't exist "
        . "in repo <$self->name>";

    my $old = $self->_sha_for("refs/heads/$tracker")
        or return 1;

    return if $old eq $new;

    return !!run qw(git diff --shortstat), $old, $new, '--', $path;
}

#===================================
sub mark_done {
#===================================
    my $self = shift;
    my ( $path, $branch ) = @_;

    my $tracker = $self->tracker_branch(@_);

    local $ENV{GIT_DIR}       = $self->git_dir;
    local $ENV{GIT_WORK_TREE} = $self->dir;

    run qw( git checkout -B), $tracker, "refs/remotes/origin/$branch";
    run qw( git branch -D _build_docs);
}

#===================================
sub tracker_branch {
#===================================
    my $self   = shift;
    my $path   = shift or die "No <path> specified";
    my $branch = shift or die "No <branch> specified";
    return "_${path}_${branch}";
}

#===================================
sub _sha_for {
#===================================
    my ( $self, $rev ) = @_;
    my $sha = eval { run 'git', 'rev-parse', $rev } || '';
    chomp $sha;
    return $sha;
}

#===================================
sub name     { shift->{name} }
sub dir      { shift->{dir} }
sub git_dir  { shift->{git_dir} }
sub url      { shift->{url} }
sub current  { shift->{current} }
sub branches { shift->{branches} }
#===================================

1
