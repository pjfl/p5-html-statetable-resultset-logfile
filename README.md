# Name

HTML::StateTable::ResultSet::Logfile - Iterator pattern for viewing logfiles

# Synopsis

    use HTML::StateTable::ResultSet::Logfile;

# Description

An imitation of a [DBIx::Class](https://metacpan.org/pod/DBIx%3A%3AClass) resultset object

# Configuration and Environment

Defines the following attributes;

- base

    An instance of [File::DataClass::IO](https://metacpan.org/pod/File%3A%3ADataClass%3A%3AIO) which represents the directory that
    contains the log files. Required

- complete

    A mutable boolean which is true if the results list contains all the rows
    in the logfile. It is false when the results list only contains a partial
    view of the logfile

- count

    Synonym for `total_results`

- current\_source\_alias

    A string which defaults to `me`. Needed by [HTML::StateTable](https://metacpan.org/pod/HTML%3A%3AStateTable)

- extension

    A string which default to `log`. The extension that all log files are expected
    to have

- page

    An integer that defaults to 1. The number of the page of results that is being
    requested

- page\_size

    An integer that defaults to 0. The size of the page of results that is being
    requested. If non zero paging is turned on

- paging

    A bool which tracks whether paging is turned on

- result\_class

    A required loadable classname. The `build_results` method in the child class
    will use this to inflate lines from the result source

- table

    Parent table object reference

- total\_results

    The total number of objects in the resultset

# Subroutines/Methods

- build\_results

    Default constructor that returns an empty array reference. Expected to be
    overridden in a child class by a method which returns a reference to an array
    of `result_class` objects

- column\_info( column\_name )

    Returns a hash reference containing the data type of the specified
    column. Think [DBIx::Class](https://metacpan.org/pod/DBIx%3A%3AClass) resultsets

- get\_column( column\_name )

    Returns a [HTML::StateTable::ResultSet::Logfile::Column](https://metacpan.org/pod/HTML%3A%3AStateTable%3A%3AResultSet%3A%3ALogfile%3A%3AColumn) object for the given
    column name

- index\_start

    The line number of the first row being displayed in the table

- next

    This is the iterator call to return the next result object

- pager

    Provides [HTML::StateTable](https://metacpan.org/pod/HTML%3A%3AStateTable) with a [Data::Page](https://metacpan.org/pod/Data%3A%3APage) object

- process( results )

    Implements the actual filtering and ordering of the result set. Called from
    the `build_results` method

- reset

    Resets the iterators state whenever one of the request parameters changes

- result\_source

    Required by [HTML::StateTable](https://metacpan.org/pod/HTML%3A%3AStateTable)

- search( where, options )

    Implements enough of [DBIx::Class::Resultset](https://metacpan.org/pod/DBIx%3A%3AClass%3A%3AResultset) search to satisfy
    [HTML::StateTable](https://metacpan.org/pod/HTML%3A%3AStateTable)

# Diagnostics

None

# Dependencies

- [HTML::StateTable](https://metacpan.org/pod/HTML%3A%3AStateTable)

# Incompatibilities

There are no known incompatibilities in this module

# Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=HTML::StateTable::ResultSet.
Patches are welcome

# Acknowledgements

Larry Wall - For the Perl programming language

# Author

Peter Flanigan, `<lazarus@roxsoft.co.uk>`

# License and Copyright

Copyright (c) 2023 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See [perlartistic](https://metacpan.org/pod/perlartistic)

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE
