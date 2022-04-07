<?php

require_once 'Zend/Http/Client.php';
require_once 'Zend/Json.php';
require_once 'Zend/Dom/Query.php';
require_once 'Zend/Db.php';

require_once 'FlashcardsServer_Exception.php';

/*
 * Some notes:
 * Set 'USE_NATIVE_QUIZLET_API' as to whether or not the native api is available.
 * The app will receive an extra key, 'api_method', which tells the app whether it is using
 * the native api or not.
 *
 * List of actions: login(/#),user(/name), cardset(/id),search,
 * searchGroups(/term), group(/id), joinGroup(/#)
 *
 * A note on languages. Quizlet allows users to set the language, and the default language is English.
 * Some of the functions here look for specific strings on the page, which will not work if the language
 * is other than English. HOWEVER, it appears (for now, as of 4/13/11) that Quizlet does not save the language
 * preference in the user's profile, but only in a cookie. This means that by loading up pages
 * here in this script, we will always get English as it is the default, even if the user has another language
 * set as their preference
 * 
 **/
 
define('FLASHCARDS_SERVER', 'api.iphoneflashcards.com');

define('NATIVE_QUIZLET_API', 'native_quizlet_api');
define('FLASHCARDS_API', 'flashcards_api');

define('API_KEY', 'api-key');
define('SECONDARY_KEY_ENCRYPTION_KEY', 'secondary-key');

define('WHITESPACE', 'on');
define('QUIZLET_API_KEY', 'quizlet-key');

define('ERROR_NO_USERNAME', 100);
define('ERROR_NO_PASSWORD', 101);
define('ERROR_NO_MESSAGE', 102);
define('ERROR_NO_SEARCH_TERM', 200);
define('ERROR_NO_CARDSET_ID', 300);
define('ERROR_LOGIN_NOT_VALID', 500);
define('ERROR_LOGIN_NOT_AVAILABLE', 501);
define('ERROR_USER_NOT_LOGGED_IN', 502);
define('ERROR_NO_GROUP_ID', 600);
define('ERROR_GROUP_ACCESS_OK', 601);
define('ERROR_GROUP_ACCESS_PENDING', 602);
define('ERROR_GROUP_ACCESS_INVITED', 603);
define('ERROR_GROUP_ACCESS_REMOVED', 604);
define('ERROR_GROUP_LIMIT_EXCEEDED', 605); // quizlet has a limit of 8 groups for normal users
define('ERROR_GROUP_REMOVED_OK', 650);
define('ERROR_GROUP_REMOVED_FAILED', 651);
define('ERROR_PRIVATE_CARDSET', 20);
define('ERROR_PRIVATE_CARDSET_PASSWORD', 701);
define('ERROR_PRIVATE_CARDSET_PASSWORD_NOT_VALID', 702);
define('ERROR_OBJECT_DELETED', 703);
define('ERROR_OBJECT_DOES_NOT_EXIST', 704);
define('ERROR_ACCESS_NOT_AUTHENTICATED', 800);
define('ERROR_HTTP_CLIENT', 1000);
define('ERROR_GENERAL', 1001);
define('ERROR_FUNCTION_NOT_SUPPORTED', -1000);

class QuizletController extends Zend_Controller_Action
{

    public $client = null;

    public $config = null;

    private $_is_logged_in = 0;
    private $_quizlet_access_token = '';

    private $_username = null;
    private $_password = null;
    private $_api_access_id = null;

    public $USE_NATIVE_QUIZLET_API = 1;
    

    public function authenticateRequest() {


        // authenticate the request as coming from the app:
        $secondaryKey = $this->decrypt($this->getRequest()->getParam('secondaryKey', ''), SECONDARY_KEY_ENCRYPTION_KEY);
        // we expect that the secondary key is ALWAYS 10 characters long:
        if (strlen($secondaryKey) != 10) {
            return 0;
        }
        // echo 'Secondary Key: '.$secondaryKey."\n";
        $primaryKey = $this->decrypt($this->getRequest()->getParam('primaryKey', ''), $secondaryKey);
        $primaryKey = strtolower($primaryKey); // make sure it's always lowercase.
        // echo 'Primary Key: '.$primaryKey."\n";
        $expectedPrimaryKey = strtolower(API_KEY.'/'.$this->getRequest()->getActionName());
        // echo 'Expected key: '.$expectedPrimaryKey."\n";
        return ($primaryKey == $expectedPrimaryKey) ? 1 : 0;
    }
    
    public function checkQuizletResponseForErrors($responseJson) {
        $responseCode = $responseJson['http_code'];
        if ($responseCode == 401) {
            die('asdfadsfa');
            die($e->toJson(ERROR_LOGIN_NOT_VALID));
        }            
    }

    public function init() 
    {
        /* Initialize action controller here */

        header('Content-Type: text/html; Charset: UTF-8');
        header('Content-Encoding: UTF-8');
        
        $internal = $this->getRequest()->getParam('internal', 0);

        // as per: http://stackoverflow.com/questions/1498692/how-do-you-make-zend-framework-not-render-a-view-layout-when-sending-an-ajax-resp/1498701#1498701
        $this->_helper->viewRenderer->setNoRender();

        $is_authenticated = $this->authenticateRequest();

        $this->client = new Zend_Http_Client();
        $this->client->setConfig(
            array(
            'Accept-encoding' => 'gzip,deflate',
            'useragent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.6.1; rv:2.0.1) Gecko/20100101 Firefox/4.0.1',
            )
        );
        $this->client->setHeaders(
            array(
            'X-Powered-By' => '',
            )
        );
        $this->client->setCookieJar();

        if ($internal) {
            $username = $this->getRequest()->getParam('username', '');
        } else {
            $username = $this->decrypt($this->getRequest()->getParam('username', ''), "api.iphoneflashcards.com/username");
        }
        
        $access_token = $this->getRequest()->getParam('access_token', '');
        if (strlen($access_token) > 0) {
            if (!$internal) {
                $access_token = $this->decrypt($access_token, "com.iphoneflashcards.api/access_token");
            }
            if (strlen($access_token) > 0) {
                $this->_quizlet_access_token = $access_token;
                $this->_username = $username;
                $this->_is_logged_in = 1;
            }
        }
        if (!$internal) {
            $db = Zend_Registry::get("db");
            $searchTerm = '';
            $testParams = array(
                'name',
                'id',
                'term',
                );
            foreach ($testParams as $param) {
                if (strlen($this->getRequest()->getParam($param, '')) > 0) {
                    $searchTerm = $this->getRequest()->getParam($param, '');
                    break;
                }
            }
            $secondaryKey = $this->decrypt($this->getRequest()->getParam('secondaryKey', ''), SECONDARY_KEY_ENCRYPTION_KEY);

            $data = array(
                'controller' => $this->getRequest()->getControllerName(),
                'action' => $this->getRequest()->getActionName(),
                'is_logged_in' => $this->isLoggedIn(),
                'username' => $username,
                'search_term' => $searchTerm,
                'ip_address' => $_SERVER['REMOTE_ADDR'],
                'app_version' => $this->getRequest()->getParam('appVersion', ''),
                'is_authenticated' => $is_authenticated,
                'encryption_key' => $secondaryKey,
                'ios_version' => $this->getRequest()->getParam('iosVersion', ''),
                );
            $db->insert('api_log', $data);
            $this->_api_access_id = $db->lastInsertId('api_log', 'api_access_id');
        
            if (!$is_authenticated) {
                $e = new FlashcardsServer_Exception('Access not authenticated');
                die($e->toJson(ERROR_ACCESS_NOT_AUTHENTICATED));
            }
        }
        if (!$internal && $this->isLoggedIn()) {
            $db->query('update api_log set is_logged_in = true, username = '.$db->quote($this->_username).' where api_access_id = '.$db->quote($this->_api_access_id));
        }
    }
    
    public function indexAction()
    {
        die('');
        // action body
    }

    public function userAction()
    {
        if (strlen($this->getRequest()->getParam('name')) < 2) {
            $e = new FlashcardsServer_Exception('No username supplied');
            die($e->toJson(ERROR_NO_USERNAME));
        }
        
        // if we're using the native quizlet API, then get the data from Quizlet:
        $url = 'https://api.quizlet.com/2.0/users/'.urlencode($this->getRequest()->getParam('name')).'?whitespace='.urlencode(WHITESPACE);
        if ($this->isLoggedIn() && strlen($this->_quizlet_access_token) > 0) {
            //$url .= '&access_token='.urlencode($this->_quizlet_access_token);
            $headerStr = 'Authorization: Bearer '.urlencode($this->_quizlet_access_token);
            $this->client->setHeaders('Authorization', 'Bearer '.urlencode($this->_quizlet_access_token));
        } else {
            $url .= '&client_id='.urlencode(QUIZLET_API_KEY);
        }
    //    echo $url; die;
        $this->client->setUri($url);
        $response = $this->client->request();
        $responseJson = $response->getBody();
        $responseJson = Zend_Json::decode($responseJson);
        // add the custom data to the Json stream, so the user knows that they are getting
        // the native api (not our own), and that they aren't logged in:
        $finalResponse = array();
        $finalResponse['response_type'] = 'ok';
        $finalResponse['sets_with_images'] = 0;
        $finalResponse['sets'] = array();
        if (isset($responseJson['sets'])) {
            foreach ($responseJson['sets'] as $set) {
                $s = array();
                $s['id'] = $set['id'];
                $s['url'] = $set['url'];
                $s['title'] = $set['title'];
                $s['creator'] = $set['created_by'];
                $s['created'] = $set['created_date'];
                $s['created_date'] = $set['created_date'];
                $s['last_modified'] = $set['modified_date'];
                $s['modified_date'] = $set['modified_date'];
                $s['has_images'] = $set['has_images'];
                $s['term_count'] = $set['term_count'];
                $s['subjects'] = $set['subjects'];
                $s['lang_front'] = @$set['lang_terms'];
                $s['lang_back'] = @$set['lang_definitions'];
                $s['is_private'] = (($set['visibility'] == 'public') ? 0 : 1);
                $finalResponse['sets'][] = $s;
                if ($s['has_images']) {
                    $finalResponse['sets_with_images']++;
                }
            }
        }
        $finalResponse['account_type'] = $responseJson['account_type'];
        $finalResponse['total_results'] = count($finalResponse['sets']);
        $finalResponse['page'] = 1;
        $finalResponse['total_pages'] = 1;
        $finalResponse['api_method'] = NATIVE_QUIZLET_API;
        $finalResponse['is_logged_in'] = $this->isLoggedIn();
        echo Zend_Json::encode($finalResponse);
    }
    
    public function usersetsAction() {
        if (strlen($this->getRequest()->getParam('name')) < 2) {
            $e = new FlashcardsServer_Exception('No username supplied');
            die($e->toJson(ERROR_NO_USERNAME));
        }
        
        // if we're using the native quizlet API, then get the data from Quizlet:
        $url = 'https://api.quizlet.com/2.0/users/'.urlencode($this->getRequest()->getParam('name')).'/sets?whitespace='.urlencode(WHITESPACE);
        if ($this->isLoggedIn() && strlen($this->_quizlet_access_token) > 0) {
            //$url .= '&access_token='.urlencode($this->_quizlet_access_token);
            $headerStr = 'Authorization: Bearer '.urlencode($this->_quizlet_access_token);
            $this->client->setHeaders('Authorization', 'Bearer '.urlencode($this->_quizlet_access_token));
        } else {
            $url .= '&client_id='.urlencode(QUIZLET_API_KEY);
        }

        $this->client->setUri($url);
        $response = $this->client->request();
        $responseJson = $response->getBody();
        $responseJson = Zend_Json::decode($responseJson);
        // add the custom data to the Json stream, so the user knows that they are getting
        // the native api (not our own), and that they aren't logged in:
        $finalResponse = array();
        $finalResponse['response_type'] = 'ok';
        $finalResponse['sets_with_images'] = 0;
        $finalResponse['sets'] = array();
        foreach ($responseJson as $set) {
            $s = array();
            $s['id'] = $set['id'];
            $s['url'] = $set['url'];
            $s['title'] = $set['title'];
            $s['creator'] = $set['created_by'];
            $s['created'] = $set['created_date'];
            $s['created_date'] = $set['created_date'];
            $s['last_modified'] = $set['modified_date'];
            $s['modified_date'] = $set['modified_date'];
            $s['has_images'] = $set['has_images'];
            $s['term_count'] = $set['term_count'];
            $s['subjects'] = $set['subjects'];
            $s['lang_front'] = @$set['lang_terms'];
            $s['lang_back'] = @$set['lang_definitions'];
            $s['is_private'] = (($set['visibility'] == 'public') ? 0 : 1);
            $s['cards'] = array();
            if (isset($set['terms'])) {
                foreach ($set['terms'] as $t) {
                    $card = array();
                    $card['id'] = $t['id'];
                    $card['front'] = $t['term'];
                    $card['back'] = $t['definition'];
                    if ($t['image']) {
                        $card['image_back'] = $t['image']['url'];
                    } else {
                        $card['image_back'] = NULL;
                    }
                    $s['cards'][] = $card;
                }
            }
            $finalResponse['sets'][] = $s;
            if ($s['has_images']) {
                $finalResponse['sets_with_images']++;
            }
        }
        $finalResponse['total_results'] = count($finalResponse['sets']);
        $finalResponse['page'] = 1;
        $finalResponse['total_pages'] = 1;
        $finalResponse['api_method'] = NATIVE_QUIZLET_API;
        $finalResponse['is_logged_in'] = $this->isLoggedIn();
        echo Zend_Json::encode($finalResponse);
    }
    
    public function usergroupsAction()
    {
        // action body

        if (strlen($this->getRequest()->getParam('name')) < 2) {
            $e = new FlashcardsServer_Exception('No username supplied');
            die($e->toJson(ERROR_NO_USERNAME));
        }
        
        // if we're using the native quizlet API, then get the data from Quizlet:
        $url = 'https://api.quizlet.com/2.0/users/'.urlencode($this->getRequest()->getParam('name')).'?whitespace='.urlencode(WHITESPACE);
        if ($this->isLoggedIn() && strlen($this->_quizlet_access_token) > 0) {
            $this->client->setHeaders('Authorization: Bearer '.urlencode($this->_quizlet_access_token));
        } else {
            $url .= '&client_id='.urlencode(QUIZLET_API_KEY);
        }
        $this->client->setUri($url);
        $response = $this->client->request();
        $responseJson = $response->getBody();
        $responseJson = Zend_Json::decode($responseJson);

        $sets = array();
        if (isset($responseJson['groups'])) {
            foreach ($responseJson['groups'] as $set) {
                $rowData = array(
                    'url' => '',
                    'id' => $set['id'],
                    'title' => $set['name'],
                    'set_count' => $set['set_count'],
                    'user_count' => $set['user_count'],
                    'is_private' => !$set['is_public'],
                    );
                $sets[] = $rowData;
            }
        }
           
           // output json:
           $responseJson = array(
               'response_type' => 'ok',
               'total_results' => count($sets),
               'page' => 1,
               'total_pages' => 1,
               'groups' => $sets
               );
               
           $responseJson['api_method'] = FLASHCARDS_API;
        $responseJson['is_logged_in'] = $this->isLoggedIn();

        echo Zend_Json::encode($responseJson);
    }


    public function searchAction()
    {
        // action body

        if (strlen($this->getRequest()->getParam('term')) < 2) {
            $e = new FlashcardsServer_Exception('No search term supplied');
            die($e->toJson(ERROR_NO_SEARCH_TERM));
        }
        $scope = $this->getRequest()->getParam('scope', 'most_studied');
        $ok_scopes = array('most_studied', 'most_recent', 'alphabetical', 'title');
        if (!in_array($scope, $ok_scopes)) {
            $scope = 'most_studied';
        }
        if ($scope == 'alphabetical') {
            $scope = 'title';
        }

        // action body
        $url = 'https://api.quizlet.com/2.0/search/sets?q='.urlencode($this->getRequest()->getParam('term')).'&sort='.urlencode($scope).'&per_page=50&page='.urlencode($this->getRequest()->getParam('page', 1)).'&whitespace='.urlencode(WHITESPACE);
        if ($this->isLoggedIn() && strlen($this->_quizlet_access_token) > 0) {
            $this->client->setHeaders('Authorization: Bearer '.urlencode($this->_quizlet_access_token));
        } else {
            $url .= '&client_id='.urlencode(QUIZLET_API_KEY);
        }
        $this->client->setUri($url);
        $response = $this->client->request();
        $responseJson = $response->getBody();
        $responseJson = Zend_Json::decode($responseJson);
        
        $finalResponse = array();
        $finalResponse['response_type'] = 'ok';
        $finalResponse['sets_with_images'] = 0;
        $finalResponse['sets'] = array();
        if (isset($responseJson['sets'])) {
            foreach ($responseJson['sets'] as $set) {
                $s = array();
                $s['id'] = $set['id'];
                $s['url'] = $set['url'];
                $s['title'] = $set['title'];
                $s['creator'] = $set['created_by'];
                $s['created'] = $set['created_date'];
                $s['created_date'] = $set['created_date'];
                $s['last_modified'] = $set['modified_date'];
                $s['modified_date'] = $set['modified_date'];
                $s['has_images'] = $set['has_images'];
                $s['term_count'] = $set['term_count'];
                $s['subjects'] = $set['subjects'];
                $finalResponse['sets'][] = $s;
                if ($s['has_images']) {
                    $finalResponse['sets_with_images']++;
                }
            }
        }
        $finalResponse['total_results'] = $responseJson['total_results'];
        $finalResponse['page'] = $responseJson['page'];
        $finalResponse['total_pages'] = $responseJson['total_pages'];
        $finalResponse['api_method'] = NATIVE_QUIZLET_API;
        $finalResponse['is_logged_in'] = $this->isLoggedIn();
        echo Zend_Json::encode($finalResponse);
    }
    
    public function uploadcardsetAction() {

        $url = 'https://api.quizlet.com/2.0/sets?';
        if ($this->isLoggedIn() && strlen($this->_quizlet_access_token) > 0) {
            $this->client->setHeaders('Authorization: Bearer '.urlencode($this->_quizlet_access_token));
        } else {
            $url .= '&client_id='.urlencode(QUIZLET_API_KEY);
        }
        
        $this->client->setUri($url);
        $this->client->setParameterPost('title', $this->getRequest()->getParam('setName', ''));
        $allows_discussion = (int)$this->getRequest()->getParam('isDiscussion', '1');
        if ($allows_discussion != 1) {
            $allows_discussion = 0;
        }
           $this->client->setParameterPost('allows_discussion', $allows_discussion);
           $is_private = (int)$this->getRequest()->getParam('isPrivate', '0');
           if ($is_private != 1) {
               $is_private = 0;
           }
           if ($is_private) {
               $visibility = 'only_me';
           } else {
               $visibility = 'public';
           }
           $this->client->setParameterPost('visibility', $visibility);
           $frontValues = $this->getRequest()->getParam('frontValue', array());
           $backValues  = $this->getRequest()->getParam('backValue', array());
           /*
           foreach ($frontValues as $k => $front) {
               $back = @$backValues[$k];
               $this->client->setParameterPost('terms[]', $front);
               $this->client->setParameterPost('definitions[]', $back);
           }
           */
       $this->client->setParameterPost('terms[]', $frontValues);
       $this->client->setParameterPost('definitions[]', $backValues);
               
           // language must be dealt with
           $lang_terms = $this->getRequest()->getParam('lang_terms', 'en');
           $lang_definitions  = $this->getRequest()->getParam('lang_definitions', 'en');
           $this->client->setParameterPost('lang_terms', $lang_terms);
           $this->client->setParameterPost('lang_definitions', $lang_definitions);
        
           $response = $this->client->request('POST');
        $responseJson = $response->getBody();
        $responseJson = Zend_Json::decode($responseJson);
    
        if (isset($responseJson['set_id'])) {
            // there is a set!!!!
            $finalResponse = array();
            $finalResponse['response_type'] = 'ok';
            $finalResponse['url'] = $responseJson['url'];
            $finalResponse['term_count'] = $responseJson['term_count'];
            $finalResponse['set_id'] = $responseJson['set_id'];
            $finalResponse['set_name'] = $this->getRequest()->getParam('setName', '');
            $finalResponse['is_private'] = $is_private;
            $finalResponse['allows_discussion'] = $allows_discussion;
            $finalResponse['api_method'] = NATIVE_QUIZLET_API;
            $finalResponse['is_logged_in'] = $this->isLoggedIn();
            
            $groupId = $this->getRequest()->getParam('groupId', -1);
            if ($groupId > 0) {
                $url = 'https://api.quizlet.com/2.0/groups/'.urlencode($groupId).'/sets/'.urlencode($finalResponse['set_id']).'?';
                if ($this->isLoggedIn() && strlen($this->_quizlet_access_token) > 0) {
                    $this->client->setHeaders('Authorization: Bearer '.urlencode($this->_quizlet_access_token));
                } else {
                    $url .= '&client_id='.urlencode(QUIZLET_API_KEY);
                }
                $this->client->setUri($url);
                $this->client->setMethod(Zend_Http_Client::PUT);
                   $response = $this->client->request('PUT');
            }
            
            echo Zend_Json::encode($finalResponse);
    
            if (!is_null($this->_api_access_id)) {
                $db = Zend_Registry::get("db");
                $db->query('update api_log set search_term = '.$db->quote($responseJson['set_id']).' where api_access_id = '.$db->quote($this->_api_access_id));
            }

        } else {
            // there is an error...
            $e = new FlashcardsServer_Exception($responseJson['error_description']);
            die($e->toJson(ERROR_GENERAL));
        }
    
        die;

    }
    
    public function parseSet($responseJson) {
        $currentSet = array();
        $currentSet['id'] = $responseJson['id'];
        $currentSet['title'] = $responseJson['title'];
        $currentSet['url'] = $responseJson['url'];
        $currentSet['creator'] = $responseJson['created_by'];
        $currentSet['created'] = $responseJson['created_date'];
        $currentSet['created_date'] = $responseJson['created_date'];
        $currentSet['modified_date'] = $responseJson['modified_date'];
        $currentSet['term_count'] = $responseJson['term_count'];
        $currentSet['has_images'] = $responseJson['has_images'];
        $currentSet['editable'] = $responseJson['editable'];
        $currentSet['lang_terms'] = $responseJson['lang_terms'];
        $currentSet['lang_definitions'] = $responseJson['lang_definitions'];
        $currentSet['lang_front'] = $responseJson['lang_terms'];
        $currentSet['lang_back'] = $responseJson['lang_definitions'];
        $currentSet['editable'] = $responseJson['editable'];
        $currentSet['terms'] = array();
        if (isset($responseJson['terms'])) {
            foreach ($responseJson['terms'] as $term) {
                $s = array();
                $s[] = $term['term'];
                $s[] = $term['definition'];
                if (!is_null($term['image'])) {
                    $s[] = '<img src="'.$term['image']['url'].'" width="'.$term['image']['width'].'" height="'.$term['image']['height'].'" />';
                } else {
                    $s[] = ""; // no front image
                }
                $s[] = ""; // back image
                $s[] = $term['id']; // the card's ID#
                $currentSet['terms'][] = $s;
            }
        }
        return $currentSet;
    }

    public function multiplecardsetsAction() {
        // action body
        $setPassword = $this->getRequest()->getParam('setPassword', '');

        $cardSetIdList = $this->getRequest()->getParam('cardSetIdList', array());

        if (isset($_GET['internal'])) {
            $cardSetIdList = explode(",", $_GET['cardsetidlist']);
        }
        $finalResponse = array();
        $finalResponse['response_type'] = 'ok';
        $finalResponse['sets_with_images'] = 0;
        $sets = array();

        $url = 'https://api.quizlet.com/2.0/sets?set_ids=';
        foreach ($cardSetIdList as $id) {
            $url .= urlencode($id.',');
        }
        if (isset($_REQUEST['lastModified'])) {
            $url .= '&modified_since='.urlencode($_REQUEST['lastModified']);
        }
        if (count($cardSetIdList) > 0) {
            $url .= '&extended=on&whitespace='.urlencode(WHITESPACE);
            if ($this->isLoggedIn() && strlen($this->_quizlet_access_token) > 0) {
                $this->client->setHeaders('Authorization: Bearer '.urlencode($this->_quizlet_access_token));
            } else {
                $url .= '&client_id='.urlencode(QUIZLET_API_KEY);
            }
            $this->client->setUri($url);
            $response = $this->client->request();
            $responseJson = $response->getBody();
            $responseJson = Zend_Json::decode($responseJson);
        
            if (isset($responseJson['http_code'])) {
                if ($responseJson['http_code'] == 403) {
                    // it is a private set, which can't be accessed at this time:
                    $e = new FlashcardsServer_Exception('This is a password-protected card set');
                    #die($e->toJson(ERROR_PRIVATE_CARDSET_PASSWORD));
                } else if ($responseJson['http_code'] == 401) {
                    // you have entered the wrong password
                    $e = new FlashcardsServer_Exception('You have entered the wrong password for this set');
                    #die($e->toJson(ERROR_PRIVATE_CARDSET_PASSWORD_NOT_VALID));
                } else if ($responseJson['http_code'] == 400) {
                    // you have entered the wrong password
                    $e = new FlashcardsServer_Exception($responseJson['error_description']);
                    #die($e->toJson(ERROR_USER_NOT_LOGGED_IN));
                }
                continue;
            }
            foreach ($responseJson as $set) {
                $currentSet = $this->parseSet($set);
                if ($currentSet['has_images']) {
                    $finalResponse['sets_with_images']++;
                }
                $currentSet['created_date'] = $currentSet['created'];
                $currentSet['cards'] = array();
                foreach ($currentSet['terms'] as $t) {
                    $card = array();
                    $card['id'] = $t[4];
                    $card['front'] = $t[0];
                    $card['back'] = $t[1];
                    if ($t[2]) {
                        $image = $t[2];
                        // extract URL: ex. <img src=\"http:\/\/i.quizlet.net\/i\/p0O5cfXcR1J1V5DAqj_wew_m.jpg\" width=\"132\" height=\"240\" \/>
                        $image = substr($image, strpos($image, '"'));
                        $image = substr($image, 0, strpos($image, '"'));
                        $card['image_back'] = $image;
                    } else {
                        $card['image_back'] = NULL;
                    }
                
                    $currentSet['cards'][] = $card;
                }
                $sets[] = $currentSet;
            }
        }
        
        $finalResponse['sets'] = $sets;
        $finalResponse['total_results'] = count($sets);
        $finalResponse['page'] = 1;
        $finalResponse['total_pages'] = 1;
        $finalResponse['api_method'] = NATIVE_QUIZLET_API;
        $finalResponse['is_logged_in'] = $this->isLoggedIn();
        
        echo Zend_Json::encode($finalResponse);
    }

    public function cardsetAction()
    {
        // action body
          if (strlen($this->getRequest()->getParam('id', '')) < 2 || !is_numeric($this->getRequest()->getParam('id', ''))) {
            $e = new FlashcardsServer_Exception('No cardset ID# supplied');
            die($e->toJson(ERROR_NO_CARDSET_ID));
        }
        
        $setPassword = $this->getRequest()->getParam('setPassword', '');

        $url = 'https://api.quizlet.com/2.0/sets/'.urlencode($this->getRequest()->getParam('id'));
        if (strlen($setPassword) > 0) {
            $url .= '/password';
        }
        $url .= '?extended=on&whitespace='.urlencode(WHITESPACE);
        if ($this->isLoggedIn() && strlen($this->_quizlet_access_token) > 0) {
            $this->client->setHeaders('Authorization: Bearer '.urlencode($this->_quizlet_access_token));
        } else {
            $url .= '&client_id='.urlencode(QUIZLET_API_KEY);
        }
        $this->client->setUri($url);


           if (strlen($setPassword) > 0) {
            $this->client->setParameterPost('password', $setPassword);
            $response = $this->client->request('POST');
        } else {
            $response = $this->client->request();
        }
        $responseJson = $response->getBody();
        $responseJson = Zend_Json::decode($responseJson);
        
        if (isset($responseJson['http_code'])) {
            if ($responseJson['http_code'] == 403) {
                // it is a private set, which can't be accessed at this time:
                $e = new FlashcardsServer_Exception('This is a password-protected card set');
                die($e->toJson(ERROR_PRIVATE_CARDSET_PASSWORD));
            } else if ($responseJson['http_code'] == 401) {
                // you have entered the wrong password
                $e = new FlashcardsServer_Exception('You have entered the wrong password for this set');
                die($e->toJson(ERROR_PRIVATE_CARDSET_PASSWORD_NOT_VALID));
            } else if ($responseJson['http_code'] == 400) {
                // you have entered the wrong password
                $e = new FlashcardsServer_Exception($responseJson['error_description']);
                die($e->toJson(ERROR_USER_NOT_LOGGED_IN));
            }
        }
        
        $finalResponse = array();
        $finalResponse['response_type'] = 'ok';
        $sets = array();
        $currentSet = $this->parseSet($responseJson);
        $sets[] = $currentSet;
        $finalResponse['sets_with_images'] = ($currentSet['has_images'] ? 1 : 0);
        $finalResponse['sets'] = $sets;
        $finalResponse['total_results'] = count($sets);
        $finalResponse['page'] = 1;
        $finalResponse['total_pages'] = 1;
        $finalResponse['api_method'] = NATIVE_QUIZLET_API;
        $finalResponse['is_logged_in'] = $this->isLoggedIn();
        
        echo Zend_Json::encode($finalResponse);
        
    }

    /**
     * A note on group privacy:
     * Some groups are marked as "private." This means that you need to be a member 
     * of the group in order to view the list of card sets inside of it.
     * However, once you are a member, you can view all sets - none are private.
     * There is NEVER a "public" group, but which includes "private" sets. Either one
     * way
     * or the other.
     * Also, about passwords. With card sets, a password allows you to access the set
     * when entering a password, whether or not you are logged in. With a group, entering
     * the password
     * makes you join the group - not just access it. This is a very different
     * workflow.
     *
    */
     
    public function getGroup() {
         $url = 'https://api.quizlet.com/2.0/groups/'.urlencode($this->getRequest()->getParam('id', '')).'?whitespace='.urlencode(WHITESPACE);
        if ($this->isLoggedIn() && strlen($this->_quizlet_access_token) > 0) {
            $this->client->setHeaders('Authorization: Bearer '.urlencode($this->_quizlet_access_token));
        } else {
            $url .= '&client_id='.urlencode(QUIZLET_API_KEY);
        }
        $this->client->setUri($url);
        $this->client->setMethod(Zend_Http_Client::GET);
        $response = $this->client->request();
        $responseJson = $response->getBody();
        $responseJson = Zend_Json::decode($responseJson);
        return $responseJson;
    }
     
    public function groupAction()
    {
        // action body
          if (strlen($this->getRequest()->getParam('id', '')) < 2 || !is_numeric($this->getRequest()->getParam('id', ''))) {
            $e = new FlashcardsServer_Exception('No group ID# supplied');
            die($e->toJson(ERROR_NO_GROUP_ID));
        }
        
         $url = 'https://api.quizlet.com/2.0/groups/'.urlencode($this->getRequest()->getParam('id', '')).'?whitespace='.urlencode(WHITESPACE);
        if ($this->isLoggedIn() && strlen($this->_quizlet_access_token) > 0) {
            $this->client->setHeaders('Authorization: Bearer '.urlencode($this->_quizlet_access_token));
        } else {
            $url .= '&client_id='.urlencode(QUIZLET_API_KEY);
        }
        $this->client->setUri($url);
        $response = $this->client->request();
        $responseJson = $response->getBody();
        $responseJson = Zend_Json::decode($responseJson);
        
        // add the custom data to the Json stream, so the user knows that they are getting
        // the native api (not our own), and that they aren't logged in:
        $finalResponse = array();
        $finalResponse['response_type'] = 'ok';
        $finalResponse['sets_with_images'] = 0;
        $finalResponse['is_private'] = !$responseJson['is_public'];
        $sets = array();
        if (isset($responseJson['sets']) && count($responseJson['sets']) > 0) {
            foreach ($responseJson['sets'] as $set) {
                $s = array();
                $s['id'] = $set['id'];
                $s['url'] = $set['url'];
                $s['title'] = $set['title'];
                $s['creator'] = $set['created_by'];
                $s['created'] = $set['created_date'];
                $s['created_date'] = $set['created_date'];
                $s['last_modified'] = $set['modified_date'];
                $s['modified_date'] = $set['modified_date'];
                $s['has_images'] = $set['has_images'];
                $s['term_count'] = $set['term_count'];
                $s['subjects'] = $set['subjects'];
                $sets[] = $s;
                if ($s['has_images']) {
                    $finalResponse['sets_with_images']++;
                }
            }
        }
        $finalResponse['sets'] = $sets;
        $finalResponse['total_results'] = count($sets);
        $finalResponse['page'] = 1;
        $finalResponse['total_pages'] = 1;
        $finalResponse['title'] = $responseJson['name'];
        $finalResponse['description'] = $responseJson['description'];
        $finalResponse['is_member'] = 0;
        if ($this->isLoggedIn() && isset($responseJson['members']) && count($responseJson['members']) > 0) {
            foreach ($responseJson['members'] as $member) {
                if (strtolower($member['username']) == strtolower($this->_username)) {
                    $finalResponse['is_member'] = 1;
                    break;
                }
            }
        }
        $finalResponse['api_method'] = FLASHCARDS_API;
        $finalResponse['is_logged_in'] = $this->isLoggedIn();
        
        
        // if it is a private set and the user is not a member, then return an error:
        /*
        if ($finalResponse['is_private']) {
            // it the user isn't logged in, or the user isn't a member:
            if (!$finalResponse['is_logged_in'] || !$finalResponse['is_member']) {
                $e = new FlashcardsServer_Exception('This group is marked as "private."');
                die($e->toJson(ERROR_PRIVATE_CARDSET));
            }
        }
        */
        if (!$responseJson['has_access']) {
            $e = new FlashcardsServer_Exception('This group is marked as "private."');
            if ($responseJson['has_password']) {
                die($e->toJson(ERROR_PRIVATE_CARDSET_PASSWORD));
            } else {
                die($e->toJson(ERROR_PRIVATE_CARDSET));
            }
        }

        echo Zend_Json::encode($finalResponse);
        die;
    }

    public function leavegroupAction()
    {
        if (strlen($this->getRequest()->getParam('id', '')) < 2 || !is_numeric($this->getRequest()->getParam('id', ''))) {
            $e = new FlashcardsServer_Exception('No group ID# supplied');
            die($e->toJson(ERROR_NO_GROUP_ID));
        }
        
        if (!$this->isLoggedIn()) {
            $e = new FlashcardsServer_Exception('You must log in to Quizlet to join a group.');
            die($e->toJson(ERROR_USER_NOT_LOGGED_IN));
        }
        
        $url = 'https://api.quizlet.com/2.0/groups/'.urlencode($this->getRequest()->getParam('id', '')).'/members/'.urlencode($this->_username);
        $this->client->setHeaders('Authorization: Bearer '.urlencode($this->_quizlet_access_token));
        $this->client->setUri($url);
        $this->client->setMethod(Zend_Http_Client::DELETE);
        $response = $this->client->request();
        $responseJson = $response->getBody();
        $responseJson = Zend_Json::decode($responseJson);

        $responseCode = $response->getStatus();
        if (floor($responseCode / 100) != 2) {
            $e = new FlashCardsServer_Exception($responseJson['error_description']);
            die($e->toJson(ERROR_GROUP_REMOVED_FAILED));
        }
        
        $e = new FlashcardsServer_Exception('Removing group OK');
        $e->isError = false;
        die($e->toJson(ERROR_GROUP_REMOVED_OK));

    }


    public function joingroupAction()
    {
        
        if (strlen($this->getRequest()->getParam('id', '')) < 2 || !is_numeric($this->getRequest()->getParam('id', ''))) {
            $e = new FlashcardsServer_Exception('No group ID# supplied');
            die($e->toJson(ERROR_NO_GROUP_ID));
        }
        
        if (!$this->isLoggedIn()) {
            $e = new FlashcardsServer_Exception('You must log in to Quizlet to join a group.');
            die($e->toJson(ERROR_USER_NOT_LOGGED_IN));
        }
        
        $joinType = $this->getRequest()->getParam('joinType', 'open');

        $url = 'https://api.quizlet.com/2.0/groups/'.urlencode($this->getRequest()->getParam('id', '')).'/members/'.urlencode($this->_username);
        
           if ($joinType == 'password') {
               if (strlen($this->getRequest()->getParam('groupPassword')) == 0) {
                   $e = new FlashcardsServer_Exception('You must enter a password.');
                die($e->toJson(ERROR_NO_PASSWORD));
               }
               $url .= '?password='.urlencode($this->getRequest()->getParam('groupPassword', ''));
               // $this->client->setParameterPost('password', $this->getRequest()->getParam('groupPassword', ''));
           } elseif ($joinType == 'message') {
               if (strlen($this->getRequest()->getParam('groupMessage')) == 0) {
                   $e = new FlashcardsServer_Exception('You must enter a message.');
                die($e->toJson(ERROR_NO_MESSAGE));
               }
               $url .= '?application='.urlencode($this->getRequest()->getParam('groupMessage', ''));
            // $this->client->setParameterPost('application', $this->getRequest()->getParam('groupMessage', ''));
           }
        $this->client->setHeaders('Authorization: Bearer '.urlencode($this->_quizlet_access_token));
        $this->client->setUri($url);
        $this->client->setMethod(Zend_Http_Client::PUT);
        $response = $this->client->request();
        $responseJson = $response->getBody();
        $responseJson = Zend_Json::decode($responseJson);
        
        $responseCode = $response->getStatus();
        if (floor($responseCode / 100) != 2) {
            $e = new FlashCardsServer_Exception($responseJson['error_description']);
            if ($responseJson['error_description'] == 'You typed the incorrect password') {
                die($e->toJson(ERROR_PRIVATE_CARDSET_PASSWORD_NOT_VALID));
            } else if ($responseJson['error_title'] == 'Too many groups') {
                die($e->toJson(ERROR_GROUP_LIMIT_EXCEEDED));
            } else if ($responseJson['error_description'] == 'The administrator of this group has been notified of your application.') {
                die($e->toJson(ERROR_GROUP_ACCESS_PENDING));
            } else {
                die($e->toJson(ERROR_GENERAL));
            }

        }
        
        if ($responseJson['role'] == 'applicant') {
            $e = new FlashCardsServer_Exception('You have successfully applied for membership in this group.');
            die($e->toJson(ERROR_GROUP_ACCESS_PENDING));
        }

        $finalResponse = array();
        $finalResponse['response_type'] = 'ok';
        
        $groupsResponseJson = $this->getGroup();
        
        $finalResponse['sets_with_images'] = 0;
        $finalResponse['sets'] = array();
        if (isset($groupsResponseJson['sets'])) {
            foreach ($groupsResponseJson['sets'] as $set) {
                $s = array();
                $s['id'] = $set['id'];
                $s['url'] = $set['url'];
                $s['title'] = $set['title'];
                $s['creator'] = $set['created_by'];
                $s['created'] = $set['created_date'];
                $s['created_date'] = $set['created_date'];
                $s['last_modified'] = $set['modified_date'];
                $s['modified_date'] = $set['modified_date'];
                $s['has_images'] = $set['has_images'];
                $s['term_count'] = $set['term_count'];
                $s['subjects'] = $set['subjects'];
                $s['is_private'] = (($set['visibility'] == 'public') ? 0 : 1);
                $finalResponse['sets'][] = $s;
                if ($s['has_images']) {
                    $finalResponse['sets_with_images']++;
                }
            }
        }
        $finalResponse['total_results'] = count($finalResponse['sets']);
        $finalResponse['page'] = 1;
        $finalResponse['total_pages'] = 1;
        $finalResponse['api_method'] = NATIVE_QUIZLET_API;
        $finalResponse['is_logged_in'] = $this->isLoggedIn();

        echo Zend_Json::encode($finalResponse);
        die;
    }


    public function searchgroupsAction()
    {

        // action body

        if (strlen($this->getRequest()->getParam('term')) < 2) {
            $e = new FlashcardsServer_Exception('No search term supplied');
            die($e->toJson(ERROR_NO_SEARCH_TERM));
        }
        
        $url = 'https://api.quizlet.com/2.0/search/groups?q='.urlencode($this->getRequest()->getParam('term')).'&page='.urlencode($this->getRequest()->getParam('page', 1)).'&per_page=50';
           if ($this->isLoggedIn() && strlen($this->_quizlet_access_token) > 0) {
            $this->client->setHeaders('Authorization: Bearer '.urlencode($this->_quizlet_access_token));
        } else {
            $url .= '&client_id='.urlencode(QUIZLET_API_KEY);
        }
        $this->client->setUri($url);
        $response = $this->client->request();
        $responseJson = $response->getBody();
        $responseJson = Zend_Json::decode($responseJson);
        // add the custom data to the Json stream, so the user knows that they are getting
        // the native api (not our own), and that they aren't logged in:
        $finalResponse = array();
        $finalResponse['response_type'] = 'ok';
        $finalResponse['total_results'] = $responseJson['total_results'];
        $finalResponse['page'] = $responseJson['page'];
        $finalResponse['total_pages'] = $responseJson['total_pages'];
        $finalResponse['groups'] = array();

        foreach ($responseJson['groups'] as $g) {
            $groupData = array (
                'id' => $g['id'],
                'url' => 'http://quizlet.com/group/'.$g['id'],
                'title' => $g['name'],
                'set_count' => $g['set_count'],
                'user_count' => $g['user_count'],
                'is_private' => (!$g['is_public']),
                );
            if (isset($g['description'])) {
                $groupData['description'] = $g['description'];
            } else {
                $groupData['description'] = '';
            }
                        
            $finalResponse['groups'][] = $groupData;
           }

        $finalResponse['api_method'] = FLASHCARDS_API;
        $finalResponse['is_logged_in'] = $this->isLoggedIn();

        echo Zend_Json::encode($finalResponse);

    }

    public function decrypt($cipher, $key)
    {
        $cipher = base64_decode($cipher);
        $iv     = substr( $cipher, 0, 16 );
        $cipher = substr( $cipher, 16 );
    
        // use the full key (all 32 bytes) for aes256
        $key = substr( hash( "sha256", $key, true ), 0, 16 );
    
        $plainText = @mcrypt_decrypt( MCRYPT_RIJNDAEL_128, $key, $cipher, MCRYPT_MODE_CBC, $iv );
    
        $plainTextLength = strlen( $plainText );
    
        // strip pkcs7 padding
        $padding = ord( $plainText[ $plainTextLength - 1 ] );
        $plainText = substr( $plainText, 0, -$padding );
    
        return $plainText;
    }

    public function usernamePasswordHash($username, $password) {
        // see: http://php.net/manual/en/function.hash.php
        $usernameHash = hash('sha256', $username);
        $passwordHash = hash('sha256', $password);
        return md5($usernameHash.'/'.$passwordHash);
    }

    public function getHTML($DOMElement)
    {
        $tmp_doc = new DOMDocument();
        $tmp_doc->appendChild($tmp_doc->importNode($DOMElement,true));
        return $tmp_doc->saveHTML();
    }

    public function firstDescendentNodeWithTag($parentNode, $tag)
    {
        if (!$parentNode->childNodes) {
            return;
        }
        for ($i = 0; $i < $parentNode->childNodes->length; $i++) {
            $item = $parentNode->childNodes->item($i);
            if (get_class($item) == 'DOMText') {
                return null;
            }
            if ($item->tagName == $tag) {
                return $item;
            } else {
                $retVal = $this->firstDescendentNodeWithTag($item, $tag);
                if (!is_null($retVal)) {
                    return $retVal;
                }
            }
        }
        return null;
    }

    public function isLoggedIn()
    {
        return $this->_is_logged_in;
    }
    
    public function checkForStrings($strings, $html, $message, $code) {
        $html = strtolower($html);
        foreach ($strings as $str) {
            if (strpos($html, strtolower($str)) !== FALSE) {
                $e = new FlashcardsServer_Exception($message);
                die($e->toJson($code));
            }
        }
    }

}

?>