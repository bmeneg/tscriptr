use v5.38;
use strict;
use warnings;

use feature qw(try);

use Getopt::Long qw( GetOptions );
use Mojolicious::Lite;

my %args = (
	api_token => '',
	model => '',
	language => '',
	file => '',
);

sub parse_args() {
	my ($help, $api_token, $file, $language, $model);
	$language = '';
	$model = 'whisper-1';   # default OpenAI model

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

	return {
		api_token => $api_token,
		model => $model,
		language => $language,
		file => $file,
	};
}

get '/' => sub ($c) {
	$c->render(template => 'index');
};

get '/transcribe' => sub ($c) {
	my $upload = $c->req->upload('audio_file');
	unless ($upload && $upload->size > 0) {
		return $c->render(
			text => '<div class="mt-6 bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded-lg relative" role="alert"><strong class="font-bold">Erro:</strong><span class="block sm:inline"> Nenhum arquivo foi enviado. Por favor, selecione um arquivo de áudio.</span></div>',
			status => 400
		); 
    }

	$c->render_late;
	my $ua = $c->app->ua;
	my $endpoint = 'https://api.openai.com/v1/audio/transcriptions';
	my $form_data = {
		model => $args{model},
		file => [$upload->asset, $upload->filename, 'Content-Type' => 'application/octet-stream'],
		($args{language} ? (language => $args{language}) : ()),
	};

	try {
		$ua->post($endpoint, {Authorization => "Bearer $args{api_key}"}, form => $form_data,
			sub {
				my ($ua, $tx) = @_;
				my $result_html;

				# Check if the transaction was successful
				if (my $res = $tx->result) {
					if ($res->is_success) {
						my $text = $res->json('/text');
						$text =~ s/&/&amp;/g; $text =~ s/</&lt;/g; $text =~ s/>/&gt;/g;

						$result_html = <<~"HTML";
						<div class="bg-green-50 border-l-4 border-green-500 text-green-800 p-4 rounded-r-lg" role="alert">
						<p class="font-bold text-lg mb-2">Transcrição Concluída:</p>
						<p class="whitespace-pre-wrap font-mono bg-white p-4 rounded-md shadow-inner text-gray-700">$text</p>
						</div>
						HTML
					}
					else {
						# Handle API-level errors (e.g., 401, 500)
						my $error_body = $res->body;
						$result_html = <<~"HTML";
						<div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded-lg" role="alert">
						<strong class="font-bold">Erro da API (${res->code}):</strong>
						<span class="block sm:inline">$error_body</span>
						</div>
						HTML
					}
				}
				else {
					# Handle connection-level errors (e.g., timeout)
					my $error = $tx->error;
					$result_html = <<~"HTML";
					<div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded-lg" role="alert">
					<strong class="font-bold">Erro de Conexão:</strong>
					<span class="block sm:inline">$error->{message}</span>
					</div>
					HTML
				}

				# Render the final HTML back to the client.
				$c->render(text => $result_html);
			});
	} catch ($e) {
		# Catch any synchronous errors (like the missing API key)
		$c->render(
			text   =>qq|<div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded-lg" role="alert"><strong class="font-bold">Erro Crítico:</strong> <span class="block sm:inline">$e</span></div>|,
			status => 500
		);
	}
};

%args = %{ parse_args() };
app->start;

__DATA__

@@ index.html.ep
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Transcrição de Áudio com IA</title>
    <!-- TailwindCSS via CDN -->
    <script src="https://cdn.tailwindcss.com"></script>
    <!-- htmx via CDN -->
    <script src="https://unpkg.com/htmx.org@1.9.10" xintegrity="sha384-D1Kt99CQMDuVetoL1lrYwg5t+9QdHe7NLX/SoJYkXDFfX37iInKRy5xLSi8nO7UC" crossorigin="anonymous"></script>
    <style>
        body { background-color: #f8fafc; }
        @keyframes spin { to { transform: rotate(360deg); } }
        .spinner {
            border: 4px solid rgba(0, 0, 0, 0.1);
            border-left-color: #2563eb;
            border-radius: 50%;
            width: 40px;
            height: 40px;
            animation: spin 1s linear infinite;
        }
        .htmx-indicator { display: none; opacity: 0; transition: opacity 200ms ease-in; }
        .htmx-request .htmx-indicator { display: inline-block; opacity: 1; }
        .htmx-request.htmx-indicator { opacity: 1; }
    </style>
</head>
<body class="bg-gray-50 flex items-center justify-center min-h-screen font-sans">
    <div class="w-full max-w-2xl mx-auto p-4 sm:p-6 lg:p-8">
        <div class="bg-white shadow-2xl rounded-2xl overflow-hidden">
            <div class="px-6 py-8 sm:p-10">
                <div class="text-center">
                    <svg class="mx-auto h-12 w-auto text-blue-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" d="M12 18.75a6 6 0 006-6v-1.5m-6 7.5a6 6 0 01-6-6v-1.5m6 7.5v3.75m-3.75 0h7.5M12 15.75a3 3 0 01-3-3V4.5a3 3 0 116 0v8.25a3 3 0 01-3 3z" /></svg>
                    <h1 class="mt-4 text-3xl font-extrabold text-gray-900 tracking-tight">Transcrição de Áudio</h1>
                    <p class="mt-2 text-lg text-gray-500">Faça o upload de um arquivo de áudio para transcrevê-lo para texto.</p>
                </div>
                <form hx-post="/transcribe" hx-encoding="multipart/form-data" hx-target="#transcription-result" hx-indicator="#loading-spinner" class="mt-8 space-y-6">
                    <div>
                        <label for="audio-file" class="block text-sm font-medium text-gray-700 sr-only">Escolha o arquivo</label>
                        <div class="mt-1 flex justify-center px-6 pt-5 pb-6 border-2 border-gray-300 border-dashed rounded-md">
                            <div class="space-y-1 text-center">
                                <svg class="mx-auto h-12 w-12 text-gray-400" stroke="currentColor" fill="none" viewBox="0 0 48 48" aria-hidden="true"><path d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" /></svg>
                                <div class="flex text-sm text-gray-600">
                                    <label for="audio-file" class="relative cursor-pointer bg-white rounded-md font-medium text-blue-600 hover:text-blue-500 focus-within:outline-none focus-within:ring-2 focus-within:ring-offset-2 focus-within:ring-blue-500">
                                        <span>Carregar um arquivo</span>
                                        <input id="audio-file" name="audio_file" type="file" class="sr-only" required>
                                    </label>
                                    <p class="pl-1">ou arraste e solte</p>
                                </div>
                                <p class="text-xs text-gray-500" id="file-name-display">Nenhum arquivo selecionado</p>
                            </div>
                        </div>
                    </div>
                    <div class="text-center">
                        <button type="submit" class="w-full sm:w-auto inline-flex justify-center items-center px-6 py-3 border border-transparent text-base font-medium rounded-md shadow-sm text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 transition-colors">
                            <span class="htmx-indicator-text">Transcrever Áudio</span>
                            <div id="loading-spinner" class="htmx-indicator ml-3"><div class="spinner !w-5 !h-5 !border-2"></div></div>
                        </button>
                    </div>
                </form>
                <div id="transcription-result" class="mt-8"></div>
            </div>
        </div>
        <footer class="text-center mt-8 text-gray-500 text-sm"><p>&copy; 2025 Transcritor de Áudio. Todos os direitos reservados.</p></footer>
    </div>
    <script>
        document.getElementById('audio-file').addEventListener('change', function(e) {
            var fileName = e.target.files[0] ? e.target.files[0].name : 'Nenhum arquivo selecionado';
            document.getElementById('file-name-display').textContent = fileName;
        });
    </script>
</body>
</html>

