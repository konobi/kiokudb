#!/usr/bin/perl

package KiokuDB::Cmd::TXN;
use Moose::Role;

use namespace::clean -except => 'meta';

requires "v";

has _txn => (
    traits => [qw(NoGetopt)],
    is => "rw",
);

sub try_txn_begin {
    my ( $self, $b ) = @_;

    if ( $b->does("KiokuDB::Backend::Role::TXN") ) {
        $self->v("starting transaction\n");
        $self->_txn( $b->txn_begin );
    }
}

sub try_txn_commit {
    my ( $self, $b ) = @_;

    if ( my $txn = $self->_txn ) {
        $self->v("comitting transaction...");
        $b->txn_commit($txn);
        $self->_txn(undef);
        $self->v(" done\n");
    }
}

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Cmd::TXN - A role for command line tools that should run inside a
transaction

=head1 DESCRIPTION

This role provides two methods, C<try_txn_begin> and C<try_txn_commit> which
are called on the backend if it supports transactions.
