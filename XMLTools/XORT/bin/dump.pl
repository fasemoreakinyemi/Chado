#!/usr/local/bin/perl

# --------------------------
# XMLValidator and XMLParser need to run separately !!!! otherwise, it will not run the load() !
# ---------------------------

use lib $ENV{CodeBase};

use XORT::Util::GeneralUtil::Properties;
use XORT::Dumper::DumperXML;
use XORT::Util::DbUtil::DB;
use Getopt::Std;
use strict;

#set the start time
my $start=time();

my $LOCAL_ID="local_id";
my $NO_LOCAL_ID='xml';
my $MODULE="module";
my $SINGLE="single";

# switch to set how to dump referenced object: unique_keys(not loadable) or cols(loadable)
my $REF_OBJ_UNIQUE='0';
my $REF_OBJ_ALL='1';

my %opt;
getopts('h:s:d:t:f:o:p:b:g:l:a:', \%opt) or usage() and exit;

usage() and exit if $opt{h};


usage() and exit if (!$opt{d} || !$opt{p});

$opt{o}='' if !(defined $opt{o});
$opt{f}=$LOCAL_ID if !($opt{f});
$opt{s}=$SINGLE if !( $opt{s});
$opt{l}=$REF_OBJ_UNIQUE if !( $opt{l});
$opt{b}=0 if !(defined $opt{b});

#option: s(dumpspec) d(database) -t (tables) -f(format_type) -o(operator) -p(output file)

 my $xml_obj=XORT::Dumper::DumperXML->new($opt{d}, $opt{b});
$xml_obj->Generate_XML(-tables=>$opt{t},-file=>$opt{p}, -struct_type=>$opt{s}, -format_type=>$opt{f}, -op_type=>$opt{o}, -dump_spec=>$opt{g}, -loadable=>$opt{l}, -app_data=>$opt{a});


my $end=time();
print "\n$0 started:", scalar localtime($start),"\n";
print "\n$0   ended:", scalar localtime($end),"\n";



sub usage()
 {
  print "\nusage:$0 [-d chado_gadfly7] [-p output] [-f format_type] [-t tables] [-o op_type] [-g dumpspec] [-s struct_type] [r loadable]",

    "\n -h              : this (help) message",
    "\n -d              : database",
    "\n -p file         : output xml file",
    "\n -f format_type  :local_id/no_local_id",
    "\n -t tables       :which table(s) to be dumped",
    "\n -o op_type      :'' /force/delete/update/insert/lookup",
    "\n -g dumpspec     :dumpspec xml file which guide the dumper behavior",
    "\n -s struct_type  :module/single(default)",
    "\n -b debug        : 0:no debug message(default), 1:debug message",
    "\n -l loadable     :1 for loadable, 0 for non_loadable",
    "\n -a app_data     :app data for dumpspec if using variable in dumpspec, separate by space for multvalue",
    "\n if you provide dumpspec, struct_type, loadable and tables will be ignored",
    "\n\nexample1: $0  -d chado_gadfly7 -g \"/users/zhou/work/API/XORT/Config/dumpspec_gene.xml\" -p \"/export/zhou/dump_gene_no_local_id.xml\" -f no_local_id -b 1 ",
    "\n\nexample2: $0  -d chado_gadfly7 -g \"/users/zhou/work/API/XORT/Config/dumpspec_scaffold.xml\" -p \"/export/zhou/dump_scaffold_local_id.xml\" -f local_id -a \"1 14473012 14476172 AE002603\" -b 1",
    "\n\nexample3: $0  -d chado_test -p /export/zhou/dump_temp_local_id.xml -f local_id -o force -s module -t \"feature:cvterm\"\n\n";
}
