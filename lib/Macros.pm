#--------------------------------------------------------------------#
#
#   project:  gbtiler 2.0
#  filename:  Macros.pm
#   created:  2002-11-13
#  modified:  2007-03-05
#
#...;....1....;....2....;....3....|....4....;....5....;....6....;....7



#--------------------------------------------------------------------#
#
#  SYNOPSIS:
#
#  This Perl package is designed to create a list of uniquely named
#  and defined RS274X gerber macro definitions, from a set of one or
#  more gerber source files.
#
#  This job is trivial when there is only a single source file to
#  parse, but typically the gbtiler program as whole is used to 
#  process multiple input files.
#
#  Primary issues of concern for the macros package include,
#
#     +  macro name collisions
#     +  macro definition duplicates
#     +  old-name to new-name mappings for each source file
#
#
#
#  ERROR CHECKING NOT PRESENT:
#
#  This package assumes correctly formatted source gerber files.
#  These routines are not designed to check for malformed or duplicate
#  macro definitions, which would be a nice feature to add.
#
#--------------------------------------------------------------------#



package Macros;
use strict;
our $self = {};

#====================================================================#
#                                                                    #
#  Constructor:                                                      # 
#                                                                    #
#====================================================================#

sub new
{
#--------------------------------------------------------------------#
#  Declare an anonymous hash table:
#--------------------------------------------------------------------#
   my ($class) = @_; 



#--------------------------------------------------------------------#
#  Assign some default values to the object's data elements:         #
#--------------------------------------------------------------------#

   $self =

   {

      projectName => 0,    # name of project to which this package
                           # belongs

      packageName => 0,    # name of this package

      diagnostic  => 0,    # reference to a diagnostics package

      trace       => {},   # a sub-hash of flags for tracing and
                           # and diagnostics generation on a
                           # per-routine basis


      layer       => {},    # reference to sub-hash holding the
                           # current gerber layer in tiling process

   };



## Further define parts of the anonymous hash data structure of this
## gbtiler Perl package:
## -------------------------------------------------------------------

   $self->{packageName} = "Macros.pm";

   $self->{trace}{new}                      = 0;
   $self->{trace}{initialize}               = 0;
   $self->{trace}{store_macros}             = 0;
   $self->{trace}{extract_macro_name_from}  = 0;
   $self->{trace}{check_macro_definition}   = 0;
   $self->{trace}{construct_new_macro_name} = 0;
   $self->{trace}{write_macro_definitions}  = 0;



## Let the object know it's class or package:
## -------------------------------------------------------------------

   bless ($self, $class); 

   return $self;

}





#====================================================================#
#                                                                    #
#   Data access methods:                                             #
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





sub store_macros
{
#--------------------------------------------------------------------#
#
#  RECEIVE:  a reference to a hash table, representing the layer
#            of gerber files currently being tiled.
#
#  RETURN:   nothing explicitly, but implicitly the passed layer
#            hash table or tree gets new information.  In this case
#            the data added to the job hash tree are lines for each
#            source gerber file that define macros.
#
#  PURPOSE:  to extract and store gerber macro definitions from each
#            gerber file specified in the current layer in the tiling
#            process.
#
#--------------------------------------------------------------------#


## -------------------------------------------------------------------
##
## IMPLEMENTATION NOTES:
##
## When we reach the last line of a macro, we need to determine
## whether the current macro has already been stored.  First we check
## by its name whether a macro exists in the master, renamed macro
## list.  If the name doesn't appear here, then we copy the current
## macro definition to the master list.
##
## If the macro name appears in the master list of potentially renamed 
## macros, then we compare macro definitions, since names may be alike
## but definitions different.
##
## If the current macro and the already-stored macro definitions
## differ, then we need to construct a unique name and again store
## the definition in the master, renamed macros list.  Storing takes
## place via a routine that receives pointers to two arrays.  As of
## gbtiler 2.0 work on 2004-07-21, the current macro being processed
## is stored as a name and an array of defining lines in the data
## structures:
##
##
##   $self{layer}{$macroNameCurrent};   # holds name of current macro
##   $self{layer}{$macroDefCurrent};    # holds def' of current macro
##
##
## Suppose in our list of stored, sometimes renamed macros there's a
## macro by the name of the current macro.  Then the following key
## points to the stored macro to which we want to compare the just-
## parsed, current macro:
##
##
##   $self{layer}{macrosRenamed}{<current macro name>};
##
##
## When macro renaming occurs, the 'old name new name' pair is stored
## in a hash within the current source file's hash:
##
##
##   $self{layer}{$sourceFile}{macroNameMapping}{$macroName} = $newMacroName;
##                  |
##   (key to source file hash in layer)
##
##
## Each source file has potentially its own mapping of original macro
## names to new macro names.
##
## -------------------------------------------------------------------


   my $self = shift;


   my $sourceFile;         # string, holds names of layer hash keys
   my $filename;           # string, holds current source filename
   my $line;               # string, holds current line in process
#  my $lineCount;          # integer,
   my $stillParsing;       # integer, acts as boolean flag
   my $onMacro;            # integer, acts as boolean flag
   my $macroName;          # string, temporary parsing variable
   my $newMacroName;       # string, temporary parsing variable
   my $macroDefNotStored;  # integer, acts as boolean flag
   my $macroLine;          # string, temporary parsing variable


## Diagnostic variables:

   my $rname = "store_macros";
   my $trace = $self->{trace}{$rname};
   my $msg;
   my ($lineCount); 



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
	    $msg = "$rname:  in package '$self->{packageName}',\n";
	    $msg .= "$rname:  opened source file, named '$filename',\n";
	    $msg .= "$rname:  \n";
	    print $msg if ($trace);

            $lineCount = 0;      # running count of lines parsed
            $stillParsing = 1;   # boolean flag
            $onMacro = 0;        # boolean flag

## -------------------------------------------------------------------
## Main parsing block for macros:
## 
## This loop exits either after reading the first gerber file line 
## which begins with a 'D' character, or after reading all file lines,
## whichever event occurs first.
## -------------------------------------------------------------------

            while ( defined( $line = <INFILE> ) && ( $stillParsing) )
            {

               $lineCount++;


## Remove trailing white space from lines of the current source file:

               while ( $line =~ /\s$/ )
               {
                  chop( $line = $line );
               }


               $msg = "$rname:  parsing line $lineCount = '$line',\n";
               print $msg if ($trace);



               if ( $line =~ /AM/ )
               {
                  $onMacro = 1;
                  $self->{layer}{macroDefCurrent} = ();
                  $macroName = extract_macro_name_from($line);

                  $msg = "$rname:  found first line of macro '$macroName'!\n";
                  print $msg if ($trace);
               }



               if ( $line =~ /^[\*]*%$/ )
               {
                  push ( @{$self->{layer}{macroDefCurrent}}, $line );
                  $onMacro = 0;

                  if ($trace)
                  {
                     $msg = "$rname:  found last line of macro '$macroName',\n";
                     $msg .= "$rname:  macro lines are:\n\n";
                     print $msg;
                     $self->{diagnostic}->show_tokens( $self->{layer}{macroDefCurrent} );

                     $msg = "$rname:  master list holds:\n\n";
                     print $msg;
                     $self->{diagnostic}->show_hash_tree_primer( $self->{layer}{macroMasterList} );

                     print "\n";
                  }



## Check whether the macro name appears in the master list:

                  if ( exists $self->{layer}{macroMasterList}{$macroName} )
                  {

                     $macroDefNotStored = check_macro_definition( $macroName );


## If the macro name exists in the master list but it's definition
## differs from the current macro, then build a new macro name by
## which to store the probably as-yet-unique macro definition:

                     if ( $macroDefNotStored )
                     {

                        $newMacroName = construct_new_macro_name( $macroName );

                        $self->{layer}{macroMasterList}{$newMacroName} = ();

                        foreach $macroLine ( @{$self->{layer}{macroDefCurrent}} )
                        {
                           push ( @{$self->{layer}{macroMasterList}{$newMacroName}}, $macroLine );
                        }

## Only when adding a renamed macro to the master list, must we also
## update macro name mapping for the current gerber file:
## -------------------------------------------------------------------

                        $self->{layer}{$sourceFile}{macroNameMapping}{$macroName} = $newMacroName;

                        if ($trace)
                        {
                           $msg = "$rname:  macro '$macroName' already in master list,\n";
                           $msg .= "$rname:  new macro name is '$newMacroName',\n";
                           $msg .= "$rname:  added new macro named '$newMacroName',\n";
                           $msg .= "$rname:  master list holds:\n\n";
                           print $msg;
                           $self->{diagnostic}->show_hash_tree_primer( $self->{layer}{macroMasterList} );
                           print "\n";
                        }
                     }
                  }

## If the current macro name doesn't appear in the master list, then
## add a key by this name, and assign the current macro name to the
## new name variable, in order to store the trivial "old name" to
## "same old name" mapping in the current file's mapping hash:
## -------------------------------------------------------------------

                  else
                  {
                     $self->{layer}{macroMasterList}{$macroName} = ();
                     foreach $macroLine ( @{$self->{layer}{macroDefCurrent}} )
                     {
                        push ( @{$self->{layer}{macroMasterList}{$macroName}}, $macroLine );
                     }

                     $msg = "$rname:  added macro '$macroName' to master list,\n";
                     print $msg if ($trace);
                  }

               }



               if ( $line =~ /^D/ )
               {
                  $stillParsing = 0;
                  $onMacro = 0;
               }



               if ( $onMacro )
               {
                  push ( @{$self->{layer}{macroDefCurrent}}, $line );
               }

            }



         } # . . . . . . . . conditional on successful filehandle open
	 else {
	     print "$rname:  couldn't open '$filename'\n";
	 }

      } # . . . . . . . .  condintional to filter for source file keys

   } # . . . . . . . . . . . . . .  loop to process keys of layer hash

}


sub extract_macro_name_from
{
#--------------------------------------------------------------------#
#
#  RECEIVE:  the first line of a Gerber format macro
#
#  RETURN:   the name of this macro, extracted from the line
#
#--------------------------------------------------------------------#
 
   my $line = shift;


   my @temp;
   my $macroName;

   my $rname = "extract_macro_name_from";
   my $trace = $self->{trace}{$rname};
   my $msg;
   my ($macro_name); 



## Check whether the passed line looks like the first line of a 
## typical gerber macro definition:
## -------------------------------------------------------------------

   if ( $line =~ /AM/ )
   {
      @temp = split( /AM/, $line );
      $macroName = $temp[1];

      while ( $macroName =~ /\s$/ )
      {
         chop($macroName = $macro_name);
      }
   }

   else
   {
      $msg = "$rname:  received line holding '$line',\n";
      $msg .= "$rname:  does not appear to be a first macro line,\n";
      $msg .= "$rname:  does not appear to be a first macro line,\n";
      print $msg;
   }


   while ( $macroName =~ /[\*]$/ )
   {
      print "$rname:  trimming macro name '$macroName',\n" if ($trace);
      chop($macroName = $macroName);
   }


   return $macroName;

}





sub check_macro_definition
{
#--------------------------------------------------------------------#
#
#  RECEIVE:  name of the current macro
#
#
#  RETURN:   0 ...if passed macro definition matches one in this 
#                 package's macro hash table.
#
#            1 ...if the like-named macros differ
#
#
#  PURPOSE:  check the definition of the current macro, the macro
#  just parsed but not yet stored in the master list, against the
#  definition of the macro already stored with the same name.
#
#
#  NOTES:  this routine is called internally
#
#--------------------------------------------------------------------#
 
   my $macroName = shift;


## Declaring variables:

   my $index;               # integer, local array index
   my $macroLineStored;     # integer, acting as boolean flag
   my $macroLineCurrent;    # integer, acting as boolean flag
   my $result;              # integer, acting as boolean flag


## Initializing additional local variables for diagnostics:

   my $rname = "check_macro_definition";
   my $trace = $self->{trace}{$rname};
   my $msg = "";
   my ($currentLineCount, $storedLineCount, $i); 



## Begin with the assumption that current and stored macros differ:
## -------------------------------------------------------------------

   $result = 0;


## Check line counts in each macro:

   $currentLineCount = $#{$self->{layer}{macroDefCurrent}}; 
   $storedLineCount =  $#{$self->{layer}{macroMasterList}{$macroName}}; 
   if ( $currentLineCount != $storedLineCount )
   {
      $result = 1;
   }


   else
   {
      for ($index = 0; $index < $currentLineCount; $index++)
      {
         $macroLineCurrent = $self->{layer}{macroDefCurrent}[$index];
         $macroLineStored = $self->{layer}{macroMasterList}{$macroName}[$index];

         if ($macroLineCurrent ne $macroLineStored)
         {
            $result = 1;
         }


         if ($trace)
         {
            $msg = "$rname:  passed line $i = '$macroLineCurrent'\n";
            $msg .= "$rname:  stored line $i = '$macroLineStored'\n\n";
            print $msg if ($trace);
         }
      }
   }

   return $result;

}





sub construct_new_macro_name
{
#--------------------------------------------------------------------#
#
#  RECEIVE:  a macro name that already exists in the master list of
#            stored macros,
#
#  RETURN:   a macro name modified to be unique in that master list.
#
#--------------------------------------------------------------------#

   my $macroName = shift;

   my $newMacroName;
   my $instance;
   my $kk;


   my $rname = "construct_new_macro_name";
   my $trace = $self->{trace}{$rname};
   my $msg;




## Update the "macro name collision count" list:

   if ( exists $self->{layer}{macroNameCollisions}{$macroName} )
   {
      $self->{layer}{macroNameCollisions}{$macroName}++;
   }
   else
   {
      $self->{layer}{macroNameCollisions}{$macroName} = 1;
   }

   $instance = $self->{layer}{macroNameCollisions}{$macroName};
   $msg .= "$rname:  collision count for this macro is '$instance',\n";
   print $msg if ($trace);



## Remove the Gerber "end-of-line" character, the asterisk:

      while ( $macroName =~ /[\*]$/ )
      {
         print "$rname:  trimming macro name '$macroName',\n" if ($trace);
         chop($macroName = $macroName);
      }



## Construct the new macro name...
##
##  +  get an instance number, a "collision count" of the name that
##     is being replaced.
##
##  +  format a string containing that instance number in a three-
##     digit, fixed format.  Also include the name of this program
##     This string is highly unlikely to appear as an existing macro 
##     name in any Gerber source file.
##
## -------------------------------------------------------------------

   $kk = sprintf("_%0*d", 3, $instance);
   $newMacroName = $macroName . $kk;


   $msg = "$rname:  number of collisions for macro '$macroName' is '$instance',\n\n";
   print $msg if ($trace);


## NOTE:
##
## The termination of the first line of a macro definition may
## at some point require characters other than a single asterisk.
## This comment is here to remind the author or other programmers
## of this possibility.  At present the following line terminates
## all modified macro names (first lines of macro definitions):
## -------------------------------------------------------------------

   $newMacroName = $newMacroName . "*";



   if ($trace)
   {
      $msg = "$rname:  colliding macro name... '$macroName'.\n";
      $msg .= "$rname:  new macro name......... '$newMacroName'.\n\n";
      print $msg;
   }



   return $newMacroName;

}





sub write_macro_definitions
{


   my $self = shift;


   my $intermediateFile;   # string,
   my $outFile;            # string,
   my $comment;            # string,
   my $macroName;          # string,
   my $macroLine;          # string,

   my $rname = "write_macro_definitions";
   my $trace = $self->{trace}{$rname};
   my $msg;




   $msg = "$rname:  writing master macro list...\n\n";
   print $msg if ($trace);




## Open current layer's output file to macro aperture definitions:

   $outFile = $self->{layer}{outfile};
   $intermediateFile = $self->{layer}{workDirectory} . $self->{layer}{outfile} . ".MERGED";


   if ( !open(OUTFILE, ">> $intermediateFile") )
   {
      $msg = "$rname:  couldn't open output file '$intermediateFile' for writing,\n";
      print $msg;
      $msg = "$rname:  unable to write master macro list for current layer,\n";
      $msg .= "$rname:  returning to caller...\n\n";
      print $msg;
      return (0);
   }



   $comment = "G04 *\n";
   $comment .= "G04 macro definitions for tiled file '$outFile':*\n";
   $comment .= "G04 *\n";
   print OUTFILE $comment;



   foreach $macroName ( keys %{$self->{layer}{macroMasterList}} )
   {
      foreach $macroLine ( @{$self->{layer}{macroMasterList}{$macroName}} )
      {
         print OUTFILE $macroLine . "\n";
      }

   }


   close(OUTFILE);


}





#--------------------------------------------------------------------#
#  By convention, end a package file with 1, so the use or require   #
#  command succeeds.                                                 #
#--------------------------------------------------------------------#

1;


# Macros.pm

