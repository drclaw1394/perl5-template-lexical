package Template::Plex::Base;

use strict;
use warnings;

use feature qw<isa>;
#use Template::Plex;
use Log::ger;
use Log::OK;


use Symbol qw<delete_package>;

use constant KEY_OFFSET=>0;
use enum ("plex_=0",qw<meta_ args_ sub_ package_ init_done_flag_ skip_>);
use constant KEY_COUNT=>skip_ - plex_ +1;


sub new {
	my ($package, $plex)=@_;
	my $self=[];
	$self->[plex_]=$plex;
	bless $self, $package;
}


sub _plex_ {
	$_[0][Template::Plex::Base::plex_];
}

sub meta :lvalue { $_[0][Template::Plex::Base::meta_]; }

sub args :lvalue{ $_[0][Template::Plex::Base::args_]; }

sub init_done_flag:lvalue{ $_[0][Template::Plex::Base::init_done_flag_]; }


sub render {
	#sub in plex requires self as first argument
	return $_[0][sub_](@_);
}

sub skip {
	Log::OK::DEBUG and log_debug("Template::Plex::Base: Skipping Template: ".$_[0]->meta->{file});
	$_[0]->[skip_]->();
}

#A call to this method will run the sub an preparation
#and immediately stop rendering the template
sub _init {
	my ($self, $sub)=@_;

	return if $self->[init_done_flag_];
	Log::OK::DEBUG and log_debug("Template::Plex::Base: Initalising Template: :".$self->meta->{file});
	unless($self isa Template::Plex::Base){
	#if($self->[meta_]{package} ne caller){
	Log::OK::ERROR and log_error("Template::Plex::Base: init must only be called within a template: ".$self->meta->{file});
		return;
	}

	$self->pre_init;
	$sub->();
	$self->post_init;

	$self->[init_done_flag_]=1;
	$self->skip;
	"";		#Must return an empty string
}

sub pre_init {

}

sub post_init {

}

#Execute the template in setup mode
sub setup {
	my $self=shift;
	#Test that the caller is not the template package
	Log::OK::DEBUG and log_debug("Template::Plex::Base: Setup Template: ".$self->meta->{file});
	if($self->[meta_]{package} eq caller){
		#Log::OK::ERROR and log_error("Template::Plex::Base: setup must only be called outside a template: ".$self->meta->{file});
		#		return;
	}
	$self->[init_done_flag_]=undef;
	$self->render(@_);
}



sub DESTROY {
	delete_package $_[0][package_] if $_[0][package_];
}

#Internal testing use only
sub __internal_test_proxy__ {
	"PROXY";
}

1;

__END__

=head1 NAME

Template::Plex::Base -  Extendable template base class

=head1 SYNOPSIS

	##Creating a subclass file
	#
	package MY::SUB::Class

	use parent "Template::Plex::Base"
	
	sub my_facny_method(){
		"something to return"
	}

	1;


	###In your template file - using your subclass methods
	#
	This temlplate uses a custom base class so it can call custom methods like
	this: @{[$self->my_fancy_method]}.
	
	Or even like this: ${\$self->my_fancy_method}



	##Main file - Loading your template with the right baseclass
	#
	use Template::Plex;

	my %args=(some=>"args", go=>"here");
	my $template=plex $path_to_template  \%args, base=>"MY::SUB::Class"


	

=head2 DESCRIPTION

This is the base class wrapping the internals of L<Tempalte::Plex> into a nicer
interface. It facilitates hooking into critical stages of template preparation.

It does not provide a way to modify how the templates are loaded (parsed etc),
as this is done at a lower level.



=head1 API

This API is mainly used in implementing a template class, NOT within a
template. While you can use some of them from within a template, there are
already nicer ways to achieve the same result

=head2 new

	
This currently is only called internally from L<Template::Plex> only. It take
the internal object as its argument to store.


=head2 Initialisation methods

When a template uses an init block, the base class is called with the block/sub
as an argument. So this:
	
	@{[
		init {...}
	]}

internally becomes:

	$self->_init {...}

The C<_init> method is not intended to be overridden however provides three
stages to override:

=over

=item C<pre_init>

A method which currently does nothing but is designed to be overridden in a subclass.  

=item C<{...}> User block

This is block specified in the template using C<init>. It is executed immediately after C<pre_init>

=item C<post_init>

Finally the C<post_init> method is called. Currently it does nothing, but again is designed to be overridden

=back

After the initialisation stages have run, a initialisation flag is set and the
remainder on the template is skipped with the C<skip> method.

This means only the first C<init> block in a template will be executed


=head2 C<render>

	$template->render($fields);

This object method renders a template object created by C<plex> into
a string. It takes an optional argument C<$fields> which is a reference to a
hash containing field variables. C<fields> is aliased into the template as
C<%fields> which is directly accessible in the template

	eg
		my $more_data={
			name=>"John",
		};

		my $string=$template->render($more_data);
		
		#Template:
		My name is $fields{John}

Note that the lexically aliased variables setup in C<plex> or C<plx> are
independent to the C<%fields> variable and can both be used simultaneously in a
template


=head2 C<setup>

	$template->setup;

Forces template to render in initialisation mode.

If a template does not have a C<init{}> block, this is equivalent to calling
C<$template->render> directly.

If a template does have a C<init{}> block, the template is executed up to the
end of the first C<init {}> block. An empty string is returned. An explicit
C<$template-E<gt>render> call is need to subsequently render the template.

	
The C<plx> template directive automatically performs a C<setup> call after the
template is loaded.  (see L<Template::Plex> for more details)


=head2 C<skip>

Causes the template to immediately finish, with an empty string as result.
From within a template, either the class method or template directive can be used:

	@{[$self->skip]}
		or
	@{[skip]}

=head2 C<meta>

Returns the options hash used to load the template.  From within a template, it
is recommended to use the C<%options> hash instead:

	@{[$self->meta->{file}]}
		or
	@{[$options{file}]}

This can also be used outside  template text to inspect a templates meta information

	$template->meta;

=head2 C<args>

Returns the argument hash used to load the template.  From within a template,
it is recommended to use the aliased variables or the C<%fields> hash instead:

	@{[$self->args->{my_arg}]}
		or
	@{[$fields{my_arg}]}

		or
	$my_arg


This can also be used outside template text to inspect a templates input variables

	$template->args;

=head1 SUB CLASSING

Sub classing is as per the standard perl C<use parent>. The object storage is
actually an array.  

Package constants are defined for the indexes of the fields along with
C<KEY_OFFSET> and C<KEY_COUNT> to aid in added extra fields in sub classes.

If you intend on adding additional fields in your class you will need to do the
following as the object

	use parent "Template::Plex::Base";

	use constant KEY_OFFSET=>Template::Plex::Base::KEY_OFFSET+ Template::Plex::Base::KEY_COUNT;

	use enum ("first_field_=".KEYOFFSET, ..., last_field_);
	use constant  KEY_COUNT=>last_field_ - first_field_ +1;

Any further sub classing will need to repeat this using using your package name.


=head1 AUTHOR

Ruben Westerberg, E<lt>drclaw@mac.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2022 by Ruben Westerberg

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, or under the MIT license

=cut
