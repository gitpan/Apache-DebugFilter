package Apache::DebugFilter;

use mod_perl 1.99;

use strict;
use warnings FATAL => 'all';

$Apache::DebugFilter::VERSION = '0.01_02';

use base qw(Apache::Filter);
use Apache::FilterRec ();
use APR::Brigade ();
use APR::Bucket ();
use APR::BucketType ();

use Apache::Const -compile => qw(OK DECLINED);
use APR::Const    -compile => ':common';

sub snoop_connection : FilterConnectionHandler { snoop("connection", @_) }
sub snoop_request    : FilterRequestHandler    { snoop("request",    @_) }

sub snoop {
    my $type = shift;
    my($filter, $bb, $mode, $block, $readbytes) = @_; # filter args

    # $mode, $block, $readbytes are passed only for input filters
    my $stream = defined $mode ? "input" : "output";

    # read the data and pass-through the bucket brigades unchanged
    if (defined $mode) {
        # input filter
        my $rv = $filter->next->get_brigade($bb, $mode, $block, $readbytes);
        return $rv unless $rv == APR::SUCCESS;
        _snoop_bb_dump($type, $stream, $bb, \*STDERR);
    }
    else {
        # output filter
        _snoop_bb_dump($type, $stream, $bb, \*STDERR);
        my $rv = $filter->next->pass_brigade($bb);
        return $rv unless $rv == APR::SUCCESS;
    }
    #if ($bb->empty) {
    #    return -1;
    #}

    return Apache::OK;
}

sub _snoop_bb_dump {
    my($type, $stream, $bb, $fh) = @_;

    # send the sniffed info to STDERR so not to interfere with normal
    # output
    my $direction = $stream eq 'output' ? ">>>" : "<<<";
    print $fh "\n$direction $type $stream filter\n";

    bb_dump($bb, $fh);

}

sub bb_dump {
    my($bb, $fh) = @_;

    my @data;
    for (my $b = $bb->first; $b; $b = $bb->next($b)) {
        $b->read(my $bdata);
        $bdata = '' unless defined $bdata;
        push @data, $b->type->name, $bdata;
    }

    return \@data unless $fh;

    unless (@data) {
        print $fh "  No buckets\n";
        return;
    }

    my $c = 1;
    while (my($btype, $data) = splice @data, 0, 2) {
        print $fh "    o bucket $c: $btype\n";
        print $fh "[$data]\n";
        $c++;
    }
}


1;
__END__

=head1 NAME

Apache::DebugFilter - Debug mod_perl and native Apache2 filters

=head1 Synopsis

  # httpd.conf
  # ----------
  PerlModule Apache::DebugFilter
  # Connection snooping (everything)
  PerlInputFilterHandler  Apache::DebugFilter::snoop_connection
  PerlOutputFilterHandler Apache::DebugFilter::snoop_connection
  
  # HTTP Request snooping (only HTTP request body)
  <Location /foo>
      PerlInputFilterHandler  Apache::DebugFilter::snoop_request
      PerlOutputFilterHandler Apache::DebugFilter::snoop_request
  </Location>

  # in handlers
  #------------
  use Apache::DebugFilter;
  # convert bb to an array of bucket_type => data pairs
  my $ra_data = Apache::DebugFilter::bb_dump($bb);
  while (my($btype, $data) = splice @data, 0, 2) {
      print "$btype => $data\n";
  }

  # dump pretty formatted bb's content to a filehandle of your choice
  bb_dump($bb, \*STDERR);





=head1 Filter Handlers

=head2 C<snoop_connection()>

The C<snoop_connection()> filter handler snoops on request and
response data flow. For example if the HTTP protocol request is
filtered it'll show both the headers and the body of the request and
response.

Notice that in order to see request's input body, the response handler
must consume it.

The same handler is used for input and output filtering. It internally
figures out what kind of stream it's working on.

To configure the input snooper, add to the top level server or virtual
host configuration in httpd.conf:

  PerlInputFilterHandler  Apache::DebugFilter::snoop_connection

To snoop on response output, add:

  PerlOutputFilterHandler Apache::DebugFilter::snoop_connection

Both can be configured at the same time.

If you want to snoop on what an output filter MyApache::Filter::output
does, put the snooper filter after it:

  PerlOutputFilterHandler MyApache::Filter::output
  PerlOutputFilterHandler Apache::DebugFilter::snoop_connection

On the contrary, to snoop on what an input filter
MyApache::Filter::input does, put the snooper filter before it:

  PerlInputFilterHandler Apache::DebugFilter::snoop_connection
  PerlInputFilterHandler MyApache::Filter::input

This is because C<snoop_connection> is going to be invoked first and
immediately call C<MyApache::Filter::input> the input filter for
data. Only when the latter returns, C<snoop_connection> will do its
work.

=head2 C<snoop_request()>

The C<snoop_request()> filter handler snoops only on HTTP request and
response bodies. Otherwise it's similar to C<snoop_connection()>. Only
normally it's configured for a specific C<E<lt>LocationE<gt>>. For
example:

  <Location /foo>
      PerlInputFilterHandler  Apache::DebugFilter::snoop_request
      PerlOutputFilterHandler Apache::DebugFilter::snoop_request
  </Location>




=head1 Functions

=head2 C<bb_dump()>

  my $ra_data = Apache::DebugFilter::bb_dump($bb);

If only a bucket brigade C<$bb> is passed, C<bb_dump> will convert bb
to an array of bucket_type => data pairs, and return a reference to
it. This later can be used as in the following example:

  while (my($btype, $data) = splice @$ra_data, 0, 2) {
      print "$btype => $data\n";
  }

If the second argument (expected to be an open filehandle) is passed,
as in:

  Apache::DebugFilter::bb_dump($bb, \*STDERR);

C<bb_dump> will print pretty formatted bb's content to that
filehandle.



=head1 Author

Stas Bekman E<lt>stas@stason.orgE<gt>

=head1 See Also

http://perl.apache.org/docs/2.0/user/handlers/filters.html#All_in_One_Filter

http://perl.apache.org/docs/2.0/

L<perl>.

=cut
