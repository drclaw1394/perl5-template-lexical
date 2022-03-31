package Template::Plex;
use strict;
use warnings;

use Symbol qw<delete_package>;
use Carp qw<carp croak>;
use version; our $VERSION = version->declare('v0.2.0');
use feature qw<say state refaliasing lexical_subs>;
no warnings "experimental";

#use File::Basename qw<dirname basename>;
use File::Spec::Functions qw<catfile>;
use Exporter 'import';
#use Data::Dumper;


our %EXPORT_TAGS = ( 'all' => [ qw( plex plx  block pl plex_clear jmap) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	plex
	plx
);

my $Include=qr|\@\{\s*\[\s*include\s*\(\s*(.*?)\s*\)\s*\] \s* \}|x;

use constant KEY_OFFSET=>0;
use enum  ("package_=".KEY_OFFSET, qw<sub_>);
use constant KEY_COUNT=>sub_-package_+1;


sub new;	#forward declare new;

sub lexical{
	my $href=shift;
	die "NEED A HASH REF " unless  ref $href eq "HASH" or !defined $href;
	$href//={};
	\my %fields=$href;

	my $string="";
	for my $k (keys %fields){
		$string.= "\\my \$$k=\\\$fields{$k};\n";
	}
	$string;
}

sub  bootstrap{
	my $self=shift;
	\my $_data_=\shift;
	my $href=shift;
	my %opts=@_;

	$href//={};
	\my %fields=$href;

my $out="package $opts{package} {";

$out.= '	\my %fields=$href;
';
$out.='		my %options=%opts; 
' if keys %opts;

$out.=lexical($href);		#add aliased variables	from hash
$out.='
	my $prepare=sub {
		my ($self,undef, $href,%opts)=@_;
		$href//={};
		\my %fields=$href;
		';
	#need this to prevent variables going out of scope
	#and avoid warnings
	for my $k (keys %fields){
		$out.= "1 or \$$k;\n";
	}

$out.='
		use Template::Plex qw<pl block plex_clear jmap>;
		use String::Util qw<:all>;
		my $ref=eval Template::Plex::bootstrap (@_);
		if($@ and !$ref){
			print  $@;
			print  $!;
		}
		$self->[Template::Plex::sub_]=$ref;
		$self;
	};

	my %cache;	#Stores code refs using caller as keys

	#lexical plex changes the prepare and also reuses options with out making it explicit
        my sub plex{
                my ($path, $vars, %opts)=@_;


                #unshift @_, $prepare;  #Sub templates now access lexical plex sub routine
                                        #with access to its scoped $prepare sub and variables
                my $template=Template::Plex->new($prepare,$path,$vars,%opts?%opts:%options);
                $template;


        }
	my sub plx {
		my ($path,$vars,%opts)=@_;

		my $id=$path.join "", caller;
		$cache{$id} and return $cache{$id}->render;
		
		my $template=&plex;
		#Template::Plex->new($prepare,$path,$vars,%opts?%opts:%options);
		#TODO: check for errors
		
		$cache{$id}//=$template;
		$template->render;
	}
	my sub plex_clear {
		%cache=();
	}

sub {
	no warnings \'uninitialized\';
	no strict;
	my $self=shift;
	\\my %fields=shift//\\%fields;
	qq{'.$_data_.'};

}
};';
my $line=0;
#say map { $line++ . $_."\n"; } split "\n", $out;
$out;
};

# First argument the template string/text. This is any valid perl code
# Second argument is a hash ref to default or base level fields
# returns a code reference which when called renders the template with the values
sub _prepare_template{
	my ($self, undef, $href, %opts)=@_;
	$href//={};
	\my %fields=$href;

 	my $ref=eval &Template::Plex::bootstrap;
	if($@ and !$ref){
		print  STDERR "EVAL: ",$@;
		print  STDERR "EVAL: ",$!;
	}
	$self->[Template::Plex::sub_]=$ref;
	$self;
}

sub render {
	$_[0][sub_](@_);
}

sub sub {
	$_[0][sub_];
}

sub DESTROY {
	delete_package $_[0][package_] if $_[0][package_];
}

#a little helper to allow 'including' templates into each other
sub _munge {
	my ($input, %options)=@_;

	#test for literals
	my $path;	
	if($input =~ /^"(.*)"$/){
		#literal		
		$path=$1;	
	}
	elsif($input =~ /^'(.*)'$/){
		#literal		
		$path=$1;	
	}
	else {
		#not supported?
		#
	}

	plex($path,"",%options);
}

sub _subst_inject {
	\my $buffer=\(shift);
	while($buffer=~s|$Include|_munge($1, @_)|e){
		#TODO: Possible point for diagnostics?
	};
}
sub _block_fix {
	#remove any new line immediately after a ]} pair
	\my $buffer=\(shift);
	while($buffer=~s/^\]\}\n/]}/gms){
	}
}
my $prepare=\&_prepare_template;

#load a template to be rendered later.
# Compiled once but usable multiple times
sub plex{
	my ($path,$vars,%opts)=@_;
	#unshift @_, $prepare;	#push current top level scope
	my $template=Template::Plex->new($prepare,$path,$vars,%opts);
	$template;
}

my %cache; #toplevel cache
#Load template and render in one call. Easy for on offs
sub plx {
	my ($path,$vars,%opts)=@_;
	my $id=$path.join "", caller;
	$cache{$id} and "exisiting !" and return $cache{$id}->render;
	my $template=&plex;

	#TODO: check for errors
	
	$cache{$id}//=$template;
	$template->render;
}

sub plex_clear {
	#say join "\n", keys %cache;
	%cache=();
}


sub block :prototype(&) {
	$_[0]->();
	return "";
}
*pl=\*block;



sub new{
	my $self=bless [], shift;
	my ($prepare, $path, $args, %options)=@_;
	my $root=$options{root};
	#croak "plex: even number of arguments required" if (@_-1)%2;
	croak "plex: first argument must be defined" unless defined $path;
	#croak "plex: at least 2 arguments needed" if ((@_-1) < 2);

	my $data=do {
		local $/=undef;
		if(ref($path) eq "GLOB"){
			#file handle
			<$path>;
		}
		elsif(ref($path) eq "ARRAY"){
			#process as inline template
			join "", @$path;
		}
		else{
			#Assume a path
			#Prepend the root if present
			$path=catfile $root, $path if $root;
			my $fh;
			if(open $fh, "<", $path){
				<$fh> 
			}
			else {
				carp "Could not open file: $path $!";
				"";
			}


		}
	};

	$args//={};		#set to empty hash if not defined
	
	chomp $data;
	#Perform inject substitution
	_subst_inject($data, root=>$root) unless $options{no_include};
	#Perform suppurfluous EOL removal
	_block_fix($data) unless $options{no_block_fix};
	if($args){
		#Only call this from top level call
		#Returns the render sub

		state $package=0;
		$options{package}//="Template::Plex::temp".$package++;#force a unique package if non specified
		$prepare->($self, $data, $args, %options);	#Prepare in the correct scope
	}
	else {
		$data;
	}
}

#Join map
sub jmap :prototype(&@){
	my $sub=shift;	#block is first
	my $data=pop;	#Data is last
	my $delimiter=shift//"";	#delimiter is whats left
	join $delimiter, map &$sub, ($data//[])->@*;
}

1;
