#--------------------------------------------------------------------#
#
#   project:  gbtiler 2.0
#  filename:  TilerArguments.pm
#   created:  2002-11-21
#  modified:  2007-03-05
#
#...;....1....;....2....;....3....|....4....;....5....;....6....;....7



#--------------------------------------------------------------------#
#
#  SYNOPSIS:
#
#  This Perl module of the Gerber tiler contains routines
#
#
#     +  to parse command line arguments for gbtiler,
#
#     +  to read and parse gbtiler arguments from external files,
#
#     +  to build a hash table data structure to hold one or more
#        layers of gerber and NC drill files being tiled and or
#        combined.
#
#
#
#  GBTILER OPTIONS:
#
#  --argfile [filename]      name of file of additional options.
#                            Multiple argument files may be specified
#                            on the command line which invokes gbtiler
#                            but --argfile tags in external arguments
#                            files are basically ignored.  In typical
#                            use, only one external argument file
#                            should be needed anyway.
#
#  --gerberfile [filename]   filename of Gerber source file to tile.
#
#  --drillfile [filename]    filename of NC drill file to tile.
#
#  --rackfile [filename]     filename of rack or tool file to
#                            accompany a given NC drill file.
#
#  --outfile [filename]      output file name for tiled layer which
#                            may be either a tiling of RS274X Gerber
#                            files or a tiling of NC drill files, but
#                            not a mix of both.
#
#  --path  [pathname]        path to prepend to all files up to next
#                            --path option.  This option makes it
#                            easier to include files to tile that are
#                            located in different directories.  When
#                            encountered, the script updates an
#                            variable as it builds the hash of circuit
#                            board layers to tile.
#
#
#  GLOBAL GBTILER OPTIONS:
#
#  The following gbtiler options normally would only appear once in
#  a list of arguments directing the processing work of gbtiler:
#
#  --offset [n.n,n.n]        offset to apply to input file data,
#                            where n.n represent a real value whose
#                            precision is limited practically to the
#                            resolution of the board producing house,
#                            and whose resolution is limited
#                            programmatically to the precision of
#                            floating point supported by the end-
#                            user's version of Perl.
#
#  --leading_zeroes [n]      toggles leading zero formatting on
#                            and off. Not yet fully implemented
#                            in gbtiler 2.0.
#
#  --trailing_zeroes [n]     toggles trailing zero formatting on
#                            and off.
#
#  --x_integer_digits [n]    output file coordinate formatting,
#                            n is an integer value between 1 and 6
#                            inclusive.  This description of n
#                            applies to the remaining global
#                            arguments in this list.
#
#  --x_decimal_digits [n]    output file coordinate formatting,
#
#  --y_integer_digits [n]    output file coordinate formatting,
#
#  --y_decimal_digits [n]    output file coordinate formatting.
#
#
#
#  VERSION 2.0 GLOBAL OPTIONS:
#
#  --created_by [program name]   not yet implemented, and may not be
#                                needed for external drill rack
#                                processing.
#
#  --drill_substitution ["apc"]  this option currently toggles on and
#                                off a limited drill size substituting
#                                routine which tries to simplify the
#                                set of drills used in a file to the
#                                seven standard drills available at
#                                Alberta Printed Circuits, Inc.
#                                Drill sizes outside this set add
#                                extra charges to the cost of
#                                producing a board.
#
#--------------------------------------------------------------------#





package TilerArguments;
use strict;

#use lib qw(/home/ted/lib/perl);
use Diagnostic;

our $self = {};

#====================================================================#
#                                                                    #
#   Constructor:                                                     # 
#                                                                    #
#====================================================================#

sub new
{

## The data structure for this Perl package is an anonymous,
## complex hash:

   my ($class) = @_; 
   $self =

   {
      projectName => 0,    # name of project to which this package
                           # belongs

      packageName => 0,    # name of this package

      diagnostic  => 0,    # reference to a diagnostics package

      trace       => {},   # a sub-hash of flags for tracing and
                           # and diagnostics generation on a
                           # per-routine basis



      lines       => 0,    # from tiler arguments file

      arguments   => 0,    # to tiler program

      argCount    => 0,    # count of gbtiler arguments

      argIndex    => 0,    # index of current gbtiler argument

      separator   => 0,    # directory and file delimiting character

      job         => {},   # a hash of output layers, which in turn
                           # are hashes of gerber and NC drill files
                           # which are themselves hashes of filenames,
                           # offsets, file statae and notes.
   };


#--------------------------------------------------------------------#
#  Initialize some object data:
#--------------------------------------------------------------------#

   $self->{package} = "TilerArguments.pm";
   $self->{identify} = 0;

   $self->{trace}{new}                      = 0;
   $self->{trace}{initialize}               = 0;
   $self->{trace}{process_arguments}        = 0;
   $self->{trace}{read_argument_file}       = 0;
   $self->{trace}{build_job_tree}           = 0;
   $self->{trace}{check_job_tree_integrity} = 1;
   $self->{trace}{current_job}              = 0;


   $self->{lines}     = ();    # array
   $self->{arguments} = ();    # array
   $self->{argCount}  = 0;     # integer
   $self->{argIndex}  = 0;     # integer
   $self->{separator} = "/";   # string

   $self->{job}{name}          = "DEFAULT_JOB_NAME";   # string
   $self->{job}{status}        = "not started";        # string
   $self->{job}{path}          = "./";                 # string
   $self->{job}{workDirectory} = "./workspace/";       # string
   $self->{job}{layerCount}    = 0;                    # integer
   $self->{job}{notes}         = "";                   # string

   $self->{job}{format}{leadingZeroes}  = 1;   # integer as boolean
   $self->{job}{format}{trailingZeroes} = 1;   # integer as boolean
   $self->{job}{format}{xIntegerDigitsRequested} = 2;   # integer
   $self->{job}{format}{xDecimalDigitsRequested} = 5;   # integer
   $self->{job}{format}{yIntegerDigitsRequested} = 2;   # integer
   $self->{job}{format}{yDecimalDigitsRequested} = 5;   # integer


## In addition to the keys named above within the 'job' hash key,
## there will normally be one or more layer keys whose names begin
## with the pattern 'layer_', for example layer_top, layer_bottom,
## layer_drill, layer_0001.



#--------------------------------------------------------------------#
#  Let the data structures of this object know their class:
#--------------------------------------------------------------------#

   bless($self, $class); 

   return $self;

}






#====================================================================#
#                                                                    #
#   Data access methods:                                             # 
#                                                                    #
#====================================================================#


sub initialize
{
#--------------------------------------------------------------------#
#
#  RECEIVE:
#
#     *  a reference to a diagnostics object
#     *  an OPTIONAL debug string to enable/disable routine tracing
#
#  RETURN:   nothing
#
#  PURPOSE:  
#
#--------------------------------------------------------------------#

   my $self  = shift;
   my $rname  = "initialize";
   my $debug_mode = "";
   my $trace = 0;



#--------------------------------------------------------------------#
#  Set a reference to a diagnostics package:                         #
#--------------------------------------------------------------------#

   if (@_)
   {
      $self->{diagnostic} = shift;
   }
   else
   {
      print "   $rname:  ERROR...\n";
      print "   $rname:  In an instance of $self->{package} package,\n";
      print "   $rname:  received no reference to 'Diagnostics' \n";
      print "   $rname:  package instance.\n\n";
   }

}





sub process_arguments
{

#--------------------------------------------------------------------#
#  2004-07-04
#
#  This routine will be the one that normally gets called by external
#  scripts, and it in turn carries out the following tasks by calling
#  local routines within this script.
#
#   1) load arguments from command line and additional argument files,
#   2) parse arguments and build tiling job hash table,
#   3) check integrity of job hash table
#   4) if there are inconsistencies in the job hash table, report them
#
#--------------------------------------------------------------------#


##  When this routine is called from outside this package, the
##  following line sets the pointer $self to the the variables and
##  data structures of the running instance of this script:

    my $self = shift; 


##  Declare and initialize local variables:

    my $argCount = 0;      # integer
    my @arguments = ();    # array

    my $rname = "process_arguments";
    my $trace = $self->{trace}{$rname};
    my $msg = "";
    my ($argument); 



##  So after the script reference is popped off some kind of Perl
##  built-in stack, parameters passed from the caller can be locally
##  copied or referenced.  If Perl's default 'routine parameter array'
##  contains data, then treat that data as an array of strings, and
##  test for a count of strings greater than zero.  We expect to find
##  this, as this represents the list of processing arguments to
##  gbtiler.  If we don't find this data, something is wrong, and the
##  IF block below reports this error.
## -------------------------------------------------------------------

   if (@_)
   {
      $self->{arguments} = shift;
      $self->{argCount} = @{$self->{arguments}};     # get the array count

      if ($trace)
      {
         $msg = "$rname:  received '$self->{argCount}' arguments from an external calling routine.\n";
         $msg .= "$rname:  passed arguments array contains...\n\n";
         print $msg;
         $self->{diagnostic}->show_tokens($self->{arguments}, "arg list passed from stub driver");
      }



##  Scan arguments passed on the command line for references to
##  files of additional arguments:
## -------------------------------------------------------------------

      $self->{argIndex} = 0;

      foreach $argument ( @{$self->{arguments}} )
      {
         $msg = "$rname:  checking argument " . $self->{argIndex} . " which equals '$argument',\n";
         print $msg if ($trace);

         if ($argument eq "--argfile")
         {
            $msg = "$rname:  found --argfile tag,\n";
            $msg .= "$rname:  calling routine to read arguments file...\n\n";
            print $msg if ($trace);

            read_argument_file();
         }

         $self->{argIndex}++;
      }

      build_job_tree();
   }


   else
   {
      $msg = "$rname:  ERROR\n";
      $msg .= "$rname:  received no arguments from an external calling routine.\n\n";
      print $msg;
      return(0);
   }

}





sub read_argument_file
{
#--------------------------------------------------------------------#
#
#  RECEIVE:  nothing
#
#  RETURN:   nothing
#
#  ACCESS:   +  the array of arguments internal to this package,
#            +  the pointer to the current array element
#
#  PURPOSE:  read a file of gbtiler arguments.  The way this routine
#            is called, the pointer to the current argument in the
#            array of argument tokens points to a --argfile option.
#            This script assume that the next immediate token
#            specifies the argument file by name, relative path and
#            name, or absolute path and name.
#
#  CALLED:   internally.
#
#--------------------------------------------------------------------#
 
   my $index    = 0;    # ...local index
   my $argument = "";   # ...temporary string
   my $argfile  = 0;    # ...name of file containing more arguments
   my $line     = "";   # ...temporary string
   my @tokens   = ();   # ...temporary string
   my $token    = "";   # ...temporary string


   my $rname = "read_argument_file";
   my $trace = $self->{trace}{$rname};
   my $msg = "";




   $msg = "$rname:  routine to read arguments file beginning,\n";
   print $msg if ($trace);



## If there's an arguments file, try to open and read it:

   $index = $self->{argIndex};
   $argfile = $self->{arguments}->[ $index + 1 ];


   if ($argfile)
   {
      $msg = "";
      $msg .= "$rname:  about to try opening file '$argfile',\n";
      $msg .= "$rname:  argument index = '$index',\n\n";
      print $msg if ($trace);
      open(FILE, "<$argfile") || die "$rname:  couldn't open arguments file '$argfile' to read.\n\n";



## Store the argument file line by line, removing trailing white
## spaces:
## -------------------------------------------------------------------

      foreach $line (<FILE>)
      {

         while ( $line =~ /\s$/ )
         {
            chop( $line = $line );
         }


## Treat argument file lines which begin with pound symbols as user
## comments, by skipping them:
## -------------------------------------------------------------------

         if ( !( $line =~ /^#/ ) )
         {
            push( @{$self->{lines}}, $line );
         }

      }

      close FILE;



      if ($trace)
      {
         print "   $rname:  read argument file lines:\n\n";
         Diagnostic->show_tokens( $self->{lines}, "read_argument_file");
      }



## Break lines from arg files into tokens and store them:
## -------------------------------------------------------------------

      if ($self->{lines})
      {
         foreach $line ( @{$self->{lines}} )
         {
            @tokens = split( /\s/, $line);
            foreach $token ( @tokens )
            {
               if ( length($token) > 0 )
               {
                  push ( @{$self->{arguments}}, $token );
               }
            }
         }


         if ($trace)
         {
            print "   $rname:  parsed and stored argument file tokens:\n\n";
            Diagnostic->show_tokens( $self->{arguments}, "read_argument_file");
         }

         $self->{argCount} = @{$self->{arguments}};     # get the array count

      }#. . . . . . . . . . . . . . . . if there are lines to tokenize

   }#. . . . . . . . . . . . . . . if there's an argument file to read

}





sub build_job_tree
{
#--------------------------------------------------------------------#
#  2004-07-10
#
#  Process parsed, stored gbtiler arguments and add primary keys, one
#  for each layer, to the internal data structure $self{job}.
#  Supported gbtiler options in gbtiler version 2.0 include:
#
#  --path         [pathname]
#  --argfile      [filename]
#  --gerberfile   [filename] 
#  --drillfile    [filename] 
#  --rackfile     [filename] 
#  --outfile      [filename] 
#  
#  --offset       [n.n,n.n]
#  --leading_zeroes [n] 
#  --trailing_zeroes [n] 
#  --x_integer_digits [n]
#  --x_decimal_digits [n]
#  --y_integer_digits [n]
#  --y_decimal_digits [n]
#
#
#  As of 2004-08-04 there is also a --created_by option, which may or
#  may not be needed to help the script handle the drill coordinate
#  data generated by some CAD programs.
#
#
#  Note:  author Ted Havelka observes that Perl type casting does not 
#  very strict.  The comments to the right of local variable
#  declarations reflect the types of variables he intended to use when
#  writing the script.  On some level it seems to him that Perl does
#  not set variables to fixed types until they are assigned values,
#  and a variable's type can change with successive assignments of new
#  values.
#--------------------------------------------------------------------#


## Declare local variables:

   my $index;      # integer, for local index
   my $argument;   # string, current argument
   my $nextArg;    # string, arg after current argument, if exists
   my $argCount;   # integer, count of stored gbtiler arguments
   my $layerName;  # string, name of current layer
   my $inFileKey;  # string, name of cur' source gerber or drill file

   my $creatingProgram;     # string, name of program which created
                            # the current NC drill file and possilby
                            # an accompanying external rack file

   my $drillSubstitution;   # string,

   my $layerHoldsFilesOfType;      # string
   my $xOffset;                    # long, real number
   my $yOffset;                    # long, real number
   my $xOffsetGood;                # integer, acting as boolean
   my $yOffsetGood;                # integer, acting as boolean
   my $latestOffsetValuesGood;     # integer, acting as boolean
   my $existingOffset;             # long, real number
   my $latestOffsetValuesDiffer;   # integer, acting as boolean
   my $inFileKeyExists;            # integer, acting as boolean
   my $offsetKeysExist;            # integer, acting as boolean


   my $rname = "build_job_tree";
   my $trace = $self->{trace}{$rname};
   my $msg;
   my ($path, $filename, $newInFileKey); 



## Some top-of-routine diagnostics...
## -------------------------------------------------------------------


   if ($trace)
   {
      $msg = "";
      $msg .= "$rname:  beginning,\n";
      $msg .= "$rname:  building job tree from '$argCount' arguments,\n";
      $msg .= "$rname:  displaying current stored list of arguments:\n\n";
      print $msg;

      $self->{diagnostic}->show_tokens($self->{arguments}, "stored gbtiler arguments");
   }




## Scan through parsed gbtiler arguments, looking for global options
## settings, layer tags, gerber and NC drill file tags, offset tags
## and any other valid gbtiler tags or options:
## -------------------------------------------------------------------


   $argCount = $self->{argCount};
   $self->{job}{status} = "in progress";

   for ($index = 0; $index < $self->{argCount}; $index++)
   {

      $argument = $self->{arguments}[$index];

      $msg = "$rname:  processing arg '$argument',\n";
      print $msg if ($trace);



# --------------------------------------------------------------------
#  Handle --path option:
# --------------------------------------------------------------------

      if ( $argument eq "--path" )
      {
         $path = $self->{arguments}[ $index + 1 ];

         if ( $path !~ /.*($self->{separator})$/ )
         {
            $path = $path . $self->{separator};
         }
         $self->{job}{path} = $path;

         $msg = "$rname:  source file path for current tiling job is '$path',\n";
         $msg .= "$rname:  current directory and file separator is '$self->{separator}',\n";
         $msg .= "$rname:  set current job's path to '$path',\n";
         $msg .= "$rname:  \n";
         print $msg if ($trace);
      }



# --------------------------------------------------------------------
#  Handle --layer option:
# --------------------------------------------------------------------

      if ( $argument eq "--layer" )
      {
         $self->{job}{layerCount}++;

## If the argument following the current --layer argument is not a
## another gbtiler option, then perform a simple name validity check
## and give the current layer a name.  This name will either be based
## on the user's specified name or name based on the current count of
## layers encountered in the arguments list.
## -------------------------------------------------------------------

         $nextArg = $self->{arguments}[ $index + 1 ];

         if ( $nextArg !~ /^--.*/ )
         {
            $msg = "$rname:  found layer name = '$nextArg',\n";
            print $msg if ($trace);

            $layerName = "layer_" . $nextArg;
            $index++;
         }

         else
         {
            $layerName = sprintf("layer_%0*d", 4, $self->{job}{layerCount});

            $msg = "";
            $msg .= "$rname:  constructed layer name = '$layerName',\n";
            $msg .= "$rname:  argument following gbtiler layer tag = '$nextArg',\n";
            $msg .= "$rname:  \n";
            print $msg if ($trace);
         }



## 1) Here is one place new job layers are created:

         $self->{job}{$layerName}{inFileCount} = 0;
         $self->{job}{$layerName}{filesOfType} = "unknown";
         $self->{job}{$layerName}{notes} = "";
         $self->{job}{$layerName}{workDirectory} = $self->{job}{workDirectory};
      }



# --------------------------------------------------------------------
#  Handle --gerberfile option:
# --------------------------------------------------------------------

      if ( $argument eq "--gerberfile" )
      {
         $msg = "$rname:  found gerber file option,\n";
         print $msg if ($trace);

## If at least one layer already exists, then the local variable
## $layerName should hold the name of the key to of the current layer.
## So if $layerName holds a name, the following IF construct passes
## control to a block of code which adds more data to the current
## layer key in the job hash table:

         if ( length($layerName) > 0 )
         {
            $layerHoldsFilesOfType = $self->{job}{$layerName}{filesOfType};

            if ( $layerHoldsFilesOfType eq "unknown")
            {
               $self->{job}{$layerName}{filesOfType} = "gerber";
               $layerHoldsFilesOfType = "gerber";
            }

            if ( $layerHoldsFilesOfType ne "gerber")
            {
               $self->{job}{$layerName}{notes} = "layer may hold mixed file types";
            }

## Advance the argument index by one, as the token following the
## --gerberfile option should be the name of the gerber file to tile:

            $index++;
            $filename = $self->{arguments}[ $index ];
            $self->{job}{$layerName}{inFileCount}++;

## The local variable $inFileKey holds the name of the hash key for
## the most recent input or source file, be it a gerber or a drill
## file.  This variables helps the script place offset values in the
## correct source file's key, which itself is located within a layer
## of the current tiling job:

            $inFileKey = sprintf("infile_%0*d", 4, $self->{job}{$layerName}{inFileCount});
            $self->{job}{$layerName}{$inFileKey}{filename} = $self->{job}{path} . $filename;
            $self->{job}{$layerName}{$inFileKey}{filetype} = "gerber";
         }
         else
         {
            $msg = "$rname:  WARNING";
            $msg .= "$rname:  gerber file specified before any layers specified.";
            print $msg;
         }
      }



# --------------------------------------------------------------------
#  Handle --drillfile option:
# --------------------------------------------------------------------

      if ( $argument eq "--drillfile" )
      {
         $msg = "$rname:  found NC drill file option,\n";
         print $msg if ($trace);

## If at least one layer already exists, then the local variable
## $layerName should hold the name of the key to of the current layer.
## So if $layerName holds a name, the following IF construct passes
## control to a block of code which adds more data to the current
## layer key in the job hash table:

         if ( length($layerName) > 0 )
         {
            $layerHoldsFilesOfType = $self->{job}{$layerName}{filesOfType};

            if ( $layerHoldsFilesOfType eq "unknown")
            {
               $self->{job}{$layerName}{filesOfType} = "drill";
               $layerHoldsFilesOfType = "drill";
            }

            if ( $layerHoldsFilesOfType ne "drill")
            {
               $self->{job}{$layerName}{notes} = "layer may hold mixed file types";
            }

## Advance the argument index by one, as the token following the
## --drillfile option should be the name of the drill file to tile:

            $index++;
            $filename = $self->{arguments}[ $index ];
            $self->{job}{$layerName}{inFileCount}++;

## The local variable $inFileKey holds the name of the hash key for
## the most recent input or source file, be it a gerber or a drill
## file.  This variables helps the script place offset values in the
## correct source file's key, which itself is located within a layer
## of the current tiling job:

            $inFileKey = sprintf("infile_%0*d", 4, $self->{job}{$layerName}{inFileCount});
            $self->{job}{$layerName}{$inFileKey}{filename} = $self->{job}{path} . $filename;
            $self->{job}{$layerName}{$inFileKey}{filetype} = "drill";
         }
         else
         {
            $msg = "";
            $msg .= "$rname:  WARNING\n";
            $msg .= "$rname:  NC drill file specified before any layers specified,\n";
            $msg .= "$rname:  \n";
            print $msg;
         }
      }



# --------------------------------------------------------------------
#  Handle --rackfile option:
# --------------------------------------------------------------------

      if ( $argument eq "--rackfile" )
      {
         $msg = "$rname:  found rack file option,\n";
         print $msg if ($trace);

## If at least one layer already exists, then the local variable
## $layerName should hold the name of the key to of the current layer.
## So if $layerName holds a name, the following IF construct passes
## control to a block of code which does some checks and then
## potentially adds more data to the current layer key in the job
## hash table:

         if ( length($layerName) > 0 )
         {
            $layerHoldsFilesOfType = $self->{job}{$layerName}{filesOfType};

            if ( $layerHoldsFilesOfType eq "drill")
            {
               $index++;
               $filename = $self->{arguments}[ $index ];
               $self->{job}{$layerName}{$inFileKey}{rackfile} = $self->{job}{path} . $filename;
            }

            elsif ( $layerHoldsFilesOfType eq "unknown")
            {
               $self->{job}{$layerName}{filesOfType} = "drill";
               $index++;
               $filename = $self->{arguments}[ $index ];
               $self->{job}{$layerName}{$inFileKey}{rackfile} = $self->{job}{path} . $filename;
            }

            elsif ( $layerHoldsFilesOfType ne "drill")
            {
               $msg = "";
               $msg .= "$rname:  WARNING\n";
               $msg .= "$rname:  rack file specified for layer holding files\n";
               $msg .= "$rname:  of type '$layerHoldsFilesOfType'\n";
               $msg .= "$rname:  \n";
               print $msg;
            }

         }

         else
         {
            $msg = "";
            $msg .= "$rname:  WARNING\n";
            $msg .= "$rname:  rack file specified before any layers specified,\n";
            $msg .= "$rname:  \n";
            print $msg;
         }
      }



# --------------------------------------------------------------------
#  Handle --created_by option:
# --------------------------------------------------------------------

      if ( $argument eq "--created_by" )
      {
         $msg = "$rname:  found option to specify program which created current drill file,\n";
         print $msg if ($trace);

## If at least one layer already exists, then the local variable
## $layerName should hold the name of the key to of the current layer.
## So if $layerName holds a name, the following IF construct passes
## control to a block of code which does some checks and then
## potentially adds more data to the current layer key in the job
## hash table:

         if ( length($layerName) > 0 )
         {
            $layerHoldsFilesOfType = $self->{job}{$layerName}{filesOfType};

            if ( $layerHoldsFilesOfType eq "drill")
            {
               $index++;
               $creatingProgram = $self->{arguments}[ $index ];
               $self->{job}{$layerName}{$inFileKey}{createdBy} = $creatingProgram;
            }

            elsif ( $layerHoldsFilesOfType eq "unknown")
            {
               $self->{job}{$layerName}{filesOfType} = "drill";
               $index++;
               $creatingProgram = $self->{arguments}[ $index ];
               $self->{job}{$layerName}{$inFileKey}{createdBy} = $creatingProgram;
            }

            elsif ( $layerHoldsFilesOfType ne "drill")
            {
               $msg = "";
               $msg .= "$rname:  WARNING\n";
               $msg .= "$rname:  drill file creating program specified for layer \n";
               $msg .= "$rname:  holding files of type '$layerHoldsFilesOfType'\n";
               $msg .= "$rname:  \n";
               print $msg;
            }

         }

         else
         {
            $msg = "";
            $msg .= "$rname:  WARNING\n";
            $msg .= "$rname:  drill file creating program specified before any layers specified,\n";
            $msg .= "$rname:  \n";
            print $msg;
         }
      }




# --------------------------------------------------------------------
#  Handle --drill_substitution option:
# --------------------------------------------------------------------

      if ( $argument eq "--drill_substitution" )
      {
         $msg = "$rname:  found option to specify global drill substitution,\n";
         print $msg if ($trace);

## If at least one layer already exists, then the local variable
## $layerName should hold the name of the key to of the current layer.
## So if $layerName holds a name, the following IF construct passes
## control to a block of code which does some checks and then
## potentially adds more data to the current layer key in the job
## hash table:

         if ( length($layerName) > 0 )
         {
            $layerHoldsFilesOfType = $self->{job}{$layerName}{filesOfType};

            if ( $layerHoldsFilesOfType eq "drill")
            {
               $index++;
               $drillSubstitution = $self->{arguments}[ $index ];
               $self->{job}{$layerName}{drillSubstitution} = $drillSubstitution;
            }

            elsif ( $layerHoldsFilesOfType eq "unknown")
            {
               $self->{job}{$layerName}{filesOfType} = "drill";
               $index++;
               $drillSubstitution = $self->{arguments}[ $index ];
               $self->{job}{$layerName}{drillSubstitution} = $drillSubstitution;
            }

            elsif ( $layerHoldsFilesOfType ne "drill")
            {
               $msg = "";
               $msg .= "$rname:  WARNING\n";
               $msg .= "$rname:  drill substitution specified for layer \n";
               $msg .= "$rname:  holding files of type '$layerHoldsFilesOfType'\n";
               $msg .= "$rname:  \n";
               print $msg;
            }

         }

         else
         {
            $msg = "";
            $msg .= "$rname:  WARNING\n";
            $msg .= "$rname:  drill substitution specified before any layers specified,\n\n";
            print $msg;
         }
      }



# --------------------------------------------------------------------
#  Handle --outfile option:
# --------------------------------------------------------------------

      if ( $argument eq "--outfile" )
      {
         $msg = "$rname:  found output file option,\n";
         print $msg if ($trace);

         if ( length($layerName) > 0 )
         {
            $index++;
            $filename = $self->{arguments}[ $index ];
            $self->{job}{$layerName}{outfile} = $filename;
         }

         else
         {
            $msg = "";
            $msg .= "$rname:  WARNING\n";
            $msg .= "$rname:  output file specified before any layers specified,\n";
            $msg .= "$rname:  \n";
            print $msg;
         }
      }



# --------------------------------------------------------------------
#
#  Parse --offset option and values:
#
#  Using gbtiler version 2.0, offset values s may be entered in the
#  following ways,
#  
#     --offset n n
#  
#  ...where n may be n, .n or n.n in form, and n is a character in
#  the set [0-9].  Note also that successive gbtiler offset tags
#  (instances of the --offset option) cause this IF block to generate
#  additional source gerber or source drill file keys within the
#  current layer.  Gbtiler wants each source file key within a layer
#  of a tiling job to have unique X and Y offset values.  In a later
#  step of an executing gbtiler script, source files are read only
#  once, though there may be multiple source file keys in a layer
#  which refer to the same source file.
#
# --------------------------------------------------------------------

      if ( $argument eq "--offset" )
      {

         $xOffset = $self->{arguments}[ $index + 1 ];
         $yOffset = $self->{arguments}[ $index + 2 ];

#        $msg = "";
#        $msg .= "$rname:  found --offset option,\n";
#        $msg .= "$rname:  x offset value = '$xOffset',\n";
#        $msg .= "$rname:  y offset value = '$yOffset',\n";


## Step 1 for offsets:
## check whether the X and Y offset values are in valid, real number
## format.  We only increment the argument index if we find a valid
## offset value, which we expect in the two arguments following a
## --offset tag.  If an offset is missing, this logic will not pass
## over a potentially valid tag one or two tokens after the latest
## --offset tag:
# --------------------------------------------------------------------

#        if ( $xOffset =~ /^[0-9]*\.[0-9]+$/ )
         if ( $xOffset =~ /^-*[0-9]+\.[0-9]+$/ )
         {
            $xOffsetGood = 1;
            $index++;
         }
         else
         {
            $xOffsetGood = 0;
         }



#        if ( $yOffset =~ /^[0-9]*\.[0-9]+$/ )
         if ( $yOffset =~ /^-*[0-9]+\.[0-9]+$/ )
         {
            $yOffsetGood = 1;
            $index++;
         }
         else
         {
            $yOffsetGood = 0;
         }



         $latestOffsetValuesGood = ($xOffsetGood && $yOffsetGood);



## Step 2 for offsets:
##
## If X and Y offsets look like valid, real numbers, then check
## whether offset keys exists in the latest source gerber or drill
## file entry.
# --------------------------------------------------------------------

         if ( $latestOffsetValuesGood )
         {
            $offsetKeysExist = 0;

            if ( exists $self->{job}{$layerName}{$inFileKey}{xOffset} )
            {
               $offsetKeysExist = 1;
            }
            else
            {
               $offsetKeysExist = 0;
            }


            if ( !( exists $self->{job}{$layerName}{$inFileKey}{yOffset} ) )
            {
               $offsetKeysExist = 0;
            }
         }



## Step 3 for offsets:
##
## If these keys exist then check whether their values differ from the
## latest parsed offset values:
# --------------------------------------------------------------------

         if ( $offsetKeysExist )
         {
            $latestOffsetValuesDiffer = 0;

## Grab and compare stored X offset with latest X offset:

            $existingOffset = $self->{job}{$layerName}{$inFileKey}{xOffset};

            if ( $xOffset == $existingOffset )
            {
               $latestOffsetValuesDiffer = 0;
            }
            else
            {
               $latestOffsetValuesDiffer = 1;
            }

## Grab and compare stored Y offset with latest Y offset:

            $existingOffset = $self->{job}{$layerName}{$inFileKey}{yOffset};

            if ( $yOffset != $existingOffset )
            {
               $latestOffsetValuesDiffer = 1;
            }
         }



## Step 4 for offsets:
##
## If the X or Y offset keys isn't found, check whether a key exists
## for the current source file in the current layer:
# --------------------------------------------------------------------

         if ( exists $self->{job}{$layerName}{$inFileKey} )
         {
            $inFileKeyExists = 1;
         }
         else
         {
            $inFileKeyExists = 0;

            $msg = "";
            $msg .= "$rname:  WARNING\n";
            $msg .= "$rname:  couldn't find source file key in current layer\n";
            $msg .= "$rname:  of tiling job.  Offset values may be specified\n";
            $msg .= "$rname:  prior to naming a source gerber or drill file.\n";
            $msg .= "$rname:  Missing source file key is:\n";
            $msg .= "$rname:  \n";
            $msg .= "$rname:  \$self{job}{$layerName}{$inFileKey}\n";
            $msg .= "$rname:  \n";
            $msg .= "$rname:  Note:  curly brace pairs in the above key should\n";
            $msg .= "$rname:  all contain some word or pattern.\n";
            $msg .= "$rname:  \n";
            print $msg;
         }



## Step 5 for offsets:
##
## Taking results of all the tests on latest and stored offsets, add
## or skip adding the latest offset values to the job hash:
## -------------------------------------------------------------------

         $msg = "";
         $msg .= "$rname:  assessing offset tests, offset values are X = '$xOffset', Y = '$yOffset',\n";
         print $msg if ($trace);

         if ( $latestOffsetValuesGood )
         {

         $msg = "";
         $msg .= "$rname:  OFFSET RESULTS - latest offsets good,\n";
         print $msg if ($trace);

            if ( $offsetKeysExist)
            {

#              $msg = "";
#              $msg .= "$rname:  OFFSET RESULTS - offset keys for current infile exist,\n";
#              $msg .= "$rname:  \n";
#              print $msg;

## If there are offset keys in the current infile key of the job hash,
## and their values differ from the latest offsets, then create a new
## infile key, placing latest offset values there:

               if ( $latestOffsetValuesDiffer )
               {

#                 $msg = "";
#                 $msg .= "$rname:  OFFSET RESULTS - latest offsets differ from stored offsets,\n";
#                 $msg .= "$rname:  adding source file key for exisitng file with different offsets,\n";
#                 $msg .= "$rname:  argument parsing index = '$index',\n";
#                 $msg .= "$rname:  \n";
#                 print $msg;

## Copy the current source gerber or drill file key:

                  $self->{job}{$layerName}{inFileCount}++;
                  $newInFileKey = sprintf("infile_%0*d", 4, $self->{job}{$layerName}{inFileCount});

                  $self->{job}{$layerName}{$newInFileKey}{filetype} = $self->{job}{$layerName}{$inFileKey}{filetype};
                  $self->{job}{$layerName}{$newInFileKey}{filename} = $self->{job}{$layerName}{$inFileKey}{filename};

                  if ( exists $self->{job}{$layerName}{$inFileKey}{rackfile} )
                  {
                     $self->{job}{$layerName}{$newInFileKey}{rackfile} = $self->{job}{$layerName}{$inFileKey}{rackfile};
                  }

                  if ( exists $self->{job}{$layerName}{$inFileKey}{createdBy} )
                  {
                     $self->{job}{$layerName}{$newInFileKey}{createdBy} = $self->{job}{$layerName}{$inFileKey}{createdBy};
                  }


## Update X and Y offset values in the newly created key:

                  $self->{job}{$layerName}{$newInFileKey}{xOffset} = $xOffset;
                  $self->{job}{$layerName}{$newInFileKey}{yOffset} = $yOffset;

                  $inFileKey = $newInFileKey;
               }
            }


## If offset keys are not present in the current infile key of the job
## hash, then add them and set them to latest offset values:

            else
            {
#              $msg = "";
#              $msg .= "$rname:  OFFSET RESULTS - creating offset keys for current infile,\n";
#              $msg .= "$rname:  \$self{job}{$layerName}{$inFileKey}{xOffset} = '$xOffset',\n";
#              $msg .= "$rname:  \$self{job}{$layerName}{$inFileKey}{yOffset} = '$yOffset',\n";
#              $msg .= "$rname:  \n";
#              print $msg if ($trace);

               $self->{job}{$layerName}{$inFileKey}{xOffset} = $xOffset;
               $self->{job}{$layerName}{$inFileKey}{yOffset} = $yOffset;
            }
         }

## If latest offset values, either of them, are somehow not valid real
## numbers, do the stuff in this ELSE block:

         else
         {
            $msg = "";
            $msg .= "$rname:  WARNING\n";
            $msg .= "$rname:  something wrong with X and/or Y offset values,\n";
            $msg .= "$rname:  X offset equals '$xOffset',\n";
            $msg .= "$rname:  Y offset equals '$yOffset',\n";
            $msg .= "$rname:  \n";
            print $msg;
         }
      }



# --------------------------------------------------------------------
#  Parse and store numeric formatting options:
# --------------------------------------------------------------------

## NOTE:
##
## As of 2004-07-28, leading zeroes and trailing zeroes are
## formatted in the tiled, output file regardless of the user's
## request.  At some point, however, it will make sense to implement
## a sanity check that confirms at least one of these options is set
## to a true or selected value.  To drop both leading and trailing
## zeroes would effectively corrupt that data, as one or the other is
## needed in conjunction with integer and decimal digit counts in
## order to determine the base ten power of a given coordinate value.


      if ( $argument eq "--leading_zeroes" )
      {
         $index++;
         $argument = $self->{arguments}[$index];
         $self->{job}{format}{leadingZeroes} = $argument;
      }



      if ( $argument eq "--trailing_zeroes" )
      {
         $index++;
         $argument = $self->{arguments}[$index];
         $self->{job}{format}{trailingZeroes} = $argument;
      }



      if ( $argument eq "--x_integer_digits" )
      {
         $index++;
         $argument = $self->{arguments}[$index];
         $self->{job}{format}{xIntegerDigitsRequested} = $argument;
      }



      if ( $argument eq "--x_decimal_digits" )
      {
         $index++;
         $argument = $self->{arguments}[$index];
         $self->{job}{format}{xDecimalDigitsRequested} = $argument;
      }



      if ( $argument eq "--y_integer_digits" )
      {
         $index++;
         $argument = $self->{arguments}[$index];
         $self->{job}{format}{yIntegerDigitsRequested} = $argument;
      }



      if ( $argument eq "--y_decimal_digits" )
      {
         $index++;
         $argument = $self->{arguments}[$index];
         $self->{job}{format}{yDecimalDigitsRequested} = $argument;
      }


   } # . . . . . . . . . . . . . . . loop to process gbtiler arguments



## Summary diagnostics for build_job_tree routine:

   if ($trace)
   {
      $msg = "\n";
      print $msg;

      $self->{diagnostic}->show_hash_tree_primer($self->{job}, "current job hash keys");

      $msg = "\n";
      print $msg;
   }

}





sub check_job_tree_integrity
{
   my $msg;
   my $rname;

   $rname = "check_job_tree_integrity";


   $msg = "$rname:  NOT YET IMPLEMENTED.\n\n";
   print $msg;
}




sub current_job
{
   my $self = shift;

   return %{$self->{job}};
}


sub testsub1
{
#--------------------------------------------------------------------#
#  print "main:  Testing a subroutine by reference:\n\n";
#  $rr = \&testsub1;
#
#  &$rr(1);
#--------------------------------------------------------------------#


  my $flag = shift;

  print "   test sub ! called ";
  if ($flag)
    {
     print %{$flag};
    }
  else
    {
     print "  in THE NORMAL WAY.\n\n";
  }
}



#--------------------------------------------------------------------#
#  By convention, end a package file with 1, so the use or require   #
#  command succeeds.                                                 #
#--------------------------------------------------------------------#

1;


# TilerArguments.pm

