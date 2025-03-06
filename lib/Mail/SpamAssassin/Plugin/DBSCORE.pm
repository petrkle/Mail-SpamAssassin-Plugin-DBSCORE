package Mail::SpamAssassin::Plugin::DBSCORE;
# ABSTRACT: Spamassassin scores from database

use strict;
use warnings;

use Mail::SpamAssassin::Plugin;
use DBI;

our @ISA = qw(Mail::SpamAssassin::Plugin);

sub new {
 my $class = shift;
 my $mailsaobject = shift;
 $class = ref($class) || $class;
 my $self = $class->SUPER::new($mailsaobject);
 bless ($self, $class);
 $self->register_eval_rule("DBSCORE");

  $mailsaobject->{conf}->{parser}->register_commands( [
      {
          setting => 'dbscore_dsn',
          type => $Mail::SpamAssassin::Conf::CONF_TYPE_STRING,
          default => 'DBI:MariaDB:database=dbscore;host=127.0.0.1;port=3306',
      }, {
          setting => 'dbscore_db_user',
          type => $Mail::SpamAssassin::Conf::CONF_TYPE_STRING,
          default => 'dbscore',
      }, {
          setting => 'dbscore_db_pass',
          type => $Mail::SpamAssassin::Conf::CONF_TYPE_STRING,
          default => 'dbscore',
      }
  ] );


 return $self;
}

sub DBSCORE{
  my ($self, $pms, $fulltext) = @_;

  my $dbh = DBI->connect($pms->{conf}->{dbscore_dsn}, $pms->{conf}->{dbscore_db_user}, $pms->{conf}->{dbscore_db_pass});

  my $fromhost = $pms->get('From:addr:host');
  my $from = $pms->get('From:addr:first');

  my $score = 0;
  my $domainscore = 0;

  my $sth = $dbh->prepare('SELECT score FROM senders WHERE sender = ?');
  $sth->execute($from);

  my $data = $sth->fetchrow_hashref;

  if($data->{score}){
    $score = $data->{score};
  }

  $sth = $dbh->prepare('SELECT score FROM domains WHERE domain = ?');
  $sth->execute($fromhost);

  $data = $sth->fetchrow_hashref;

  if($data->{score}){
    $domainscore = $data->{score};
  }

  $score = $score + $domainscore;

  if($score) {
     $pms->got_hit("DBSCORE", "HEADER: ", score => $score);
      for my $set (0..3) {
        $pms->{conf}->{scoreset}->[$set]->{"DBSCORE"} = sprintf("%0.3f", $score);
      }
  }

  $dbh->disconnect;

  return 0;
}
