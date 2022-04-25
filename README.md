# NAME

Template::Plex - Templates in (P)erl using (Lex)ical Aliasing

# SYNOPSIS

Import `plex` and `plx` into you package:

```perl
    use Template::Plex;
```

Setup variables/data you want to alias:

```perl
    my $vars={
            size=>"large",
            slices=>8,
            people=>[qw<Kim Sam Harry Sally>
            ]
    };
    local $"=", ";
```

Write a template:

```perl
    #Contents of my_template.plex

    Ordered a $size pizza with $slices slices to share between @$people and
    myself.  That averages @{[$slices/(@$people+1)]} slices each.
```

Load the template with `plex`:

```perl
    my $template= plex "my_template.plex", \%vars;
```

Render it:

```perl
    my $output=$template->render;   

    #OUTPUT
    Ordered a large pizza with 8 slices to share between Kim, Sam, Harry,
    Sally and myself.  That averages 1.6 slices each.     
    
```

Change values and render it again:

```perl
    $vars->{size}="extra large";
    $vars->{slices}=12;
    
    $output=$template->render;

    #OUTPUT
    Ordered a extra large pizza with 12 slices to share between Kim, Sam,
    Harry, Sally and myself.  That averages 2.4 slices each.
```

# DESCRIPTION

This module facilitates the use of perl (not embedded perl) as a text
processing template language and system capable of loading, caching and
rendering powerful templates. 

It does this by implementing a handful of subroutines to perform template
loading/management (i.e. `plex` and `plx`) and also includes a couple of
convenience routines to make processing simpler (i.e. `block` and `jmap`).

[String::Util](https://metacpan.org/pod/String%3A%3AUtil) string filtering routines are also made available in templates
for the most common of filtering tasks.  Of course you can `use` any modules
you like within the template, or define your own subroutines within the
template. The template is just perl!

Conceptually, a `Template::Plex` template is just a string in perl's double
quoted context, with the outer operators removed:

```
    #PERL
    "This is a perl string interpolating @{[ map uc, qw<a b c d>]}"

    #  or

    qq{This is a perl string interpolating @{[ map uc, qw<a b c d>]}}
    

    #PLEX template. Same as PERL syntax, without the outer double quotes
    This is a perl string interpolating @{[ map uc, qw<a b c d>]};

    #OUTPUT is the same for all of the above:
    This is a perl string interpolating A B C D
```

The 'lexical' part of this modules refers to ability of variables to be
aliased into the template (more on this later). It improves the style and usage
of variables in a template while also allowing sub templates to access/override
variables using lexical scoping.

The synopsis example only scratches the surface in terms of what is possible.
For more examples, checkout the examples directory in this distribution. I hope
to add more in the future

# FEATURES

The following are snippets of templates demonstrating some of the feature:

- Templates are written in perl syntax:

    ```
        This template is a valid $perl  code @{[ uc "minus" ]} the outer quotes
    ```

- Templates are compiled into a perl subroutine, with automatic caching (plx)

    ```
        Sub/template is loaded only the first time in this map/loop

        @{[map {plx "path_to_template",{}} qw< a b c d e >]}
                
    ```

- Lexical and package variables accessed/created within templates

    ```
        @{[
                block {
                        $input_var//=1; #set default
                }

        }]
        
        Value is $input_var;
    ```

- Call and create subroutines within templates:

    ```perl
        @{[
                block {
                        sub my_great_calc {
                                my $input=shift;
                                $input*2/5;
                        }
                }

        }]

        Result of calculation: @{[my_great_calc(12)]}
    ```

- 'Include' Templates within templates easily:

    ```
        @{[include("path_to_file")]}
    ```

- Recursive sub template loading

    ```perl
        @{[ plx "path_to_sub_template" ]}
    ```

- Conditional rendering

    ```
        @{[ $flag and $var]}

        @{[ $flag?$var:""]}
        
        @{[
                pl {
                        if($flag){
                                #do stuff       
                        }
                }
        ]}
    ```

- Lists/Loops/maps

    ```perl
        template interpolates @$lists directly
        
        Items that are ok:
         @{[
                do {
                        #Standard for loop
                        my $output;
                        for(@$items){
                                $output.=$_."\n" if /ok/;
                        }
                        $output;
                }
        }]

        More ok items:
        @{[map {/ok/?"$_\n":()} @$items]}

        
    ```

- `use` other modules directly in templates:

    ```perl
        @{[
                block {
                        use Time::HiRes qw<time>
                }
        ]}

        Time of day right now: @{[time]}
    ```

# MOTIATION

- So many templating systems available, yet none use perl as the template language?
- Lexical aliasing allows the input variables to be accessed directly by name
(i.e. `$name`) instead of as a member of a hash ref (i.e.
`$fields->{name}`) or by delimiting with custom syntax (i.e. `<%= name %>`)
- The perl syntax `@{[...]}`  will execute arbitrary perl statements in a double
quoted string. 
- Other templating system are very powerful, but have huge a huge APIs and
options. [Template::Plex](https://metacpan.org/pod/Template%3A%3APlex) could have a very minimal API with perl doing the
hard work

# API

## `plex`

```
    plex $path, $variables_hash, %options
    
```

Creates a new instance of a template, loaded from a scalar, file path or an
existing file handle. 

- `$path`

    This is a required argument.

    If `$path` is a string, it is treated as a file path to a template file. The
    file is opened and slurped with the content being used as the template.

    If `$path` is a filehandle, or GLOB ref, it is slurped with the content being
    used as the template. Can be used to read template stored in `__DATA__` for
    example

    If `$path` is an array ref, the items of the array are joined into a string,
    which is used directly as the template.

- `$variables_hash`

    This is an optional argument but if present must be an empty hash ref `{}` or
    `undef`.

    The top level items of the `$variables_hash` hash are aliased into the
    template using the key name (key names must be valid for a variable name for
    this to operate). This allows an element such as `$fields{name`}> to be
    directly accessible as `$name` in the template and sub templates.

    External modification of the items in `$variable_hash` will be visible in the
    template. This is thee primary mechanism change inputs for subsequent renders
    of the template.

    In addition, the `$variables_hash` itself is aliased to `%fields` variable
    (note the %) and directly usable in the template like a normal hash e.g.
    `$fields{name}`

    If the `$variables_hash` is an empty hash ref `{}` or `undef` then no
    variables will be lexically aliased. The only variables accessible to the
    template will be via the `render` method call.

- `%options`

    These are non required arguments, but must be key value pairs when used.

    Options are stored lexically for access in the template in the variable
    `%options`. This variable is automatically used as the options argument in
    recursive calls to `plex` or `plx`, if no options are provided

    Currently supported options are:

    - **root**

        `root` is a directory path, which if present, is prepended to to the `$path`
        parameter if `$path` is a string (file path).

    - **no\_include**

        Disables the uses of the preprocessor include feature. The template text will
        not be scanned  and will prevent the `include` feature from operating.
        See `include` for more details

        This doesn't impact recursive calls to `plex` or `plx` when dynamically/conditionally
        loading templates.

    - **no\_block\_fix**

        Disables removing of EOL after a `@{[]}` when  the closing `}]` starts on a
        new line. Does not effect `@{[]}` on a single line or embedded with other text

        ```
            eg      
                    
                    Line 1
                    @{[
                            ""
                    ]}              <-- this NL removed by default
                    Line 3  
            
        ```

        In the above example, the default behaviour is to remove the newline after the
        closing `]}` when it is on a separate line. The rendered output would be:

        ```
                    Line1
                    Line3
        ```

        If block fix was disabled (i.e. `no_block_fix` was true) the output would be:

        ```
                    Line1

                    Line3
        ```

    - **package**

        Specifies a package to run the template in. Any `our` variables defined in
        the template will be in this package.  If a package is not specified, a unique
        package name is created to prevent name collisions

- Return value

    The return value is `Template::Plex` object which can be rendered using the
    `render` method

- Example Usage
		my $hash={
			name=>"bob",
			age=>98
		};

    ```perl
                my $template_dir="/path/to/dir";

                my $obj=plex "template.plex", $hash, root=>$template_dir;
    ```

## `plx`

```
    plex $path, $variables_hash, %options
```

Arguments are the same as `plex`.  Similar to the `plex` subroutine, however
it loads, caches and immediately executes the template.  Somewhat equivalent
to:

```
    state $template=plex ...;
    $template->render;
```

The template is cached so that next time `plx` is called from the same
file/line, it reuses the code.

Makes using recursive templates very easy:

```perl
    eg
            @{[ plx "path to sub template"]}
```

Does have the slight overhead of generating cache keys and actually performing
the cache lookup compared to manually caching using `plex`

## `render`

```
    $obj->render($fields);
```

This object method renders a template object created by `plex` into
a string. It takes an optional argument `$fields` which is a reference to a
hash containing field variables. `fields` is aliased into the template as
`%fields` which is directly accessible in the template

```perl
    eg
            my $more_data={
                    name=>"John",
            };
            my $string=$template->render($more_data);
            
            #Template:
            My name is $fields{John}
```

Note that the lexically aliased variables setup in `plex` or `plx` are independent to the
`%fields` variable and can both be used simultaneously in a template

## `include`

```
    @{[include("path")}]

    where $path is path to template file to inject
```

Used in templates only.

This is a special directive that substitutes the text similar to
**@{\[include("path")\]}** with the contents of the file pointed to by path. This
is a preprocessing step which happens before the template is prepared for
execution

This API is only available in templates. If `root` was included in the options
to `plex`, then it is prepended to `path` if defined.

When a template is loaded by `plex` the processing of this is
subject to the `no_include` option. If `no_include` is specified, any
template text that contains the `@{[include("path")}]` text will result in a
syntax error

## pl

## block

```
    block { ... }
    pl { ... }
```

By default this is only exported into a templates namespace.
A subroutine which executes a block just like the built in  `do`. However it
always returns an empty  string.

When used in a template in the `@{[]}` construct, arbitrary statements can be
executed. However, as an empty string is returned, perl's interpolation won't
inject anything at that point in the template.

If you DO want the last statement returned into the template, use the built in

`do`.

```perl
    eg
            
            @{[
                    # This will assign a variable for use later in the template
                    # but WILL NOT inject the value 1 into template when rendered
                    pl {
                            $i=1;
                    }

            ]}


            @{[
                    # This will assign a variable for use later in the tamplate
                    # AND immediately inject '1' into the template when rendered
                    do {
                            $i=1
                    }

            ]}
```

## plex\_clear

```
    plex_clear;
```

**Subject to change**.  Clears all compiled templates from the current level.

## jmap

```
    jmap {block} $delimiter, $array_ref;
```

Performs a join using `$delimiter` between each item in the `$array_ref` after
they are processed through `block`

`$delimiter` is optional with the default being an empty string

Very handy for rendering lists:

```perl
    eg
            <ul>
                    @{[jmap {"<li>$_</li>"} "\n", $items]}
            </ul>
```

## skip

```
    Template with potential output
    @{[ block {
            skip if $flag;
            }
    ]}
    Any more potential output
```

This subroutine prevents the current template from generating rendered output.
Instead it will return an empty string.  Variables can still be manipulated by
template before the `skip` call.

Useful to conditionally skip the body of a template, but configure the variable
hash for preprocessing in a `@{[block{...}]}` structure

# FILTERS

There is no special syntax for filters as in other template languages. Filters
are simply subroutines and you chain them the usual way in perl:

```
            @{[ third_filer second_filter first_filter @data]}
```

To get you started, the string filters from [String::Util](https://metacpan.org/pod/String%3A%3AUtil) are imported into
the template namespace. This includes:

```
    collapse     crunch     htmlesc    trim      ltrim
    rtrim        define     repeat     unquote   no_space
    nospace      fullchomp  randcrypt  jsquote   cellfill
    crunchlines  file_get_contents
```

Please consult the [String::Util](https://metacpan.org/pod/String%3A%3AUtil) documentation for details

# TIPS ON USAGE

## Potential Pitfalls

- Remeber to set `$"` locally to your requied seperator

    The default is a space, however when generating HTML lists for example,
    a would make it easier to read:

    ```
        #Before executing template
        local $"="\n";

        plex ...
    ```

    Or alternatively use `jmap` to explicitly set the interpolation separator each time

- Aliasing is a two way steet

    Changes made to aliased variables external to the template are available inside
    the template (one of the main tenets of this module)

    Changes make to aliased variables internal to the template are available outside
    the template.

- Unbalanced Delimiter Pairs

    Perl double quote operators are smart and work on balanced pairs of delimiters.
    This allows for the delimiters to appear in the text body without error.

    However if your template doesn't have balanced pairs (i.e. a missing "}" in
    javascript/c/perl/etc), the template will fail to compile and give a strange
    error.

    If you know you don't have balanced delimiters, then you can escape them with a
    backslash

    Currently [Template::Plex](https://metacpan.org/pod/Template%3A%3APlex) delimiter pair used is **{ }**.  It isn't changeable in
    this version.

- Are you sure it's one statement?

    If you are having trouble with `@{[...]}`, remember the result of the last
    statement is returned into the template.

    Example of single statements

    ```perl
        @{[time]}                       #Calling a sub and injecting result
        @{[$a,$b,$c,time,my_sub]}       #injecting list
        @{[our $temp=1]}                #create a variable and inject 
        @{[our ($a,$b,$c)=(7,8,9)]}     #declaring a
    ```

    If you are declaring a package variable, you might not want its value injected
    into the template at that point.  So instead you could use `block{..}`  or
    `pl{..}` to execute multiple statements and not inject the last statement:

    ```
        @{[ pl {our $temp=1;} }];
    ```

- Last newline of templates are chomped

    Most text editors insert a newline as the last character in a file.  A chomp is
    performed before the template is prepared to avoid extra newlines in the output
    when using sub templates. If you really need that newline, place an empty line
    at the end of your template

## More on Input Variables

If the variables to apply to the template completely change (note: variables
not values), then the aliasing setup during a `plex` call will not
reflect what you want.

However the `render` method call allows a hash ref containing values to be
used.  The hash is aliased to the `%fields` variable in the template.

```perl
    my $new_variables={name=>data};
    $template->render($new_variables);
```

However to use this data the template must be constructed to access the fields
directly:

```perl
    my $template='my name is $fields{name} and I am $fields{age}';
```

Note that the `%field` is aliased so any changes to it is reflected outside
the template

Interestingly the template can refer to the lexical aliases and the direct
fields at the same time. The lexical aliases only refer to the data provided at
preparation time, while the `%fields` refer to the latest data provided during
a `render` call:

```perl
    my $template='my name is $fields{name} and I am $age

    my $base_data={name=>"jimbo", age=>10};

    my $override_data={name=>"Eva"};

    my $template=plex $template, $base_data;

    my $string=$template->render($override_data);
    #string will be "my name is Eva and I am 10
```

As an example, this could be used to 'template a template' with global, slow
changing variables stored as the aliased variables, and the fast changing, per
render data being supplied as needed.

## Security

This module uses `eval` to generate the code ref for rendering. This means
that your template, being perl code, is being executed. If you do not know what
is in your templates, then maybe this module isn't for you.

Aliasing means that the template has access to variables outside of it.
That's the whole point. So again if you don't know what your templates are
doing, then maybe this module isn't for you

# ISSUES 

Currently caching of templates when using `plx` is primitive. It works, but
management will likely change. Manual caching with `state $template=plex ...`
gives you better control and performance

Debugging templates could be much better

Unless specifically constructed to write to file, templates are completely
processed in memory.

`plx` caching will not be effective with literal templates unless they are stored in an anonymous array.

# SEE ALSO

Yet another template module right? 

Do a search on CPAN for 'template' and make a cup of coffee.

# REPOSITORY and BUG REPORTING

Please report any bugs and feature requests on the repo page:
[GitHub](http://github.com/drclaw1394/perl-template-plex)

# AUTHOR

Ruben Westerberg, <drclaw@mac.com>

# COPYRIGHT AND LICENSE

Copyright (C) 2022 by Ruben Westerberg

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, or under the MIT license
