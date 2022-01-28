# NAME

Template::Plex - Templates with Perl and Lexical Aliasing

# SYNOPSIS

```perl
    use Template::Plex;

    #Data for templates alias and access
    my $base_data={name=>"James", age=>"12", fruit=>"banana"};

    my $inline_template='$name\'s age $age and favourite fruit is $fruit'

    my $ren=plex [$inline_template], $base_data, $root;

    #       or

    my $ren=plex $path_to_a_file, $base_data, $root;

    #       or

    my $ren=plex $file_handle, $base_data, $root;


    #Render with the values aliased in $base_data
    $render->();            
    #
    #=>     James's age is 12 and favourite fruit is banana

    #Update the data, 
    $base_data->{qw<name,fruit>}=qw<John apple>;

    #Rendering again will use updated aliased values
    $render->();            
    #
    #=>     John's age is 12 and favourite fruit is apple
```

# DESCRIPTION

A very small, very powerful templating mechanism. After all, the template
language is perl itself. No not embedded perl, just perl.  Its key goals and features are:

- Templates are 99.9% perl syntax
- Lexical aliasing for performance and style
- Include Templates withing templates easily

This module uses the experimental feature **refaliasing** which may or may not
be around int later perl versions

As perl is doing the heavy lifting in the syntax deparment, the actual code is
quite small. The documentaion is larger (significantly) in byte size. In that
spirit, this module does no management of templates.

# MOTIATION

So many templating systems available, but none of them that I know of actually
use perl as the template language. There are lots of 'embedded perl' templating
modules, but that is a different beast.  Also, I wanted to use lexical aliasing
as it can have good performance and style benefits. Finally, instead of OO over
management, a consice functional API would be nice.

# TEMPLATE SYNTAX

Well, its just perl. Seriously. A template is a perl program with the two following constraints:

- 1. The program consists only of perl syntax permissible in a double quoted string
- 2. The outermost double quote operators are ommited from the program/template

This is best illustrated by example.  The following  shows a valid (boring)
template stored in a the scalar `$template`:

```perl
    my $template = 'this is a $adj template';
```

Firstly, the text between the quotes would be a valid double quoted string (the
`$adj` is a scalar to be interpolated into the template).
Secondly the outer double quotes for the string are omitted.

A template could also be stored in a file following the same two rules. Suppose the following is store in a file on in the `__DATA__ ` section:

```
    How many colours are in the rainbow? If you said $count  you would be correct
```

Again, the text is valid withing a double quoted operator and the outer double quotes are
ommited.

Neat!

In otherwords, template looks like plain text, but with double quoted added, it is valid perl code.

# THE POWER OF DOUBLE QUOTE INERPOLATION

Perl has the abiliby to interpolate just about anything into a string. The
following shows examples of valid perl syntax to get you salivating:

### Access to Scalars, Arrays and Hashes

```perl
    This template uses a $scalar and it will also

    access the array element $array->[$index]

    Accessing element $hash->{key} just for fun
```

## Executing a single (or list) of Statements

To achieve this, a neat trick is to dereference an inline reference to an
annonynous array. Thatis `@{[...]}`. The contents of the array is then the
result of the statements.  Sounds like a mouthful, but it is only a couple of
braces:

```perl
    Calling a subrotine @{[ my_sub()} ]}

    Doing math $a + b = @{[ $a+$b ]}

    I like the colours @{[ uc("red"),uc("blue")]}

    My shoppling list @{[ join "\n", map uc, @items]}

    
```

## Executing Multiple Statements

The `do{}` construct executes a block, which can have any number of statements
and returns the last statement executed into the template

```perl
    Executing multiple statments @{[ do {
            my $a=1; 
            $a++; 
            ($a,-$a)

            } ]} in this template
```

## Using/Requiring Modules

Again standard perl syntax for the win

```perl
    Template will call hi res time 
    The time is: @{[ time ]}
    @{[ BEGIN {
            use Time::HiRes qw<time>;
            }
    ]}
```

# API

## `plex`

```
    plex $path, $hash_ref, $root
    where
            $path 
                    the path to a template file to open and slurp
                    or
                    a already opend filehandle/glob reference
                    or
                    an array ref of strings joined into a template

            $hash_ref 
                    hash ref with elements to alias

            $root 
                    directory path to prepend to $path when template include other templates
    
```

If `$path` is a string, it is treated as a file path to a template file. The file is opened and slurped with the content being used as the template

If `$path` is filehandle, or GLOB ref, it is slurped. Can be used to use `__DATA__` section as a template store

If `$path` is an array ref, the items of the array are joined into a stirng, which is used directly as the template.

The `$hash_ref` provides variables to the template. Using refaliasing it is aliased to `%fields` in the render subrotine. The top level items are also aliased into the render subroutine.

$root Is a directory path which if present, is prepeneded to any file path used `plex`. This also applies to 'recursive' templates. This is aliased into the rendere to a variable `$root`

The return value is subroutine reference, which when fills/executes the template with data.

```perl
    eg
            my $hash={
                    name=>"bob",
                    age=>98
            };
            my $template_dir="/path/to/dir";

            my $renderer=plex "template.plex", $hash, $template_dir;


            #/path/to/dir/template.plex
            My name is $name and my age is $age
```

In this example the hash elements `{name}` and `{age}` are aliased to lexical variables `$name` and `$age` which are directly accessable to the template.

## `inject`

```
    @{[inject($path)}]

    where $path is path to template file to inject
```

This special subroutine call is replaced with the contents of the template at `$path`. Once it is replaced, any subsequent instances are also processed recursively.

Only applicable withing a template. This

# MORE ON LEXICAL ALIASING

Any keys present in the hash when `plex` is called are used to construct
lexical variables which are aliases to the hash elements of the same key name.
The hash itself is also aliased to a variable called `%fields` 

So for a `$base_data` hash like this:

```perl
    my $base_data={name=>"jimbo", age=>10};
```

The template can access the fields "name" and age like this:

```perl
    my $template='my name is $name an I am $age';
```

or like this:

```perl
    my $template='my name is $fields{name} and I am $fields{age}';
```

The first uses the lexical variables to skip the hash lookup, and simpler
style.  The caveat is that all fields must exist at the time the template is
prepared.

To change the values and render the template, the same `$base_data` variable
must be manipulated. ie

```
    $base_data->{name}="Tim";
    $render->();
```

This still performs no hash lookups in the rendering and is a very quick way of
rendering the changing data.

## NOT USING LEXICAL ALIASING 

If the data to apply to the template completely changes, it can be passed as a
hash ref to the render code reference.

```perl
    my $new_variable={name=>data};
    $render->($new_variable);
```

However to use this data the template must be constructed to access the fields
directly:

```perl
    my $template='my name is $fields{name} and I am $fields{age}';
```

## HYBRID ACCESS

This is interesting. The template can refer to the lexical aliases and the
direct fields at the same time. The lexical aliases only refer to the data
provided at preparation time, while the field refer to the latest data
provided:

```perl
    my $template='my name is $fields{name} and I am $age
    my $base_data={name=>"jimbo", age=>10};
    my $override_data={name=>"Eva"};

    my $render=plex $template, $base_data;
    my $string=$render($override_data);
    #string will be "my name is Eva and I am 10
```

# SECURITY

This module uses `eval` to generate the code ref for rendering. This means
that your template, being perl code, is being executed. If you do not know what
is in your templates, then maybe this module isn't for you.

To mitigate the security risk, the rendering code refs should be generated  and
cached, so they are not needing to be run during normal execution. That will
provide faster rendering and also, prevent unknown templates from accidentally
being executed.

# SEE ALSO

Yet another template module right? 

Do a search on CPAN for 'template' and make a cup of coffee.

# AUTHOR

Ruben Westerberg, <drclaw@mac.com>

# COPYRIGHT AND LICENSE

Copyright (C) 2021 by Ruben Westerberg

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, or under the MIT license
