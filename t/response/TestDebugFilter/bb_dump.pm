package TestDebugFilter::bb_dump;

use strict;
use warnings FATAL => 'all';

use Apache::Connection ();
use APR::Bucket ();
use APR::Brigade ();
use APR::Util ();
use APR::Error ();

use Apache::TestTrace;

use Apache::DebugFilter;

use APR::Const -compile => qw(SUCCESS EOF);
use Apache::Const -compile => qw(OK MODE_GETLINE);

sub handler {
    my Apache::Connection $c = shift;

    my $ba  = $c->bucket_alloc;
    my $ibb = APR::Brigade->new($c->pool, $ba);
    my $obb = APR::Brigade->new($c->pool, $ba);

    for (;;) {
        my $rv = $c->input_filters->get_brigade($ibb, Apache::MODE_GETLINE);
        if ($rv != APR::SUCCESS or $ibb->is_empty) {
            my $error = APR::Error::strerror($rv);
            unless ($rv == APR::EOF) {
                warn "[echo_filter] get_brigade: $error\n";
            }
            $ibb->destroy;
            last;
        }

        my $ra_data = Apache::DebugFilter::bb_dump($ibb);
        debug $ra_data;

        $ibb->destroy;

        while (my($btype, $data) = splice @$ra_data, 0, 2) {
            my $data = "$btype => $data";
            $obb->insert_tail(APR::Bucket->new($ba, $data));
        }
        $obb->insert_tail(APR::Bucket::flush_create($ba));

        $c->output_filters->pass_brigade($obb);
    }

    Apache::OK;
}

1;
__END__
<NoAutoConfig>
  <VirtualHost TestDebugFilter::bb_dump>
      PerlProcessConnectionHandler TestDebugFilter::bb_dump
  </VirtualHost>
</NoAutoConfig>

