use v5.40;
use strict;
use warnings;
use lib 'lib';

use Getopt::Long;
use HTTP::Request::Common qw(POST);
use LWP::UserAgent;
use File::Basename;

# Command-line options
my ($help, $api_token, $file, $language, $model);
$language ||= '';            # optional
$model    ||= 'whisper-1';   # default OpenAI model

my $usage = 'Usage: $0 --api-token TOKEN --file FILE [--language LANG] [--model MODEL]\n';
GetOptions(
	'help' => \$help,
	'api-token=s' => \$api_token,
	'file=s' => \$file,
	'language=s' => \$language,
	'model=s' => \$model,
) or die $usage;

if ($help) {
	say $usage if $help;
	exit 0;
}
die 'Missing --api-token\n' unless $api_token;
die 'Missing --file\n'      unless $file && -f $file;

my $ua = LWP::UserAgent->new;
# OpenAI Endpoint
my $endpoint = 'https://api.openai.com/v1/audio/transcriptions';
# Create the request (multipart/form-data)
my $req = POST($endpoint,
Authorization => 'Bearer $api_token',
Content_Type  => 'form-data',
Content       => [
	file     => [$file, basename($file), 'Content-Type' => 'application/octet-stream'],
	model    => $model,
	($language ? (language => $language) : ()),
]);

# Send the request
my $res = $ua->request($req);

# Print the result
if ($res->is_success) {
	say 'Transcription result:\n' . $res->decoded_content . '\n';
} else {
	die 'Failed: ' . $res->status_line . '\n' . $res->decoded_content . '\n';
}

1;
