use feature ":all";
use warnings;
#use strict;
#no warnings "uninitialized";
use Template::Plex;
use Data::Dumper;
use File::Basename qw<dirname>;
use File::Spec::Functions qw<rel2abs>;

my @items=qw<eggs watermellon hensteeth>;
my $hash={
	title=>"Mr",
	surname=>"chick"
};

my $root=dirname __FILE__;

say "Root dir: $root";
my $template=plex("external.plex", $hash, $root);

say $template->();
$hash->{title}="GOGO";
say $template->();


$template=plex(\*DATA,$hash, $root);
say $template->();
say $template->({title=>"KING"});
say $template->({title=>"KONG"});

__DATA__
An inline data template with title $title and surname $surname
Field access $fields{title}
@{[do{
	say "ROOT IS: ", $root;
	say %fields;
	state $t=plex("header.plex",\%fields,$root);
	say "STATE IS: $t";
	$t->();
}]}
