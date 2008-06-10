#!/usr/bin/env perl
package Mouse::Object;
use strict;
use warnings;
use MRO::Compat;

use Scalar::Util qw/blessed weaken/;
use Carp 'confess';

sub new {
    my $class = shift;
    my %args  = @_;
    my $instance = bless {}, $class;

    for my $attribute ($class->meta->attributes) {
        my $key = $attribute->init_arg;
        my $default;

        if (!exists($args{$key})) {
            if ($attribute->has_default || $attribute->has_builder) {
                my $default = $attribute->default;

                unless ($attribute->is_lazy) {
                    my $builder = $attribute->builder;
                    my $value = $attribute->has_builder
                              ? $instance->$builder
                              : ref($default) eq 'CODE'
                                  ? $default->()
                                  : $default;

                    $attribute->verify_type_constraint($value)
                        if $attribute->has_type_constraint;

                    $instance->{$key} = $value;

                    weaken($instance->{$key})
                        if $attribute->weak_ref;
                }
            }
            else {
                if ($attribute->is_required) {
                    confess "Attribute '".$attribute->name."' is required";
                }
            }
        }

        if (exists($args{$key})) {
            $attribute->verify_type_constraint($args{$key})
                if $attribute->has_type_constraint;

            $instance->{$key} = $args{$key};

            weaken($instance->{$key})
                if $attribute->weak_ref;

            if ($attribute->has_trigger) {
                $attribute->trigger->($instance, $args{$key}, $attribute);
            }
        }
    }

    $instance->BUILDALL(\%args);

    return $instance;
}

sub DESTROY { shift->DEMOLISHALL }

sub BUILDALL {
    my $self = shift;

    # short circuit
    return unless $self->can('BUILD');

    no strict 'refs';

    for my $class ($self->meta->linearized_isa) {
        my $code = *{ $class . '::BUILD' }{CODE}
            or next;
        $code->($self, @_);
    }
}

sub DEMOLISHALL {
    my $self = shift;

    # short circuit
    return unless $self->can('DEMOLISH');

    no strict 'refs';

    for my $class ($self->meta->linearized_isa) {
        my $code = *{ $class . '::DEMOLISH' }{CODE}
            or next;
        $code->($self, @_);
    }
}

1;

__END__

=head1 NAME

Mouse::Object - we don't need to steenkin' constructor

=head1 METHODS

=head2 new arguments -> object

Instantiates a new Mouse::Object. This is obviously intended for subclasses.

=head2 BUILDALL \%args

Calls L</BUILD> on each class in the class hierarchy. This is called at the
end of L</new>.

=head2 BUILD \%args

You may put any business logic initialization in BUILD methods. You don't
need to redispatch or return any specific value.

=head2 DEMOLISHALL

Calls L</DEMOLISH> on each class in the class hierarchy. This is called at
L</DESTROY> time.

=head2 DEMOLISH

You may put any business logic deinitialization in DEMOLISH methods. You don't
need to redispatch or return any specific value.

=cut
