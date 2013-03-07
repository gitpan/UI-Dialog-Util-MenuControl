package UI::Dialog::Util::MenuControl; ## Produces a simple progress bar


our $VERSION='0.02';


use strict;
use Carp;
use vars qw($VERSION);



# It is an OO class to render a Dialog menu by a tree of array and hashes
# with specific form.
# a shell. It does not use curses and has no large dependencies.
#
#
# SYNOPSIS
# ========
#
#
#    use UI::Dialog::Util::MenuControl;
#    
#    my $tree = {
#                    title       =>  'Conditinal behaviour',
#                    entries     =>  [
#                                        {
#                                            title       =>  'entry A (prework for B)',
#                                            function    =>  \&doA,
#                                            condition   =>  undef,
#                                        },
#                                        {
#                                            title       =>  'entry B',
#                                            function    =>  \&doB,
#                                            condition   =>  \&aWasCalled,
#                                        },
#                                        {
#                                            title       =>  'reset A (undo prework)',
#                                            function    =>  \&resetA,
#                                            condition   =>  \&aWasCalled,
#                                        },
#                                        {
#                                            title       =>  'has also submenus',
#                                            entries     =>  [
#                                                                {
#                                                                    title   =>  'sub b 1',
#                                                                },
#                                                                {
#                                                                    title   =>  'sub b 2',
#                                                                },
#                                                            ]
#                                        },
#                    
#                                    ],
#                };
#    
#    
#    
#    my $menu_control = UI::Dialog::Util::MenuControl->new( menu => $tree );
#    
#    $menu_control->run();
#
# To build a menu, you can nest nodes with the attributes
#   
#   title
#   function    a reference to a function.
#   condition   a reference to a function given a boolean result whether to display the item or not
#   entries     array ref to further nodes
#   context     a 'self" for the called function
#   
#      
#      ... 
#      
#      our $objA = Local::UsecaseA->new();
#      
#      
#      my $tree = {
#                      title       =>  'Conditinal behaviour',
#                      entries     =>  [
#                                          {
#                                              title       =>  'entry B',
#                                              function    =>  \&doB,
#                                              condition   =>  \&Local::UsecaseA::check,
#                                              context     =>  $objA,
#                                          },
#                      
#                                      ],
#                  };
#
#  In this example an object objA has been loaded before and provides a check() method.
#  To run this check method in $objA context, you can tell a context to the node.
#
#  What does the absolute same:
#
#      my $tree = {
#                      title       =>  'Conditinal behaviour',
#                      entries     =>  [
#                                          {
#                                              title       =>  'entry B',
#                                              function    =>  \&doB,
#                                              condition   =>  sub{ $objA->check() },
#                                          },
#                      
#                                      ],
#                  };
#
#      
#
# Please consult the example files for more.
#
#
#
# LICENSE
# =======   
# You can redistribute it and/or modify it under the conditions of LGPL.
# 
# AUTHOR
# ======
# Andreas Hernitscheck  ahernit(AT)cpan.org


# parameters
#
#   context             context object wich can be used for all called procedures (self)
#   backend             UI::Dialog Backend engine. E.g. CDialog (default), GDialog, KDialog, ...
#   backend_settings    Values as hash transfered to backend constructor
#   menu                Tree structure (see example above)
sub new { 
    my $pkg = shift;
    my $self = bless {}, $pkg;
    my $param = { @_ };

    if ( not $param->{'menu'} ){ die "needs menu structure as key \'menu\'" };
    my $menu = $param->{'menu'};

    %{ $self } = %{ $param };
  
    my $bset = $param->{'backend_settings'} || {};

    $bset->{'listheight'} ||= 10;
    $bset->{'height'}     ||= 20;

    # if no dialog is given assume console and init now
    my $use_backend = $param->{'backend'} || 'CDialog';
    my $backend_module = "UI::Dialog::Backend::$use_backend";

    #require $backend_module;
    eval("require $backend_module");
    if ( $@ ){ die $@ };

    my $backend = $backend_module->new( %{ $bset } );
    $self->dialog( $backend );


    # set first node as default
    $self->_currentNode( $menu );

    return $self;
}


# Main loop method. Will return when the user selected the last exit field.
sub run{
    my $self = shift;

    while (1){
        last if not $self->showMenu();
    }

    return;
}


# Main control unit, but usually called by run().
# If you call it by yourself, you have to build your own loop around.
sub showMenu {
    my $self = shift;
    my $dialog = $self->dialog();
    my $pos = $self->_currentNode();

    my $title = $pos->{'title'};
    

    my $retval = 1;


    # node context or global or undef
    my $context = $pos->{'context'} || $self->{'context'} || undef;

    # prepare entries and remember further refs by
    # the selected number
    my @list;
    my $c = 0;
    my $entries = {};
    menubuild: foreach my $e ( @{ $pos->{'entries'} } ) {
      
        # context per element entry?
        my $context_elem = $e->{'context'};

        # you can skip menu entries if a condition is false.
        # it is a boolean return of a function. So you can
        # use moose's attributes.
        if ( exists $e->{'condition'} && defined($e->{'condition'}) ){
            if ( not &{$e->{'condition'}}( $context_elem || $context) ){
                next menubuild;
            } 
        }
        
        $c++; # is the entry number
        push @list, $c, $e->{'title'}; # title shown in the menu
        
        $entries->{ $c } = $e;
    }
    
    
    my $sel = $dialog->menu(
                        text => $title,
                        list => \@list,
                      );
                      
    # selection in the menu?
    if ( $sel ) {
        
        # does the selected item has a submenu?
        if ( $entries->{ $sel }->{'entries'} ){
       
            $self->_currentNode(  $entries->{ $sel } );
            $self->_currentNode()->{'parent'} = $pos;
            $self->showMenu();            
            
        }elsif( $entries->{ $sel }->{'function'} ){ # or is it a function call?
            &{ $entries->{ $sel }->{'function'} }( $context );
        }
        
    }else{
        # selected 'cancel' means go to partent if exists or exit app
        if ( $pos->{ 'parent' } ) {
            $self->_currentNode(  $pos->{ 'parent' } );
            $self->showMenu();
        }else{
            $retval = 0;
            exit; ## top menu cancel, does an exit
        }
        

    }
    
    return $retval;                      
}

# Points to the current displayed node in the menu tree.
sub _currentNode{
    my $self = shift;
    my $node = shift;

    if ( $node ){
        $self->{'current_node'} = $node;
    }

    return $self->{'current_node'};
}


# Holds the backend dialog system.
sub dialog{
    my $self = shift;
    my $backend = shift;

    if ( $backend ){
        $self->{'backend'} = $backend;
    }

    return $self->{'backend'};
}



1;


#################### pod generated by Pod::Autopod - keep this line to make pod updates possible ####################

=head1 NAME

UI::Dialog::Util::MenuControl - Produces a simple progress bar


=head1 SYNOPSIS



   use UI::Dialog::Util::MenuControl;
   
   my $tree = {
                   title       =>  'Conditinal behaviour',
                   entries     =>  [
                                       {
                                           title       =>  'entry A (prework for B)',
                                           function    =>  \&doA,
                                           condition   =>  undef,
                                       },
                                       {
                                           title       =>  'entry B',
                                           function    =>  \&doB,
                                           condition   =>  \&aWasCalled,
                                       },
                                       {
                                           title       =>  'reset A (undo prework)',
                                           function    =>  \&resetA,
                                           condition   =>  \&aWasCalled,
                                       },
                                       {
                                           title       =>  'has also submenus',
                                           entries     =>  [
                                                               {
                                                                   title   =>  'sub b 1',
                                                               },
                                                               {
                                                                   title   =>  'sub b 2',
                                                               },
                                                           ]
                                       },
                   
                                   ],
               };
   
   
   
   my $menu_control = UI::Dialog::Util::MenuControl->new( menu => $tree );
   
   $menu_control->run();

To build a menu, you can nest nodes with the attributes
  
  title
  function    a reference to a function.
  condition   a reference to a function given a boolean result whether to display the item or not
  entries     array ref to further nodes
  context     a 'self" for the called function
  
     
     ... 
     
     our $objA = Local::UsecaseA->new();
     
     
     my $tree = {
                     title       =>  'Conditinal behaviour',
                     entries     =>  [
                                         {
                                             title       =>  'entry B',
                                             function    =>  \&doB,
                                             condition   =>  \&Local::UsecaseA::check,
                                             context     =>  $objA,
                                         },
                     
                                     ],
                 };

 In this example an object objA has been loaded before and provides a check() method.
 To run this check method in $objA context, you can tell a context to the node.

 What does the absolute same:

     my $tree = {
                     title       =>  'Conditinal behaviour',
                     entries     =>  [
                                         {
                                             title       =>  'entry B',
                                             function    =>  \&doB,
                                             condition   =>  sub{ $objA->check() },
                                         },
                     
                                     ],
                 };

     

Please consult the example files for more.





=head1 DESCRIPTION

It is an OO class to render a Dialog menu by a tree of array and hashes
with specific form.
a shell. It does not use curses and has no large dependencies.




=head1 REQUIRES

L<Carp> 


=head1 METHODS

=head2 new

 $obj = UI::Dialog::Util::MenuControl->new( menu => $tree );

parameters

  context             context object wich can be used for all called procedures (self)
  backend             UI::Dialog Backend engine. E.g. CDialog (default), GDialog, KDialog, ...
  backend_settings    Values as hash transfered to backend constructor
  menu                Tree structure (see example above)


=head2 dialog

 $obj->dialog();

Holds the backend dialog system.


=head2 run

 $obj->run();

Main loop method. Will return when the user selected the last exit field.


=head2 showMenu

 $obj->showMenu();

Main control unit, but usually called by run().
If you call it by yourself, you have to build your own loop around.



=head1 AUTHOR

Andreas Hernitscheck  ahernit(AT)cpan.org


=head1 LICENSE

You can redistribute it and/or modify it under the conditions of LGPL.



=cut

