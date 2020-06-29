# EPrints/Azure AI Integration experiment by Liam Green-Hughes, University of Kent
# This trigger will add keywords to an EPrint based on Abstract text
# It uses the Microsoft Azure Text analytics service https://azure.microsoft.com/en-us/services/cognitive-services/text-analytics/
$c->add_dataset_trigger( "eprint", EPrints::Const::EP_TRIGGER_BEFORE_COMMIT, sub {
  my( %params ) = @_;
  my $repo = $params{repository};
  my $eprint = $params{dataobj};
  my $changed = $params{changed};

  if (!$eprint->is_set("keywords")) {
        my $ua = LWP::UserAgent->new();
        $ua->proxy( 'http', $ENV{HTTP_proxy} ) if( EPrints::Utils::is_set( $ENV{HTTP_proxy} ) );
        # See https://docs.microsoft.com/en-us/azure/cognitive-services/text-analytics/how-tos/text-analytics-how-to-call-api
        # You might have to change the region here
        my $ms_azure = "https://uksouth.api.cognitive.microsoft.com/";
        # You will need to obtain a key, it is possible to get a 7 day Azure trail key without providing a credit card
        my $api_key = $repo->config( 'ms_azure_api_key' );
        my $azure_url = URI->new( sprintf("%s/text/analytics/v2.1/keyPhrases", $ms_azure)  ); 
        my $req = HTTP::Request->new( POST => $azure_url );
        $req->header("Ocp-Apim-Subscription-Key" => $api_key);
        $req->header("Content-Type" => "application/json");
        $req->header("Accept" =>  "application/json");
        my $abstract =  $eprint->value("abstract");
        # Remember to call the right language for your repository here
        my %doc = ("documents" => [{"language" => "en", "id" => $eprint->value("eprintid"), "text" =>  $abstract }]);
        $req->add_content_utf8(JSON::encode_json(\%doc));
        my $res = $ua->request($req);
        if( $res->is_success ) 
        { 			
             my %content = %{JSON::decode_json($res->content)};			
             my $keywords = join(", ", @{$content{"documents"}[0]{"keyPhrases"}});
             $eprint->set_value("keywords", $keywords); 
        }
        else
        {
             $repo->log(sprintf("Could not add keywords for Eprint %d", $eprint->value("eprintid")));
             $repo->log($res->status_line);
             $repo->log($res->content);
        }
 }
});
