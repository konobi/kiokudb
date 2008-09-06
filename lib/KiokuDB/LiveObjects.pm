#!/usr/bin/perl

package KiokuDB::LiveObjects;
use Moose;

use MooseX::AttributeHelpers;

use Scalar::Util qw(weaken);
use Scope::Guard;
use Hash::Util::FieldHash::Compat qw(fieldhash);
use Carp qw(croak);
use Devel::PartialDump qw(croak);

use namespace::clean -except => 'meta';

has _objects => (
    isa => "HashRef",
    is  => "ro",
    init_arg => undef,
    default => sub { fieldhash my %hash },
);

has _ids => (
    metaclass => 'Collection::Hash',
    isa => "HashRef",
    is  => "ro",
    init_arg => undef,
    default => sub { my %hash; \%hash },
    provides => {
        get    => "ids_to_objects",
        keys   => "live_ids",
        values => "live_objects",
    },
);

sub id_to_object {
    my ( $self, $id ) = @_;
    scalar $self->ids_to_objects($id);
}

sub objects_to_ids {
    my ( $self, @objects ) = @_;

    return $self->object_to_id($objects[0])
        if @objects == 1;

    my $o = $self->_objects;

    return map {
        my $ent = $o->{$_};
        $ent && $ent->{id};
    } @objects;
}

sub object_to_id {
    my ( $self, $obj ) = @_;

    if ( my $ent = $self->_objects->{$obj} ){
        return $ent->{id};
    }

    return undef;
}

sub objects_to_entries {
    my ( $self, @objects ) = @_;

    return $self->object_to_entry($objects[0])
        if @objects == 1;

    my $o = $self->_objects;

    return map {
        my $ent = $o->{$_};
        $ent && $ent->{entry};
    } @objects;
}

sub object_to_entry {
    my ( $self, $obj ) = @_;

    if ( my $ent = $self->_objects->{$obj} ){
        return $ent->{entry};
    }

    return undef;
}

sub update_entries {
    my ( $self, @entries ) = @_;

    my @ret;

    foreach my $entry ( @entries ) {
        my $id = $entry->id;

        my $obj = $self->_ids->{$id};

        croak "The object doesn't exist"
            unless defined $obj;

        my $ent = $self->_objects->{$obj};

        push @ret, $ent->{entry} if defined wantarray;
        $ent->{entry} = $entry;
    }

    @ret;
}

sub remove {
    my ( $self, @stuff ) = @_;

    my ( $o, $i ) = ( $self->_objects, $self->_ids );

    foreach my $thing ( @stuff ) {
        if ( ref $thing ) {
            if ( my $ent = delete $o->{$thing} ) {
                delete $i->{$ent->{id}};
                $ent->{guard}->dismiss;
            }
        } else {
            if ( ref( my $object = delete $i->{$thing} ) ) {
                if ( my $ent = delete $o->{$object} ) {
                    $ent->{guard}->dismiss;
                }
            }
        }
    }
}

sub insert {
    my ( $self, @pairs ) = @_;

    croak "The arguments must be an list of pairs of IDs/Entries to objects"
        unless @pairs % 2 == 0;

    my ( $o, $i ) = ( $self->_objects, $self->_ids );

    while ( @pairs ) {
        my ( $id, $object ) = splice @pairs, 0, 2;
        my $entry;

        if ( ref $id ) {
            $entry = $id;
            $id = $entry->id;
        }

        croak($object, " is not a reference") unless ref($object);
        croak($object, " is already registered as $o->{$object}{id}") if exists $o->{$object};

        if ( exists $i->{$id} ) {
            croak "An object with the id '$id' is already registered";
        } else {
            weaken($i->{$id} = $object);

            $o->{$object} = {
                id => $id,
                entry => $entry,
                guard => Scope::Guard->new(sub {
                    delete $i->{$id};
                }),
            };
        }
    }
}

sub clear {
    my $self = shift;

    foreach my $ent ( values %{ $self->_objects } ) {
        if ( my $guard = $ent->{guard} ) { # sometimes gone in global destruction
            $guard->dismiss;
        }
    }

    # avoid the now needless weaken magic, should be faster
    %{ $self->_objects } = ();
    %{ $self->_ids }     = ();
}

sub DEMOLISH {
    my $self = shift;
    $self->clear;
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::LiveObjects - Live object set tracking

=head1 SYNOPSIS

=head1 DESCRIPTION

This object keeps track of the set of live objects and their associated UIDs.

=cut