use HTML::TreeBuilder;
use strict;
use Data::Dumper;
use LWP::UserAgent;
use File::Slurp;

my $ua = LWP::UserAgent->new;

my $seed = "https://pubseed.theseed.org";

my $res = $ua->get("$seed/SubsysEditor.cgi");

if (!$res->is_success)
{
    die "Error retrieving data";
}

my $tree = HTML::TreeBuilder->new_from_content($res->content);
open(F, ">", "dump");
$tree->dump(\*F);
close(F);
my $n = $tree->look_down('id', 'table_data_0');

my $val = $n->attr('value');

my @rows = split(/\@\~/, $val);

for my $row (@rows)
{
    my($c1, $c2, $nlink, $vers, $mod, $curator) = split(/\@\^/, $row);
    my($name) = $nlink =~ m,>(.*?)</A,;
#    die Dumper($row, $name, $c1, $c2, $curator, $vers);
    print join("\t", $name, $c1, $c2, $curator, $vers, $mod), "\n";
#    last if $name;
}
    
