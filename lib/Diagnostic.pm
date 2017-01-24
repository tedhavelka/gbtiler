#--------------------------------------------------------------------#
#
#  filename:  Diagnostic.pm
#   created:  2002-11-03
#  modified:  2007-03-05
#
#  Diagnostic routines to help in the development of Perl scripts
#  and programs.
#
#
#  Notes:
#
#   +  test_command_line_options(\@ARGV);
#
#   +  test_display_lines(\@lines, $lcount);
#
#
#--------------------------------------------------------------------#

package Diagnostic;
use strict;

our $self = {};

#********************************************************************#
#                                                                    #
#   Constructor:                                                     #
#                                                                    #
#********************************************************************#

sub new
{
   my ($class) = @_; #added
   $self =
   {
      identify     => 0,   # a trace/debugging flag
      packageName  => 0,   # name of this package
      maxShowDepth => 0,   # max' num' recursions in hash display
      indent       => 0,   # diagnostics formatting
   };


#--------------------------------------------------------------------#
#  Initialize part of this package's data structure:                 #
#--------------------------------------------------------------------#

   $self->{identify}     = 0;                 # default setting quiet
   $self->{packageName}  = "Diagnostic.pm";   # package name
   $self->{maxShowDepth} = 10;
   $self->{indent}       = "   ";


#--------------------------------------------------------------------#
#  Let the data structures of this object know their class:          #
#--------------------------------------------------------------------#

   bless ($self, $class); 

   return ($self);
}





#********************************************************************#
#                                                                    #
#   DATA ACCESS ROUTINES:                                            #
#                                                                    #
#********************************************************************#


sub show_tokens
{
#--------------------------------------------------------------------#
#  Display the values (may be string tokens, numbers or other data
#  types) of an array passwed by reference.
#--------------------------------------------------------------------#

   my ($self) = shift;
   my ($tokens, $note) = @_;

   my $pname = $self->{packageName};
   my $rname = "show_tokens";
   my $i = 0;
   my ($msg);
   my $identifier = $pname . " :: " . $rname . ":";
   $msg = $identifier . "\n";




   if ( @$tokens > 0 )
   {

      if (length($note) > 0)
      {
         $msg .= "displaying contents of array holding:\n";
         $msg .= $note . "\n\n";
      }
      else
      {
         $msg .= "displaying contents of array:\n\n";
      }

      print $msg;



      for ($i = 0; $i < @$tokens; $i++)
      {
         print "   $i:  '$tokens->[$i]'\n";
      }

      print "\n";
   }


   else
   {
      $msg .= "passed array tagged '$note' is empty.\n\n";
      print $msg;
   }

}





sub show_hash_keys
{
#--------------------------------------------------------------------#
#
#  RECEIVE:  *  a reference to a hash table
#            *  a descriptive note
#
#  RETURN:   nothing
#
#  PURPOSE:  display the primary keys of the passed hash table
#
#--------------------------------------------------------------------#

   my $self     = shift;
   my $hash_ref = shift;
   my $note     = shift;

   my $name   = "show_hash_keys";
   my @keys   = ();   # ...list of keys in passed hash table
   my $key    = "";   # ...current key being shown
   my $kcount = 0;    # ...count of keys in passed hash table
   my $i      = 1;    # ...local index


   {
      print "   $name:  looking for keys in hash tagged \"$note\",\n"
      if ($note);

      @keys = ( sort keys %{$hash_ref} );
      $kcount = @keys;
      if ($kcount > 0)
      {
         print "   $name:  keys in referenced hash:\n\n" if ($note);
         foreach $key (@keys)
         {
            print "     $i) '$key',\n";
            $i++;
         }
         print "\n";
      }
      else
      {
         print "   $name:  no keys in referenced hash,\n";
      }

      print "\n\n";
   }

}





sub show_hash
{
#--------------------------------------------------------------------#
#
#  RECEIVE:  +  a reference to a hash table
#            +  a descriptive note
#
#  RETURN:   nothing
#
#  PURPOSE:  to display the primary keys of the passed hash table and
#            the values associated with each key.
#
#--------------------------------------------------------------------#

   my $self     = shift;
   my $hash_ref = shift;
   my $note     = shift;

   my @keys   = ();   # ...list of keys in passed hash table
   my $key    = "";   # ...current key being shown
   my $kcount = 0;    # ...count of keys in passed hash table
   my $i      = 1;    # ...local index

   my $msg = "";
   my $rname  = "show_hash";



   @keys = ( sort keys %{$hash_ref} );
   $kcount = @keys;
   if ($kcount > 0)
   {
      $msg = "$rname:  '$note'...\n\n";
      print $msg;

      foreach $key (@keys)
      {
         print "   $i) \{$key}->$hash_ref->{$key},\n";
         $i++;
         }
      print "\n\n";
   }
   else
   {
      $msg = "$rname:  no keys in referenced hash,\n\n";
      print $msg;
   }

}




sub show_hash_tree_primer
{
#--------------------------------------------------------------------#
#
#  RECEIVE:  a hash table reference
#
#  RETURN:   nothing
#
#  PURPOSE:  Allow a single-parameter interface for callers to
#  utilize a two-parameter recursive routine.
#
#  TECHNICAL NOTE:  Because the "show hash tree" routine is typically
#  called externally from another package, and yet is recursive and
#  thus calls itself, there is a problem handling the implicit 
#  parameter that is passed to instantiated Perl packages.  For this
#  reason, this priming routine takes the initial call from some
#  external routine or code, and then calls the show hash tree 
#  routine locally.  That locality is the key, and this arrangement
#  of two routines would not be needed except for the implicitly
#  passed package variable, which itself appears to be a hash table.
#
#--------------------------------------------------------------------#

   my $self  = shift;
   my $hash  = undef;
   my $rname = "show_hash_tree_primer";



   if (@_)
   {
      $hash = shift;
   }
   else
   {
      print "$rname:  no valid hash reference passed.\n\n";
      return;
   }

   show_hash_tree($hash, 1 );

}





sub show_hash_tree_verbose
{
#--------------------------------------------------------------------#
#
#  RECEIVE:  *  a referece to a hash table,
#            *  a starting depth value of 1
#
#  RETURN:   nothing
#
#  PURPOSE:  show all nodes and data contents of keys in each node
#    of a B-tree composed of linked hash tables.
#
#  USAGE:  Call this routine with a hash reference and the value '1'
#    for an accurate starting tree-depth value.
#
#
#  NOTE:  this routine is written to be called externally, from a
#   routine or code in some other file that has access to an instance
#   of this package.
#
#--------------------------------------------------------------------#

   my $hash = shift;
   my $level = shift;

   my @keys         = ();     # hash keys received when called
   my $key          = "";     # name of current key
   my @children     = ();     # hash keys to send when calling
   my $num_children = 0;      # number of hash keys to send
   my $element      = "";     # array elements variable
   my $i            = 0;      # local index
   my ($kcount, $foo, $note);

   my $pname = $self->{packageName};
   my $rname = "show_hash_tree_verbose";
   my $identifier = ( $pname . " :: " . $rname );
   my $indent = $self->{indent};
   my $msg = "";



#--------------------------------------------------------------------#
#  Build an array of sorted keys from the hash table passed to
#  us by the calling code:
#--------------------------------------------------------------------#

   @keys = ( sort keys %{$hash} );
   $kcount = @keys;


#--------------------------------------------------------------------#
#  In case there's a circular reference or some other error that
#  would cause this routine to recurse endlessly, check the level
#  or iteration of recursion we're at and return if we're going to
#  far:
#--------------------------------------------------------------------#

   if ($level > $self->{maxShowDepth})
   {
      print "$rname:  current show depth = $level,\n";
      print "$rname:  maximum show depth = $self->{maxShowDepth},\n";
      print "$rname:  endless-loop safety limit reached, returning...\n\n";
      return;
   }


   print "$rname:  CALLED, BEGINNING...\n";
   print "$rname:  current show depth = $level,\n";

   if ($kcount > 0)
   {
#     foreach $key (@keys)
#     {
#        print "$rname:  key '$key' points to data '$hash->{$key}'\n";
#        if ( $key =~ /HASH/ )
#        {
#           print "  ...last key may be erroneous -- ",
#           "looks like the hash itself.\n";
#        }
#     }

      foreach $key (@keys)
      {
#        last if ($key eq "data");
         print "$rname:  processing key: '$key',\n";
         $foo = $hash->{$key};
         print "$rname:  key holds '$foo',\n";

         if ($foo =~ /^ARRAY/)
         {
            print "$rname:  '$key' points to an array:\n\n";
            $i = 1;
            foreach $element ( @{$hash->{$key}} )
            {
               print "   $i) '$element'\n";
               $i++;
            }
         }
         else
         {
            @children = ( sort keys %{$hash->{$key}} );
            $num_children = @children;
            if ($num_children > 0)
            {
               print "$rname:  '$key' contains one or more keys...\n\n";
               show_hash_tree_verbose( $hash->{$key}, ($level + 1) );
            }
         }
      }
   }

   else
   {
      $msg = $identifier . " :: " . "WARNING" . "\n";
      $msg .= $indent . "no keys in passed hash,\n";
      $msg .= $indent . "caller passed this note for hash:\n";
      $msg .= $indent . "'$note'\n";
      print $msg;
   }

   print "$rname:  RETURNING FROM CALL...\n\n";
}





sub show_hash_tree
{
#--------------------------------------------------------------------#
#
#  RECEIVE:  *  a referece to a hash table,
#            *  a starting depth value of 1
#
#  RETURN:   nothing
#
#  PURPOSE:  show all nodes and data contents of keys in each node
#    of a B-tree composed of linked hash tables.
#
#  USAGE:  Call this routine with a hash reference and the value '1'
#    for an accurate starting tree-depth value.
#
#
#  NOTE:  this routine is written to be called externally, from a
#   routine or code in some other file that has access to an instance
#   of this package.
#
#--------------------------------------------------------------------#

   my $hash = shift;
   my $level = shift;

   my @keys         = ();     # hash keys received when called
   my $key          = "";     # name of current hash key
   my $content      = undef;  # content of current hash key
   my @children     = ();     # hash keys to send when calling
   my $num_children = 0;      # number of hash keys to send
   my $element      = "";     # array elements variable
   my $i            = 0;      # local index

   my $pname = $self->{packageName};
   my $rname = "show_hash_tree";
   my $identifier = ( $pname . " :: " . $rname );
   my $indent = $self->{indent};
   my $msg = "";
   my ($kcount, $note);


#--------------------------------------------------------------------#
#  Build an array of sorted keys from the hash table passed to
#  us by the calling code:
#--------------------------------------------------------------------#

   @keys = ( sort keys %{$hash} );
   $kcount = @keys;


#--------------------------------------------------------------------#
#  In case there's a circular reference or some other error that
#  would cause this routine to recurse endlessly, check the level
#  or iteration of recursion we're at and return if we're going to
#  far:
#--------------------------------------------------------------------#

   if ($level > $self->{maxShowDepth})
   {
      print "$rname:  current show depth = $level,\n";
      print "$rname:  maximum show depth = $self->{maxShowDepth},\n";
      print "$rname:  endless-loop safety limit reached, returning...\n\n";
      return;
   }


   if ($kcount > 0)
   {
      foreach $key (@keys)
      {
         $content = $hash->{$key};
         $indent = (" " x (3 * $level));
         print $indent . "$key -> '$content'\n";

         if ($content =~ /^ARRAY/)
         {
            $i = 1;
            foreach $element ( @{$hash->{$key}} )
            {
               print "$indent   $i) '$element'\n";
               $i++;
            }
         }
         else
         {  if ($content =~ /^HASH/) {                 
            @children = ( sort keys %{$hash->{$key}} );
            $num_children = @children;
            if ($num_children > 0)
            {
               show_hash_tree($hash->{$key}, ($level + 1) ); 
            }
         } }
      }
   }

   else
   {
      $msg = $identifier . " :: " . "WARNING" . "\n";
      $msg .= $indent . "no keys in passed hash,\n";
      $msg .= $indent . "caller passed this note for hash:\n";
      $msg .= $indent . "'$note'\n";
      print $msg;
   }

}





sub test_display_lines
{
   my (@lines, $index) = @_;
   my $response; #added

   print "pf.cgi:  in subroutine test_display_lines...\n";
   print "\$lines: $#lines\n";
   print "\$index: $index\n";
   print "\n";

   print "Enter line number to display or \"quit\":  ";
   $response = <STDIN>;
   $/ = "\n";
   chomp $response;

   while ($response ne "quit")
   {
      $index = int $response;

      if ($index <= $#lines)
      {
         print $lines[$index];
      }
      else
      {
         print "$index out of range of lines in line array.\n";
      }

      print "enter line number to display or \"quit\":  ";
      $response = <STDIN>;
      $/ = "\n";
      chomp $response;
   }

}





sub test_tokenize
{
#--------------------------------------------------------------------#
#                                                                    #
#  Example call for this routine:                                    #
#                                                                    #
#   @tokens = test_tokenize(\@lines);                                #
#                                                                    #
#--------------------------------------------------------------------#

   my ($lines) = @_;
   my $i = 0;
   my @words = ();
   my $word = "";


   print "test_tokenize:  starting...\n";

   for ($i = 0; $i < @$lines; $i++)
   {
      @words = (@words, split(/\s+/, $lines->[$i]));
   }
   print "\n";

   return(@words);


#--------------------------------------------------------------------#
#  A small array element printing loop:                              #
#--------------------------------------------------------------------#
   $i = 0;
   foreach $word (@words)
   {
      print "word[$i]: $word\n";
      $i++;
   }

   print "pf.cgi:  leaving subroutine test_tokenize...\n\n";

   return(@words);
}





sub test_command_line_options
{
   my ($options) = @_;
   my $i = 0;
   

   $i = 0;
   for ($i = 0; $i < @$options; $i++)
   {
      print "ARGV[$i]: $options->[$i]\n";
   }
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


# Diagnostic.pm

