#!/usr/bin/env perl

use GraphViz;
use XML::NestArray qw(:all);
use Bio::XML::Sequence::Transform;
use Getopt::Long;

use FileHandle;
use strict;
use warnings;
use Data::Dumper;

my @valid_fmts = qw(png gd pic ps gd mif pcl gd2 jpeg vrml svg);
my $loc;
my $out;
my %style;
my $conf;
my $fmt = 'png';
my $phen;
my $view;
my $fontsize = 10;
my $horizontal = 0;
my %graphvizopts = ();
GetOptions(
           "loc|l"=>\$loc,
           "phen|p"=>\$phen,
           "out|o=s"=>\$out,
           "style|s=s%"=>\%style,
           "conf|c=s"=>\$conf,
           "view|v"=>\$view,
           "gv=s%"=>\%graphvizopts,
           "horizontal"=>\$horizontal,
           "fontsize=s"=>\$fontsize,
          );
my @font_args = ();
push(@font_args, "fontsize"=>$fontsize) if $fontsize;
my $cnf = Node([]);
if ($conf) {
    $cnf->parse($conf);
}
if (%style) {
    map {
        $cnf->set($_, $style{$_});
    } keys %style;
}
my $fn = shift @ARGV;

my $T = Bio::XML::Sequence::Transform->new();
$T->parse($fn);

my $g = GraphViz->new(rankdir=>$horizontal, %graphvizopts);

# add genes
my @genes = map {Node(gene=>$_)} $T->get_gene;
map {
    $g->add_node($_->sget_dbxref,
                 label=>get_glabel($_),
                 @font_args,
                 shape=>$cnf->sget_geneshape || 'box',
                 style=>'filled',
                 fillcolor=>$cnf->sget_genefillcolor || '#FF8888',
                 cluster=>$_->sget_dbxref,
                )
} @genes;

# add features
my @features = $T->findSubTree("feature");
map {
    my $cluster;
    my @genexrefs = $_->findSubTreeVal("gene");
    foreach my $gx (@genexrefs) {
        $cluster = $gx;
        $g->add_edge($_->sget_dbxref, $gx, 
                     label=>sprintf('gene'),
                     @font_args,
                     style=>$cnf->sget_genefeaturestyle || 'dashed',
                     cluster=>$cluster,
                    );
    }
    $g->add_node($_->sget_dbxref,
                 label=>get_flabel($_),
                 @font_args,
                 style=>'filled',
                 fillcolor=>$cnf->sget_featurefillcolor || 'green',
                 cluster=>$cluster,
                );
} @features;
my @frs = $T->findSubTree("feature_relationship");
map {
    $g->add_edge($_->sget_subjfeature => $_->sget_objfeature,
                 @font_args,
                 label=>$_->sget_type);
} @frs;

# show locations
if ($loc) {
    map {
        my ($dbxref, $src, $fmin, $fmax, $fstrand) = 
          $_->getl(qw(dbxref source_feature fmin fmax fstrand));
        my $ssym = $fstrand < 0 ? "-" : "+";
        print ":: $dbxref $src $fmin $fmax\n";
        if ($src) {
            $g->add_edge($dbxref, $src, 
                         label=>sprintf('%s..%s[%s]',
                                        $fmin, $fmax, $ssym),
                         @font_args,
                         style=>$cnf->sget_locedgestyle || 'dotted',
                        );
        }
    } @features;
}


my $next_id = 1;

# show analysisresults
sub show_analysisresult {
    my $ar = shift;
    my $anname = shift;
    my $parent = shift;
    $ar->set_id("analysisresult_".$next_id++);
    $g->add_node($ar->sget_id,
		 label=>get_resultlabel($ar),
		 @font_args,
		 style=>'filled',
		 fillcolor=>$cnf->sget_analysisresultfillcolor || 'cyan',
		 cluster=>$anname,
		);
    if ($parent) {
	$g->add_edge($ar->sget_id, $parent->sget_id,
		     label=>sprintf('parent'),
		     @font_args,
                     style=>$cnf->sget_genefeaturestyle || 'dashed',
                     cluster=>$anname,
                    );
    }
    else {
	$g->add_edge($ar->sget_id, $anname, 
		     label=>sprintf('analysis'),
		     @font_args,
                     style=>$cnf->sget_genefeaturestyle || 'dashed',
                     cluster=>$anname,
                    );
    }
    my @locs = $ar->gettree("resultlocation");
    foreach my $loc (@locs) {
	$g->add_edge($ar->sget_id,
		     $loc->sget_srcfeature,
		     label=>'loc',
		     @font_args,
                     style=>$cnf->sget_genefeaturestyle || 'dashed',
		    );
    }
}
my @ans = $T->findSubTree("analysis");
foreach my $an (@ans) {
    my $anname = $an->sget_name;
    $g->add_node($anname,
                 label=>get_anlabel($an),
                 @font_args,
                 shape=>$cnf->sget_analysisshape || 'box',
                 style=>'filled',
                 fillcolor=>$cnf->sget_genefillcolor || 'red',
                 cluster=>$anname,
                );
    my @aresults = $an->findSubTree("analysisresult");
    foreach my $ar (@aresults) {
	show_analysisresult($ar, $anname);
	my @subresults = 
	  grep {
	      $_->name eq "analysisresult"
	  } $ar->children;
	map {
	    show_analysisresult($_, $anname, $ar);
	} @subresults;
    }
}

if ($phen) {
    my @phenotypes = $T->fst("phenotype");
    my ($pcnf) = $cnf->fst("phenotype");
    $pcnf = Node() unless Node();
    foreach my $p (@phenotypes) {
        $g->add_node($p->sget_dbxref,
                     label=>get_plabel($p),
                     @font_args,
                     style=>'filled',
                     fillcolor=>$pcnf->sget_fillcolor || '#8888FF',
                    );
        my @fps = $p->findSubTree("feature_phenotype");
        foreach my $fp (@fps) {
            $g->add_edge($p->sget_dbxref, $fp->sget_feature, 
                         label=>sprintf('gene'),
                         @font_args,
                         style=>$pcnf->sget_featurelinkstyle || 'dashed',
                        );
        }
    }
}

my $ofh = \*STDOUT;
my $is_out_a_tempfile;
if ($view && !$out) {
    $is_out_a_tempfile = 1;
    $out = $$.".tmp.$fmt";
}
if ($out) {
    if ($out =~ /\.(w+)$/) {
        my $nu_fmt = $1;
        if (grep {$nu_fmt eq $_} @valid_fmts) {
            $fmt = $nu_fmt;
        }
    }
    $ofh = FileHandle->new(">$out") || die($out);
}
my $meth = 'as_'.$fmt;
print $ofh $g->$meth();
$ofh->close if $out;
if ($view) {
    system("display $out");
}

END {
    if ($is_out_a_tempfile) {
        unlink($out);
    }
}

# --

sub get_flabel {
    my $f = shift;
    sprintf("%s",
            join("\n",
                 map {"$_:".$f->sget($_)} qw(dbxref name ftype)));
}
sub get_anlabel {
    my $f = shift;
    sprintf("%s",
            join("\n",
                 map {"$_:".$f->sget($_)} qw(name program sourcename)));
}
sub get_resultlabel {
    my $f = shift;
    sprintf("%s",
            join("\n",
                 map {"$_:".$f->sget($_)} qw(score significance)));
}
sub get_glabel {
    my $f = shift;
    sprintf("%s",
            join("\n",
                 map {"$_:".$f->sget($_)} qw(dbxref name)));
}
sub get_plabel {
    my $p = shift;
    my @terms = $p->findSubTreeVal("termname");
    sprintf("%s",
            join("\n",
                 map {"$_:".$p->sget($_)} qw(dbxref),
                @terms),
           );
}
