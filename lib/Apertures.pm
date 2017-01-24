#---------------------------------------------------------------------
#
#   project:  gbtiler 2.0
#  filename:  Apertures.pm
#   created:  2002-11-03
#  modified:  2007-03-05
#
#...;....1....;....2....;....3....|....4....;....5....;....6....;....7



#---------------------------------------------------------------------
#
#  SYNOPSIS:
#
#  This Perl module builds a master list of aperture definitions, and
#  manages aperture name substitution during tiling of source files
#  into a single output file.
#
#
#  ADDITIONAL DETAILS OF SCRIPT PURPOSE:
#
#  This Perl module gathers aperture definitions from the gerber
#  source files of the current tiling job layer.  Uniquely named
#  unique definitions are stored in a master list that becomes part
#  of the current layer.  Additional aperture name mapping information
#  is stored elsewhere in the layer.  Name mapping info allows other
#  parts of this package to correctly map merged aperture references
#  -- 'Dnn' lines -- in the final, tiled gerber file.
#
#  After building a master list, aperture name substitution occurs
#  on a per source file basis.  Each file by this time has its own
#  name mapping hash of corresponding original and modified aperture
#  names.  By the time this script performs aperture substitutions,
#  it is appending to a growing output file to which other packages
#  have already written header and macro definition data.  For each
#  gerber source file the routine to substitute aperture names filters
#  for aperture references, lines that begin with the character 'D'.
#  The aperture references in these lines are used to find the
#  potentially renamed aperture in the master list for the current
#  tiling layer.
#
#
#  IMPLEMENTATION:
#
#  
#
#
#
#
#  AUTHORS:
#
#  Ted Havelka    ted(a)cs.pdx.edu
#
#---------------------------------------------------------------------



package Apertures;
use strict;
our $self = {};

#====================================================================#
#                                                                    #
#   Constructor:                                                     # 
#                                                                    #
#====================================================================#

sub new
{

## Define an anonymous, comples hash table as the data structure
## for this package:
   my ($class) = @_; #added
   $self =

   {

      projectName => 0,    # name of project to which this package
                           # belongs

      packageName => 0,    # name of this package

      diagnostic  => 0,    # reference to a diagnostics package

      trace       => {},   # a sub-hash of flags for tracing and
                           # and diagnostics generation on a
                           # per-routine basis


      layer       => 0,    # reference to sub-hash holding the
                           # current gerber layer in tiling process

   };


#--------------------------------------------------------------------#
#  Initialize with some arbitrary data for testing:
#
#  NOTE:  I learned here that initializations like the following
#    can't take place in a Perl line beginning with the 'my' token.
#--------------------------------------------------------------------#

   $self->{packageName} = "Apertures.pm";

   $self->{trace}{new}                        = 0;
   $self->{trace}{initialize}                 = 0;
   $self->{trace}{set_work_directory}         = 0;
   $self->{trace}{store_apertures}            = 0;
   $self->{trace}{write_aperture_definitions} = 0;
   $self->{trace}{substitute_apertures}       = 0;



#--------------------------------------------------------------------#
#  Let the data structures of this object know their class:
#--------------------------------------------------------------------#

   bless($self, $class); 

   return $self ;

}





sub initialize
{
#--------------------------------------------------------------------#
#
#  RECEIVE:  a pointer to an ApertureLabel object
#
#  RETURN:   nothing
#
#  PURPOSE:  initialize a reference or pointer to an 'ApertureLabel'
#    object, which main instantiates, and other objects or packages
#    may use.
#
#--------------------------------------------------------------------#


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





#====================================================================#
#                                                                    #
#   Data access methods:                                             #
#                                                                    #
#====================================================================#


sub store_apertures
{
#--------------------------------------------------------------------#
#
#  RECEIVE:  a reference to the current layer's hash table, from
#            the primary "package driving, glue" script,
#
#  RETURN:   nothing explicitly, but implicitly the passed layer
#            hash table or tree gets new information.  In this case
#            the data added include aperture definitions and
#            old name -> new name mappings stored in each source
#            file's subkey within the layer hash,
#
#  PURPOSE:  to extract and store gerber aperture definitions from
#            each gerber file specified in the current layer.
#
#
#
#  IMPLEMENTATION AND PARSING STRATEGY:
#
## Ok, so now we have this aperture broken down into its directive,
## name, shape and size.  We store apertures in a master list by their
## names.  Shape and size information, separated by a comma fill the
## string to which each aperture name in the master list points.
##
## As with macros, we have three cases to handle with each aperture
## from a source file,
##
##
##    1)  aperture name not in master list
##
##    2)  aperture name in master list, definitions match
##
##    3)  aperture name in master list, definitions differ
##
##
## When I speak of matching definitions I refer to the def' of the
## current aperture and the def' of the stored aperture.  In the first
## two cases, aperture handling is simple,
##
##
##   1)  aperture not in list?  Add it.
##
##   2)  aperture named in list and def's match?  Do not add it.
##
##
## When an aperture name appears in the list but definitions differ,
## then our work is more complex.  Because like-defined apertures are
## often present in different source files, but with differing names,
## it makes sense to scan stored aperture definitions when current
## and stored names collide.  In this way, if I have for example five
## gerber source files with the same apertures defined but named 
## differently each time, I can map those names for each source file
## to point to the same definition in the master list that this script
## generates.
##
## Actually what happens is, the aperture definition is stored the 
## first time it is encountered.  Successive encounters of the same
## aperture definition result in name mappings within the
## corresponding source files.
# 
#--------------------------------------------------------------------#


   my $self = shift;


   my $sourceFile;     # string, holds names of layer hash keys
   my $filename;       # string, holds current source filename
   my $line;           # string, holds current line in process
   my $stillParsing;   # integer, acts as boolean flag

   my $directive;      # string,
   my $name;           # string,
   my $shape;          # string,
   my $size;           # string,

   my $numericID;          # string,
   my $currentDefinition;  # string,
   my $nextApertureID;     # integer, holds value between 10 and 999

  #my $currentDefinition;  # string,
   my $storedDefinition;   # string,



## Diagnostic variables:

   my $rname = "store_apertures";
   my $trace = $self->{trace}{$rname};
   my $msg = "";
   my ($lineCount, $onMacro, $onAperture, $alphaID, $apertureName); #added
   my ($definitionPresent, $aperture, $newName); #added


## Assign the first explicitly passed parameter to the hash table
## pointer $self{layer}:
## -------------------------------------------------------------------


   if (@_)
   {
      $self->{layer} = shift;
   }
   else
   {
      $msg = "$rname:  ERROR\n";
      $msg .= "$rname:  in package '$self->{packageName}' received no gerber layer to parse,\n";
      $msg .= "$rname:  returning to caller...\n\n";
      print $msg;
      return (0);
   }




## According to the gerber language specification described in the
## document rs274c.pdf, aperture labels may fall within the range of
## whole number values 10 to 999.  Initialize the next available 
## aperture numeric ID value for the current layer to 10:
## -------------------------------------------------------------------


   $self->{layer}{nextApertureID} = 10;




## For each file in the passed gerber layer hash tree, search for
## and store macro definitions:
## -------------------------------------------------------------------


   foreach $sourceFile ( keys %{$self->{layer}} )
   {  
      if ( $sourceFile =~ /^infile_/ )
      {
         $filename = $self->{layer}{$sourceFile}{filename};
 
      
         if (open(INFILE, "< $filename") )
         {

            $lineCount = 0;      # running count of lines parsed
            $stillParsing = 1;   # boolean flag
            $onMacro = 0;        # boolean flag

            $msg  = "$rname:  \n";
            $msg .= "$rname:  processing layer hash key '$sourceFile',\n";
            $msg .= "$rname:  \n";
            print $msg if ($trace);

##       .
##  .....
## .  



## Main parsing block for aperture definitions:
##
## This loop exits either after reading the first gerber file line
## which begins with a 'D' character, or after reading all file lines,
## whichever event occurs first.
## -------------------------------------------------------------------


   while ( defined( $line = <INFILE> ) && ( $stillParsing) )
   {
    
      while ($line =~ /\s$/) { chop($line = $line); }

      $lineCount++;
      $msg = "$rname:  parsing line $lineCount = '$line',\n";
      print $msg if ($trace);



      if ( $line =~ /^[%]*AD/ )
      {
         $onAperture = 1;
         $self->{layer}{apertureDefCurrent} = "";



## Remove trailing white space from current line:

         while ( $line =~ /\s$/ )
         {
            chop( $line = $line );
         }



## Two ways of extracting data from an aperture definition line:

         ($directive, $name, $shape, $size) = $line =~ /(^.*AD)(D\d+)([A-Z0-9]+),(.+)/;
         ($alphaID, $numericID, $currentDefinition) = $line =~ /^.*AD([A-Z])(\d+)([A-Z0-9]+,.+)/;


         if ($trace)
         {
            $msg = "$rname:  found aperture '$line' with label '$apertureName',\n";
            $msg .= "$rname:  \n";
            $msg .= "$rname:  directive      = '$directive',\n";
            $msg .= "$rname:  name or D-code = '$name',\n";
            $msg .= "$rname:  shape          = '$shape',\n";
            $msg .= "$rname:  size info      = '$size',\n";
            $msg .= "$rname:  \n";
            $msg .= "$rname:  alpha ID       = '$alphaID',\n";
            $msg .= "$rname:  numeric ID     = '$numericID',\n";
            $msg .= "$rname:  definition     = '$currentDefinition',\n";
            $msg .= "$rname:  \n";
            print $msg;
         }



         $msg = "$rname:  comparing current and next available numeric ID values,\n";

         if ( $numericID >= $self->{layer}{nextApertureID} )
         {
            $msg .= "$rname:  incrementing next available numeric ID,\n";
            $self->{layer}{nextApertureID} = ( $numericID + 1 );
         }

         $msg .= "$rname:  current aperture numeric ID = '$numericID',\n";
         $msg .= "$rname:  next available numeric ID =   '$self->{layer}{nextApertureID}',\n";
         $msg .= "$rname:  \n";
         print $msg if ($trace);



         if ( exists $self->{layer}{apertureMasterList}{$name} )
         {


## If the aperture name is in the master list and current definition
## matches the aperture definition in the master list, then simply
## update the corresponding source file's aperture name mapping hash:

            $storedDefinition = $self->{layer}{apertureMasterList}{$name};

            if ( $currentDefinition eq $storedDefinition )
            {
               $self->{layer}{$sourceFile}{apertureNameMapping}{$name} = $name;
            }


## If aperture name in master list but definition differs, first
## search for a like definition.
##
## CASE 1:
##
## In the case where a like definition is found but referenced in the
## master list by a different name, update the current source file's
## name mapping list to reflect this renaming.
##
## CASE 2:
##
## If no like definition is found then rename the current aperture,
## add this definition to the master list, and update name mapping for
## corresponding gerber source file.
## 
## -------------------------------------------------------------------

            else
            {
               $definitionPresent = 0;

               foreach $aperture ( keys %{$self->{layer}{apertureMasterList}} )
               {
                  $storedDefinition = $self->{layer}{apertureMasterList}{$aperture};

                  if ( $currentDefinition eq $storedDefinition )
                  {
                     $definitionPresent = 1;
                     $newName = $aperture;
                     last;
                  }
               }


## Current aperture name in master list,
## current aperture definition stored, but by a different name:

               if ( $definitionPresent )
               {
                  $self->{layer}{$sourceFile}{apertureNameMapping}{$name} = $newName;
               }


## Current aperture name in master list,
## current aperture defintion not yet stored, needs new name:

               else
               {
                  $newName = $alphaID . $self->{layer}{nextApertureID};
                  $self->{layer}{nextApertureID}++;
                  $self->{layer}{apertureMasterList}{$newName} = $currentDefinition;
                  $self->{layer}{$sourceFile}{apertureNameMapping}{$name} = $newName;
               }
            }
         }


## If the current aperture name does not exist in the master list, 
## then search the list for a matching definition:
## -------------------------------------------------------------------

         else
         {
            $definitionPresent = 0;

            foreach $aperture ( keys %{$self->{layer}{apertureMasterList}} )
            {
               $storedDefinition = $self->{layer}{apertureMasterList}{$aperture};

               if ( $currentDefinition eq $storedDefinition )
               {
                  $definitionPresent = 1;
                  $newName = $aperture;
                  last;
               }
            }


## Current aperture name not in master list,
## current aperture defintion stored, update name change mapping:

            if ( $definitionPresent )
            {
               $self->{layer}{$sourceFile}{apertureNameMapping}{$name} = $newName;
            }


## Current aperture name not in master list,
## current aperture def' not yet stored, store current name and def':

            else
            {
               $self->{layer}{apertureMasterList}{$name} = ( $currentDefinition );
               $self->{layer}{$sourceFile}{apertureNameMapping}{$name} = $name;
            }

         }

      } # . . . . . . . . .  if current line is an aperture definition




## When we see the first line that starts with a 'D', then we've
## passed all the aperture definitions:
## -------------------------------------------------------------------

      if ( $line =~ /^D/ )
      {
         $stillParsing = 0;
      }

   }

#  . 
#   .....
#        .

         } # . . . . . . . . conditional on successful filehandle open
	 else { 
	     print "$rname:  couldn't open '$filename'\n";
	 }

      } # . . . . . . . .  condintional to filter for source file keys

   } # . . . . . . . . . . . . . .  loop to process keys of layer hash


}


sub write_aperture_definitions
{
#--------------------------------------------------------------------#
#
#  PURPOSE:
#
#  For the current gerber layer append the master list of aperture
#  definitions.
#
#--------------------------------------------------------------------#

   my $self = shift;


   my $intermediateFile;   # string,
   my $outFile;            # string,
   my $comment;            # string,
   my $apertureName;       # string,
   my $definition;         # string,
   my $line;               # string,

   my $rname = "write_aperture_definitions";
   my $trace = $self->{trace}{$rname};
   my $msg;




   $msg = "$rname:  writing master aperture list...\n\n";
   print $msg if ($trace);




## Open current layer's output file to append aperture definitions:

   $outFile = $self->{layer}{outfile};
   $intermediateFile = $self->{layer}{workDirectory} . $self->{layer}{outfile} . ".MERGED";


   if ( !open(OUTFILE, ">> $intermediateFile") )
   {
      $msg = "$rname:  couldn't open output file '$intermediateFile' for writing,\n";
      print $msg;
      $msg = "$rname:  unable to write master aperture list for current layer,\n";
      $msg .= "$rname:  returning to caller...\n\n";
      print $msg;
      return (0);
   }



   $comment = "G04 *\n";
   $comment .= "G04 aperture list for tiled file '$outFile':*\n";
   $comment .= "G04 *\n";
   print OUTFILE $comment;



   foreach $apertureName ( keys %{$self->{layer}{apertureMasterList}} )
   {
      $definition = $self->{layer}{apertureMasterList}{$apertureName};
      $line = "%AD" . $apertureName . $definition . "\n";
      print OUTFILE $line;
   }


}





sub substitute_apertures
{
#--------------------------------------------------------------------#
#
#  IMPLEMENTATION:
#
#  This routine, called externally, reads all the lines in each
#  gerber source file, filtering for the aperture references.  These
#  references appear to be lines that are always of the form,
#
#     Dnn or Dnnn
#
#  ...where 'D' is a fixed character followed by a two- or three-
#  digit number.
#
#
#
#--------------------------------------------------------------------#


   my $self = shift;


   my $outFile;        # string,
   my $sourceFile;     # string, holds names of keys in current layer
   my $filename;       # string, holds name of current source file
   my $stillParsing;   # integer, acts as boolean flag
   my $line;           # string, holds a line from current source file


## Diagnostic variables:

   my $rname = "substitute_apertures";
   my $trace = $self->{trace}{$rname};
   my $msg;
   my ($name, $newName); #added
    


   $msg = "$rname:  substituting aperture directives...\n\n";
   print $msg if ($trace);




## Open current layer's output file to append coordinate data,
## aperture names substituted to match master list aperture def's:
## -------------------------------------------------------------------

   $outFile = $self->{layer}{workDirectory} . $self->{layer}{outfile} . ".MERGED";




   if ( !open(OUTFILE, ">> $outFile") )
   {
      $msg = "$rname:  couldn't open output file '$outFile' for writing,\n";
      print $msg;
      $msg = "$rname:  unable to append coordinate data with renamed aperture references,\n";
      $msg .= "$rname:  returning to caller...\n\n";
      print $msg;
      return (0);
   }

## For each file in the passed gerber layer hash tree, search for
## and substitute names of aperture references, 'D' lines among the
## coordinate data:
## -------------------------------------------------------------------

   foreach $sourceFile ( keys %{$self->{layer}} )
   {
      if ( $sourceFile =~ /^infile_/ )
      {
         $filename = $self->{layer}{$sourceFile}{filename};
         $msg = "$rname:  couldn't open '$filename',\n";
     



	 
         if (open(INFILE, "< $filename"))
         {
            $msg = "$rname:  in package '$self->{packageName}',\n";
            $msg .= "$rname:  opened source file, named '$filename',\n";
            $msg .= "$rname:  \n";
            print $msg if ($trace);
            $stillParsing = 1;


            $msg = "G04 *\n";
            $msg .= "G04 next data from source file '$filename', *\n";
            $msg .= "G04 source file key is '$sourceFile'. *\n";
            $msg .= "G04 *\n";
            print OUTFILE $msg;




## Read past header, macro and aperture information:
            $line = ' ';
            while ( $line !~ /^D/ )
            {
               $line = <INFILE>;
            }

#           $msg = "$rname:  passed header, macros, apertures, line holds '$line',\n";
#           print $msg if ($trace);

            seek(INFILE, -(length($line)), 1);

#           $line = <INFILE>;
#           $msg = "$rname:  moved file handle back by " . length($line) . ", line holds '$line',\n";
#           print $msg if ($trace);




## -------------------------------------------------------------------
## Copy coordinate data, and if necessary modify aperture references:
## -------------------------------------------------------------------

            while ( defined( $line = <INFILE> ) && ( $stillParsing) )
            {

## The pattern match below attempts to filter lines which represent
## aperture references, expressed as 'D' followed by a number between
## 10 and 999.  There are other gerber directives such as D01, D02,
## D03 which turn off, turn on, and momentarily flash a light source
## when interpreted in the typical way by gerber speaking plotters.

#              if ( $line =~ /^D/)

               if ( $line =~ /^D[1-9][0-9]+/)
               {
                  ($name) = $line =~ /(D\d+)/;
                  $newName = $self->{layer}{$sourceFile}{apertureNameMapping}{$name} . "*\n";
                  print OUTFILE $newName;

                  $msg = "$rname:  current line is '$line',\n";
                  $msg .= "$rname:  substituting aperture reference '$name' with '$newName',\n";
                  $msg .= "$rname:  \n";
                  print $msg if ($trace);
               }



               elsif ( $line !~ /^M02/ )
               {
                  print OUTFILE $line;
               }



               elsif ( $line =~ /^M02/ )
               {
                  $stillParsing = 0;

                  $msg = "$rname:  found end-of-program directive for source file '$sourceFile',\n";
                  $msg .= "$rname:  line holds '$line',\n";
                  $msg .= "$rname:  \n";
                  print $msg if ($trace);
               }
            }
         } # . . . . . . . . conditional on successful filehandle open
	 else {
             print $msg;
	 }
         close(INFILE);

      } # . . . . . . . .  condintional to filter for source file keys

   } # . . . . . . . . . . . . . .  loop to process keys of layer hash


   print OUTFILE "M02*\n";
   close(OUTFILE);



}





#--------------------------------------------------------------------#
#  By convention, end a package file with 1, so the use or require   #
#  command succeeds.                                                 #
#--------------------------------------------------------------------#

1;


# Apertures.pm

