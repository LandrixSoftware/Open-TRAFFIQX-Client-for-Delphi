<?php

namespace Landrix\OAuth2;

use GuzzleHttp\Client as HttpClient;
use League\OAuth2\Client\OptionProvider\HttpBasicAuthOptionProvider;
use League\OAuth2\Client\Provider\GenericProvider;

/**
 * Gemeinsamer Provider fuer Portale, die zwingend Basic Auth am Token-Endpoint
 * verlangen und das optionale approval_prompt nicht akzeptieren.
 */
class LandrixOAuthProvider extends GenericProvider
{
    /** @var bool */
    private $stripApprovalPrompt;

    public function __construct(array $options = [], array $collaborators = [], bool $stripApprovalPrompt = true)
    {
        $this->stripApprovalPrompt = $stripApprovalPrompt;

        if (!isset($collaborators['optionProvider'])) {
            $collaborators['optionProvider'] = new HttpBasicAuthOptionProvider();
        }

        // Keine Weiterleitungen folgen: Der Token-Endpunkt ist geprueft, ein
        // Redirect koennte den Serverrequest sonst auf ein internes Ziel lenken.
        if (!isset($collaborators['httpClient'])) {
            $collaborators['httpClient'] = new HttpClient([
                'allow_redirects' => false,
                'timeout' => 20,
                'connect_timeout' => 10,
            ]);
        }

        parent::__construct($options, $collaborators);
    }

    protected function getAuthorizationParameters(array $options)
    {
        $params = parent::getAuthorizationParameters($options);

        if ($this->stripApprovalPrompt) {
            unset($params['approval_prompt']);
        }

        return $params;
    }
}
