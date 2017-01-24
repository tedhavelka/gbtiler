#--------------------------------------------------------------------#
#
#   project:  gbtiler 2.0
#  filename:  Offsetter.pm
#   created:  2002-11-02
#  modified:  2007-03-05
#
#
#
#  SYNOPSIS:
#
#  Take merged, intermediate gerber data files that contain data from
#  one or more source files, and according to the job hash table
#  offset the coordinate data as specified.
#
# --------------------------------------------------------------------
#
#
#
#  IMPLEMENTATION:
#
#  This script reads the tiling job hash table to determine which
#  data in the merged, intermediate file need to be offset.
#  Coordinate data are processed line by line and immediately after
#  processing are writting out to a final, tiled file.
#
#  While offsetting, this script looks for comment lines among
#  coordinate data which specify from which source file the following
#  data come.  As of 2004-07-15 the apertures package puts these 
#  comments in the intermediate, merged file.
#
#  By no means the whole set of possible gerber coordinate lines, as
#  of 2004-08-09 the offsetter package handles the following types
#  of gerber coordinate data,
#
#
#  basic, cartesian coordinate statements:
#
#     X1583D01*
#     Y1100D02*
#     X4152Y2539D02*
#
#
#  gerber arc statements:
#
#     G02*X4248Y2500I40J-39D01*
#
#
#  In the arc statement the I and J values may appear one or the other
#  solo.  Gbtiler does not offset these values as they are incremental
#  values.  See the Gerber Systems Corporation document 'rs274xc.pdf'
#  for details on gerber arc statements.  This document is copyrighted
#  and not a part of the gbtiler documentation.
#
#
#  Offsetting gerber arc statements --
# 
#  If the current line appears to be a gerber arc statement, then
#  this script processes it as a ten part line.  The ten parts of a
#  typical arc statement are,
#
#     +  a leading directive,  
#     +  four label-value pairs
#     +  a trailing directive,  
#
#  Protel'98 generated arc statements appear to always contain both
#  X and Y label-value pairs, but may contain only an I or only a J
#  distances between arc start point and center of arc.  Though not
#  necessary, minus signs sometimes appear in the arc statements
#  present in some Protel generated gerber files.
#
#
#  Formatting leading and trailing zeroes --
#
#  In gerber arc statements I and J arc radii distances may appear one
#  or the other or both.  As of 2004-08-10 the Offsetter package tests
#  for the presence of I and J data in arc statements.  Upon review,
#  developer Ted may find that this test is unneeded, depending on the
#  way Perl string concatination works.
#
#  The overall goal, of course, is to minimize the number of
#  operations needed to process gerber data lines, as these are
#  typically the most numerous lines in the files being tiled.
#
#  The method for figuring out whether and how many additional leading
#  and trailing zeroes deserves some discussion.  As an example,
#  suppose we have the following situation:
# 
# 
#    1)  source file format statement is 'FSALX23Y23%*',
#    2)  user requests 2 integer digits in coordinate data,
#    3)  current arc value I appears as '40' in the arc statement,
# 
# 
#  The example arc line,
# 
#    G02*X4248Y2500I40J-39D01*
# 
# 
#  Calculation logic:
# 
#    >  length of the I value '40' as a string is 2,
# 
#    >  length 2 minus format statement's 3 decimal digits is -1,
# 
#    >  user requested 2 integer digits minus the value -1 equals 3,
# 
# 
#  Prepending a series of three zeroes to '40' gives '00040'.  If the
#  user has requested additional precision, the script appends one or
#  more zeroes as needed.
# 
# --------------------------------------------------------------------
#
#
#
#  AUTHORS:
#
#  Ted Havelka    ted(a)cs.pdx.edu
#
#
#
#--------------------------------------------------------------------#



package Offsetter;
use strict;
our $self = {};



#====================================================================#
#                                                                    #
#  Constructor:                                                      # 
#                                                                    #
#====================================================================#


sub new
{

## Declare an anonymous, complex hash table as the data structure
## for this package:
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

    };



## Initialize data for this object:

   $self->{package} = "Offsetter.pm";

   $self->{trace}{new}                = 0;
   $self->{trace}{initialize}         = 0;
   $self->{trace}{offset_coordinates} = 0;



## Let the object know its class:

    bless($self, $class); 

    return $self;

}





#====================================================================#
#                                                                    #
#   Data-access methods:                                             #
#                                                                    #
#====================================================================#


sub initialize
{

   my $self = shift;

   my $rname = "initialize";
   my $trace = $self->{trace}{$rname};
   my $msg = "";



## Set a reference to a diagnostics package:

   if (@_)
   {
      $self->{diagnostic} = shift;
   }
   else
   {
      $msg  = "$rname:  ERROR\n";
      $msg .= "$rname:  In an instance of '$self->{packageName}' package, received\n";
      $msg .= "$rname:  no reference to 'Diagnostics' package instance.\n";
      $msg .= "$rname:  \n";
      print $msg;
   }



## If passed, set the name of the project to which this package
## belongs:

   if (@_)
   {
      $self->{projectName} = shift;
   }

}





#--------------------------------------------------------------------#
#
#  2004-07-28
#
#  TOPIC:  Perl string repeat operator
#  URL:  http://iis1.cps.unizar.es/Oreilly/perl/prog/ch01_05.htm
#
#  There's also a "multiply" operation for strings, also called the
#  repeat operator. Again, it's a separate operator (x) to keep it
#  distinct from numeric multiplication:
#
#     $a = 123;
#     $b = 3;
#     print $a * $b;     # prints 369
#     print $a x $b;     # prints 123123123
#
#--------------------------------------------------------------------#





sub offset_coordinates
{
#--------------------------------------------------------------------#
#
## 2004-07-24
##
## In gbtiler 2.0, by the time this routine is called, coordinate data
## exists in the growing tiled output file.  Coordinate data from each
## source file are preceded by gerber format comments which identify
## the source file.
##
## By reading these comments, this routine can open the intermediate
## output file and determine which coordinate data belong to which
## source files.  With this information, the routines in this package
## can access the header information in corresponding source files
## and learn, for example, the counts of integral and decimal digits
## in the data of a given source file.
##
##
## Sample gerber Format Statement line:
##
##    %FSAX24Y24*%
##
##
## Filtering for tool change directives:
##
##    if ($line =~ /^D[0-9][0-9]+/)
##
##
## Filtering for last line in the merged gerber data:
##
##    if ($line !~ /^M0[02]/) 
##
##
##
## For each source file to be offset this package must parse the
## format statement or 'FS' line to determine X and Y decimals...
##
##    $x_decimals = $self{numeric_format}->cur_x_decimal_digits();
##    $y_decimals = $self{numeric_format}->cur_y_decimal_digits();
##
##    $x_multiplier = (10 ** $x_decimals);
##    $y_multiplier = (10 ** $y_decimals);
##
##
#--------------------------------------------------------------------#

   my $self = shift;


   my $intermediateFile;  # string, intermediate file name
   my $outFile;           # string, output filename

   my $onData;            # string, integer as boolean flag
   my $sourceFileKnown;   # string, integer as boolean flag
   my $line = ' ';              # string, current merged file line
   my $sourceFileKey;     # string, name of source file hash key
   my $offsetLine;        # string, modified line

   my $xIntegerDigitsOriginal;     # integer, source file format information
   my $xDecimalDigitsOriginal;     # integer, source file format information
   my $yIntegerDigitsOriginal;     # integer, source file format information
   my $yDecimalDigitsOriginal;     # integer, source file format information
   my $xOffset;           # integer, user-specified offset value
   my $yOffset;           # integer, user-specified offset value




   my $rname = "offset_coordinates";
   my $trace = $self->{trace}{$rname};
   my $msg;
   my $directive; 
   my ($stillParsing, $directive1, $label1, $value1, $label2, $value2) = (0,0,0,0,0,0); 
   my ($dataI, $label3, $value3, $dataJ, $label4, $value4, $directive2) = (0,0,0,0,0,0,0); 
   my ($xInt, $xDec, $yInt, $yDec, $xCoordFormatted, $yCoordFormatted) = (0,0,0,0,0,0); 
   my ($xCoord, $yCoord, $iCoordFormatted, $jCoordFormatted, $headerLine) = (0,0,0,0,0); 
## Assign the first explicitly passed parameter to the hash table
## pointer $self{layer}:

   
   $self->{layer} = shift;




## Assign a pointer to a passed hash reference containing output
## format information:


   $self->{format} = shift;




## Construct the filename of an intermediate file of the current layer
## in the tiling process:


   $intermediateFile = $self->{layer}{workDirectory} . $self->{layer}{outfile} . ".MERGED";

   if ( !open(INFILE, "< $intermediateFile") )
   {
      $msg = "$rname:  couldn't open intermediate file '$intermediateFile' for reading,\n";
      print $msg;
      $msg = "$rname:  unable to read intermediate file to begin offsetting,\n";
      $msg .= "$rname:  returning to caller...\n\n";
      print $msg;
      return (0);
   }



   $outFile = $self->{layer}{workDirectory} . $self->{layer}{outfile};

   if ( !open(OUTFILE, "> $outFile") )
   {
      $msg = "$rname:  couldn't open intermediate file '$outFile' for writing,\n";
      print $msg;
      $msg = "$rname:  unable to write intermediate file to store offset data,\n";
      $msg .= "$rname:  returning to caller...\n\n";
      print $msg;
      return (0);
   }



   $stillParsing    = 1;
   $sourceFileKnown = 0;
   $onData          = 0;

   $sourceFileKey   = "DEFAULT_SOURCE_FILE_KEY";



## -------------------------------------------------------------------
##
##           -=*  Main Gerber Data Offsetting Loop  *=-
##
## -------------------------------------------------------------------


## 2004-08-09
##
## Note:  in a later version of gbtiler, one with more error checking,
## we may use a condition like this to avoid looping long or
## indefinite periods of time,
##
##    while ( ( $line = <INFILE> ) && ( $stillParsing ) )



   while ( $line = <INFILE> )
   {

      $msg = "$rname:  processing line '$line',\n";
      print $msg if ($trace);


## -------------------------------------------------------------------
## Case 1:  processing data or directives
## -------------------------------------------------------------------

      if ( ($sourceFileKnown) && ($onData ) )
      {

   
## Offset gerber arc statements:
         
         if ( $line =~ /^G0[23]/ )
         {
       
            ($directive1, $label1, $value1, $label2, $value2,
            $dataI, $label3, $value3, $dataJ, $label4, $value4, $directive2) =
            $line =~ /^(G0[23].*)([AX])(\d+)([BY])(\d+)((I-*)(\d+))*((J-*)(\d+))*(D.*)/;



## As of 2004-08-09 gerber arc statements all appear to have both X
## and Y coordinate data.  Offset these unconditionally:
          

            $value1 += $xOffset;
            $value2 += $yOffset;



## Formatting arc X and Y values with leading and trailing zeroes:


            $xInt = $self->{format}{xIntegerDigitsRequested} - (length($value1) - $xDecimalDigitsOriginal);
            $xInt = 0 if ( $xInt < 0 );

            $xDec = $self->{format}{xDecimalDigitsRequested} - $xDecimalDigitsOriginal;
            $xDec = 0 if ( $xDec < 0 );

            $yInt = $self->{format}{yIntegerDigitsRequested} - (length($value2) - $yDecimalDigitsOriginal);
            $yInt = 0 if ( $yInt < 0 );

            $yDec = $self->{format}{yDecimalDigitsRequested} - $yDecimalDigitsOriginal;
            $yDec = 0 if ( $yDec < 0 );

            $xCoordFormatted = ("0" x $xInt) . $value1 . ("0" x $xDec);
            $yCoordFormatted = ("0" x $yInt) . $value2 . ("0" x $yDec);

            $xCoord = $value1;
            $yCoord = $value2;




## Formatting arc I and J values with leading and trailing zeroes:


   if (defined($value3)) { $xInt = $self->{format}{xIntegerDigitsRequested} - (length($value3) - $xDecimalDigitsOriginal); }
            $xInt = 0 if ( $xInt < 0 );
         if(defined($value4)) { 
            $yInt = $self->{format}{yIntegerDigitsRequested} - (length($value4) - $yDecimalDigitsOriginal); }
            $yInt = 0 if ( $yInt < 0 );


            if (defined($label3) &&  (length($label3) > 0) )
            {
               $iCoordFormatted = ("0" x $xInt) . $value3 . ("0" x $xDec);
            }
            else
            {
               $iCoordFormatted = "";
            }


            if (defined($label4) && (length($label4) > 0))
            {
               $jCoordFormatted = ("0" x $yInt) . $value4 . ("0" x $yDec);
            }
            else
            {
               $jCoordFormatted = "";
            }

  if (defined($label3) && defined($label4)) {
            $offsetLine = $directive1 . "X" . $xCoordFormatted . "Y" . $yCoordFormatted .
                          $label3 . $iCoordFormatted . $label4 . $jCoordFormatted . $directive2 . "\n"; 
  }


            $msg = "$rname:  parsing gerber arc statement,\n";
            $msg .= "$rname:  found directives, X and Y values, I and J values:\n";
            $msg .= "$rname:  \n";
 if (defined($label3) && defined($label4)) {          $msg .= "$rname:  '" . $directive1 . "' '" . $label1 . "' '" . $value1 . "' '" . $label2 . "' '" . $value2 . "' '" . $label3 . "' '" . $value3 . "' '" . $label4 . "' '" . $value4 . "' '" . $directive2 . "',\n"; }
            $msg .= "$rname:  \n";
            $msg .= "$rname:  offset arc statement = '$offsetLine',\n";
            $msg .= "$rname:  \n";
            print $msg if ($trace);

         }



## Offset gerber coordinate data statements:
## -------------------------------------------------------------------

         elsif ( $line =~ /^([ABXY]\d+)+([BY]\d+)*/ )
         {  

            ($label1, $value1, $label2, $value2, $directive) =
               $line =~ /^([ABXY])(\d+)([BY])*(\d+)*(\S+)*/;

#           ($directive1, $label1, $value1, $label2, $value2, $directive2) =
#              $line =~ /^([G][0-9\*]+)*([ABXY])(\d+)([BY])*(\d+)*(\S+)*/;


            if ( $label1 =~ /[AX]/ )
            {
               $xCoord = $value1;
            }
            else
            {
               $yCoord = $value1;
            }
          
           
            if (defined($label2) &&($label2 =~ /[BY]/))
            {
               $yCoord = $value2;
            }
      


            $msg = "$rname:  parsing and offsetting coordinate data,\n";
            $msg .= "$rname:  \n";
            $msg .= "$rname:  \$label1 = '$label1',\n";
            $msg .= "$rname:  \$value1 = '$value1',\n";
            if(defined($label2)) {$msg .= "$rname:  \$label2 = '$label2',\n"; } 
            if(defined($label2)) {$msg .= "$rname:  \$value2 = '$value2',\n"; } 
            $msg .= "$rname:  \$directive = '$directive',\n";
            $msg .= "$rname:  \n";
            $msg .= "$rname:  potentially carrying X or Y value from previous coordinate line,\n";
            $msg .= "$rname:  X value equals '$xCoord',\n";
            $msg .= "$rname:  Y value equals '$yCoord',\n";
            $msg .= "$rname:  \n";



## Because of Perl's often automatic type conversion, the following
## arithmetic operations convert the x and y coordinate variables from
## strings to integers.  Where the strings contain leading zeroes,
## the leading zeroes disappear after this operation as evidenced by
## the output of the diagnostic statements just a few lines further:
## -------------------------------------------------------------------
        
            if ( $label1 =~ /[AX]/ )
            {  
               $xCoord += $xOffset;
            }
            else
            {
               $yCoord += $yOffset;
            }
            

            if (defined($label2) && ($label2 =~ /[BY]/))
            {
               $yCoord += $yOffset;
            }


            $msg .= "$rname:  offset X value equals '$xCoord',\n";
            $msg .= "$rname:  offset Y value equals '$yCoord',\n";
            $msg .= "$rname:  \n";
            


## Unconditionally format coordinate data with leading zeroes.
## This involves taking the difference between the digit counts
## specified in the source files and the digit counts specified by
## the user running the tiling job.  In general this script will
## either add laeding and trailing zeroes, or leave them unchanged in
## their count.  Because in the year 2004 memory and disk space are
## generally no longer limiting for small files as most gerber files
## are, there is not a pressing need to minimize or remove leading
## zeroes in gerber and NC drill files.
##
## Take the length of the coordinate value, minus the number of digits
## that represent the decimal portion.  What remains are the number of
## digits that represent the integer portion of the coordinate value.
## For values less than one inch or less than one millimeter, this may
## be a negative value.  When this occurs the two subtractions in the
## calculation of $xInt and $yInt cancel and effectively become
## additions:
## -------------------------------------------------------------------
           
            $xInt = $self->{format}{xIntegerDigitsRequested} - (length($xCoord) - $xDecimalDigitsOriginal);
            $xInt = 0 if ( $xInt < 0 );
          
            $xDec = $self->{format}{xDecimalDigitsRequested} - $xDecimalDigitsOriginal;
            $xDec = 0 if ( $xDec < 0 );


            $yInt = $self->{format}{yIntegerDigitsRequested} - (length($yCoord) - $yDecimalDigitsOriginal);
            $yInt = 0 if ( $yInt < 0 );

            $yDec = $self->{format}{yDecimalDigitsRequested} - $yDecimalDigitsOriginal;
            $yDec = 0 if ( $yDec < 0 );

             $xCoordFormatted = ("0" x $xInt) . $xCoord . ("0" x $xDec);
             
             $yCoordFormatted = ("0" x $yInt) . $yCoord . ("0" x $yDec);
          
        
 
           
            $msg .= "$rname:  X value needs '$xInt' leading zeroes and '$xDec' trailing zeroes,\n"; 
            $msg .= "$rname:  Y value needs '$yInt' leading zeroes and '$yDec' trailing zeroes,\n";
            $msg .= "$rname:  \n";
#           $msg .= "$rname:  formatted X value equals '$xCoordFormatted',\n";
#           $msg .= "$rname:  formatted Y value equals '$yCoordFormatted',\n";
#           $msg .= "$rname:  \n";



            $offsetLine = "X" . $xCoordFormatted . "Y" . $yCoordFormatted . $directive . "\n";
             

            $msg .= "$rname:  \n";
            $msg .= "$rname:  offset line = '$offsetLine',\n";
            $msg .= "$rname:  \n";
            $msg .= "$rname:  \n";
            print $msg if ($trace);

         }



## Pass on comments unaltered:

         elsif ($line =~ /^G04/) 
         {
            $sourceFileKnown = 0;
            $onData = 0;
            $offsetLine = $line;
         }



## Pass on end-of-program commands unaltered:

         elsif ($line =~ /^M0[012]/) 
         {
            $onData = 0;
            $offsetLine = $line;
         }



         else
         {
            while ($line =~ /\s$/) { chop($line = $line); }
            $offsetLine = $line . "\n";
         }



         print OUTFILE $offsetLine;

      }



## -------------------------------------------------------------------
## Case 2 while processing lines of intermediate file:
##
## If we're not on sure what the current source file is or we are
## not processing a line of coordinate data, then perform these
## checks:
## -------------------------------------------------------------------

      else
      {
         if ($sourceFileKnown)
         {
            if ( $line =~ /^D/ )
            {
               $onData = 1;

               $msg = "$rname:  found beginning of data block,\n";
               $msg .= "$rname:  \n";
               print $msg if ($trace);

            }
         }

         else
         {
            if ( $line =~ /source file key/ )
            {
               $line =~ /(infile_\d+)/;  # These two lines work to put
               $sourceFileKey = $1;      # corrent value into Perl's
                                         # built-in variable '$1'.
               $sourceFileKnown = 1;


               $msg = "$rname:  parsing source file key, current line holds '$line',\n";
               $msg .= "$rname:  source file key variable holds '$sourceFileKey',\n";
               $msg .= "$rname:  built-in Perl variable \$1 holds '$1',\n";
               $msg .= "$rname:  \n";
               print $msg if ($trace);



## -------------------------------------------------------------------
## Found name of source file's key in the layer hash, now parsing
## for the source files numeric format information...
##
## Typinal Format Statement line,
##
##    %FSAX24Y24*%
##
## Note a little further down the taking of 10 to a power equal to
## the number of decimal digits in the X and Y coordinates.  Treating
## the coordinate data as integers, and multiplying user-specified
## offsets correspondingly is more simple than converting the
## coordinate data into real values with decimal points. 
## -------------------------------------------------------------------

               foreach $headerLine ( @{$self->{layer}{$sourceFileKey}{header}} )
               {

                  $msg = "$rname:  examining header line '$headerLine',\n";
                  print $msg if ($trace);


                  if ( $headerLine =~ /FS/ )
                  {  
                     ($xIntegerDigitsOriginal, $xDecimalDigitsOriginal, $yIntegerDigitsOriginal, $yDecimalDigitsOriginal) = $headerLine =~ /[AX](\d)(\d)[BY](\d)(\d)/;
                     last;
                  }

               }

               $msg = "$rname:  Parsing formats for file in key '$sourceFileKey',\n";
               $msg .= "$rname:  coordinate data for this file has,\n";
               $msg .= "$rname:  \n";
               $msg .= "$rname:  '$xIntegerDigitsOriginal' x integer digits,\n";
               $msg .= "$rname:  '$xDecimalDigitsOriginal' x decimal digits,\n";
               $msg .= "$rname:  '$yIntegerDigitsOriginal' y integer digits,\n";
               $msg .= "$rname:  '$yDecimalDigitsOriginal' y decimal digits,\n";
               $msg .= "$rname:  \n";
               print $msg if ($trace);



               $xOffset = $self->{layer}{$sourceFileKey}{xOffset};
               $yOffset = $self->{layer}{$sourceFileKey}{yOffset};
           
               $xOffset *= ( 10 ** $xDecimalDigitsOriginal );
               $yOffset *= ( 10 ** $yDecimalDigitsOriginal );
               
           
            
               $msg = "$rname:  X offset converted to mils = '$xOffset',\n";
               $msg .= "$rname:  Y offset converted to mils = '$yOffset',\n";
               print $msg if ($trace); 

            }

         }

         print OUTFILE $line;
      }

   }



}





#--------------------------------------------------------------------#
#  By convention, end a package file with 1, so the use or require   #
#  command succeeds.                                                 #
#--------------------------------------------------------------------#

1;


# Offsetter.pm

