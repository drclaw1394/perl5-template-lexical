package Template::Lexical;
use strict;
use warnings;
use version; our $VERSION = version->declare('v0.1.0');
use feature qw<say refaliasing>;
no warnings "experimental";

use Exporter 'import';


our %EXPORT_TAGS = ( 'all' => [ qw( prepare_template slurp_template) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	prepare_template	
	slurp_template
);

# First argument the template string/text. This is any valid perl code
# Second argument is a hash ref to default or base level fields
# returns a code reference which when executed returns anything that perl ca
sub prepare_template{
	\my $data=\shift;
	my $href=shift;
	die "NEED A HASH REF " unless  ref $href eq "HASH" or !defined $href;
	$href//={};
	\my %fields=$href;	#hash ref

	my $string="";
	#make lexically available aliases for all keys currently defined in the input
	for my $k (keys %fields){
		$string.= "\\my \$$k=\\\$fields{$k};\n";
	}
	$string.=
	"sub {\nno warnings 'uninitialized';\n"
	."\\my %fields=shift//\\%fields;\n"
	."qq{$data}; };\n";
	say $string;
	my $ref=eval $string;
	if($@ and !$ref){
		print  $@;
		print  $!;
	}
	$ref;
}

sub _subst_inject {
	\my 	$buffer=\$_[0];
	say "processiing $buffer";
	while($buffer=~s|\@\{\[\s*inject\("(\w+)"\)\]\}|slurp_template("$1.tpl")|e){
		
	}
}

#Read an entire file and return the contents
sub slurp_template{
	my $path=shift;
	#my $args=shift;
	do {
		local $/=undef;
		if(open my $fh, "<", $path){
			my $data=<$fh>;
			_subst_inject($data);
			$data;
		}
		else {
			say "Error slurpping";
			"";
		}
	}
}

1;
__END__

=head1 NAME

Template::Lexical - Perl base template using lexical aliasing

=head1 SYNOPSIS

  use Template::Lexical;
  my $base_data={name=>"James", age=>"12", fruit=>"banana"};
  my $template = '$name\'s age $age and favourite fruit is $fruit';
  my $render=prepare_template($template,$base_data);
  
  $render->();		#renders with base values. 
  #James's age is 12 and favourite fruit is banana

  $base_data->{qw<name,fruit>}=qw<John apple>;
  $render->();		#render with updated base values
  #John's age is 12 and favourite fruit is apple



=head1 DESCRIPTION

Uses perl itself as a template language to generate text, array, hashes, or
anything perl can return from a subroutine.

A template is valid perl code contained in literal quotes (ie C<''> C<q()> et
al). Like always the last statement will be the returned.

	'"This template is a string"'

	q|"So is this one"|

	q|sub { "This template returns a code reference" }|

Because the template is perl code, all the loop and control constructs are
available. Here is a template that renders an array of numbers form the field
called C<$data>:

       my $template='my $s="";
	for($data->@*){
		s.="Number: $_\n";	
	}
	$s;
       ';

Data to apply to the template is provided as a hash reference

	my $base_data={
		data=>[1,2,3,4]
	};


To use a this template it must be prepared using C<prepare_template>. What is
returned from this is the renderer code reference which when called actually
renders your template. Very simple and powerful.
	
	my $render=prepare_template $template, $base_data; 	#create a renderer

	my $result=$render->();				#actuall render

=head2 LEXICAL ALIASING

Any keys present in the hash when C<prepare_template> is called are used to
construct lexical variables which are aliases to the hash elements of the same
key name. The hash itself is also aliased to a variable called C<%fields>

So for a C<$base_data> hash like this:

	my $base_data={name=>"jimbo", age=>10};

The template can access the fields "name" and age like this:

	my $template='my name is $name an I am $age';

or like this:
	
	my $template='my name is $fields{name} and I am $fields{age}';

The first version uses the lexical variables skips the hash lookup, which gives
higher rendering rates.  The caveat is that all fields must exist at the time
the template is prepared.

To change the values and render the template the same C<$base_data> variable
must be manipulated. ie

	$base_data->{name}="Tim";
	$render->();

This still requires no hash lookups in the rendering and is a very quick way of
rendering the changing data.


=head2 ARBITARY FIELD ACCESS

If the data to apply to the template completely changes, it can be passed as a
hash ref to the render code reference.

	my $new_variable={name=>data};
	$render->($new_variable);

However to use this data the template must be constructed to access the fields
directly:

	my $template='my name is $fields{name} and I am $fields{age}';

=head2 HYBRID ACCESS

This is interesting. The template can refer to the lexical aliases and the
direct fields at the same time. The lexical aliases only refer to the data
provided at preparation time, while the field refer to the latest data
provided:

	my $template='my name is $fields{name} and I am $age
	my $base_data={name=>"jimbo", age=>10};
	my $override_data={name=>"Eva"};

	my $render=prepare_template $template, $base_data;
	my $string=$render($override_data);
	#string will be "my name is Eva and I am 10

=head2 EXPORT

	prepare_template $tempate, $hash_ref

This is the only subroutine exported.  It takes the template text (perl code
wrapped in literal quotations) as the first argument.

The second (optional) argument is a hash reference to a hash containing the
base data to alias in to lexical variables. The hash itself is also aliased
into a variable called C<%fields> to allow direct access.

It returns a code reference which when executed renders the template

=head1 SECURITY

This module uses C<eval> to generate the code ref for rendering. This means
that your template, being perl code, is being executed. If you do not know what
is in your templates, then maybe this module isn't for you.

To mitigate the security risk, the rendering code refs should be generated  and
cached, so they are not needing to be run during normal execution. That will
provide faster rendering and also, prevent unknown templates from accidentally
being executed.


=head1 SEE ALSO

Yet another template module right? Pretty sure this is the smallest one and
render not just text.


=head1 AUTHOR

Ruben Westerberg, E<lt>drclaw@mac.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2021 by Ruben Westerberg

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, or under the MIT license

=cut
