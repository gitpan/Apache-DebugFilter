package TestDebugFilter::snoop;

use strict;
use warnings FATAL => 'all';

use APR::Brigade ();
use APR::Bucket ();
use Apache::RequestRec ();
use Apache::RequestIO ();
use Apache::Connection ();

use Apache::Const -compile => qw(OK M_POST MODE_READBYTES);
use APR::Const -compile => qw(:common BLOCK_READ);

use constant IOBUFSIZE => 8192;

sub handler {
    my $r = shift;

    $r->content_type('text/plain');

    if ($r->method_number == Apache::M_POST) {
        my $data = read_post($r);
        $r->print($data);
    }

    Apache::OK;
}

# to enable debug start with: (or simply run with -trace=debug)
# t/TEST -trace=debug -start
sub read_post {
    my $r = shift;
    my $debug = shift || 0;

    my $bb = APR::Brigade->new($r->pool,
                               $r->connection->bucket_alloc);

    my $data = '';
    my $seen_eos = 0;
    my $count = 0;
    do {
        $r->input_filters->get_brigade($bb, Apache::MODE_READBYTES,
                                       APR::BLOCK_READ, IOBUFSIZE);

        $count++;

        warn "read_post: bb $count\n" if $debug;

        while (!$bb->is_empty) {
            my $b = $bb->first;

            if ($b->is_eos) {
                warn "read_post: EOS bucket:\n" if $debug;
                $seen_eos++;
                last;
            }

            if ($b->read(my $buf)) {
                warn "read_post: DATA bucket: [$buf]\n" if $debug;
                $data .= $buf;
            }

            $b->delete;
        }

    } while (!$seen_eos);

    $bb->destroy;

    return $data;
}

1;
__END__
<NoAutoConfig>
  <VirtualHost TestDebugFilter::snoop>
      PerlModule             TestDebugFilter::snoop
      PerlModule             Apache::DebugFilter

      # Connection snooping (everything)
      PerlInputFilterHandler  Apache::DebugFilter::snoop_connection
      PerlOutputFilterHandler Apache::DebugFilter::snoop_connection

      # HTTP Request snooping (only HTTP request body)
      <Location /TestDebugFilter__snoop>
          SetHandler modperl
          PerlResponseHandler     TestDebugFilter::snoop
          PerlInputFilterHandler  Apache::DebugFilter::snoop_request
          PerlOutputFilterHandler Apache::DebugFilter::snoop_request
      </Location>
  </VirtualHost>
</NoAutoConfig>

