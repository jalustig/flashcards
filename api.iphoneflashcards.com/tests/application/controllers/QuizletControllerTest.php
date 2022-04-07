<?php

require_once '../application/controllers/QuizletController.php';


define('USERNAME', 'testusername');
define('OTHERUSERNAME', 'otherusername');
define('CORRECT_PASSWORD', 'testpassword');
define('INCORRECT_PASSWORD', 'badtestpassword');
define('CORRECT_SET_PASSWORD', 'setpassword');
define('PUBLIC_CARDSET_ID', 5152358);
define('PRIVATE_CARDSET_ID', 5152378);
define('PASSWORD_CARDSET_ID', 5155442);

define('PUBLIC_GROUP_ID', 94712);
define('PRIVATE_GROUP_ID', 94714);
define('PASSWORD_GROUP_ID', 94643);
define('REMOVED_GROUP_ID', 94841);
define('INVITED_GROUP_ID', 94840);
define('PENDING_GROUP_ID', 94844);
define('DELETED_GROUP_ID', 94906);
define('CORRECT_GROUP_PASSWORD', 'grouppassword');

class QuizletControllerTest extends Zend_Test_PHPUnit_ControllerTestCase
{

    private $client = null;

    public function setUp()
    {
        $this->client = new Zend_Http_Client();
        $this->client->setConfig(array(
            'Accept-encoding' => 'gzip,deflate',
            'useragent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.6.1; rv:2.0.1) Gecko/20100101 Firefox/4.0.1'
        ));
        $this->client->setHeaders(array(
            'X-Powered-By' => '',
            ));

        $this->bootstrap = new Zend_Application(APPLICATION_ENV, APPLICATION_PATH . '/configs/application.ini');
        parent::setUp();
    }

    public function testLoginActionNoCredentials()
    {

        $this->client->setUri('http://127.0.0.1/quizlet/login/');
        $response = $this->client->request('POST');
        $body = $response->getBody();
        $json = Zend_Json::decode($body);
        
        // assertions: has proper keys
        $this->verifyError($json, ERROR_NO_USERNAME);
        
    }

    public function testUserActionNoUsername()
    {
        $this->client->setUri('http://127.0.0.1/quizlet/user/');
        $response = $this->client->request('POST');
        $body = $response->getBody();
        $json = Zend_Json::decode($body);
        
        // assertions: has proper keys
        $this->verifyError($json, ERROR_NO_USERNAME);
        
    }

    public function testLoginActionNoPassword()
    {
        
                
        $this->client->setUri('http://127.0.0.1/quizlet/login/');
        $this->client->setParameterPost('username', USERNAME);
        $this->client->setParameterPost('alreadyDecrypted', 1);
        $response = $this->client->request('POST');
        $body = $response->getBody();
        $json = Zend_Json::decode($body);
        
        $this->verifyError($json, ERROR_NO_PASSWORD);
    }

    public function testLoginActionInvalidCredentials()
    {
        
                
        $this->client->setUri('http://127.0.0.1/quizlet/login/');
        $this->client->setParameterPost('username', USERNAME);
        $this->client->setParameterPost('password', INCORRECT_PASSWORD);
        $this->client->setParameterPost('alreadyDecrypted', 1);
        $response = $this->client->request('POST');
        $body = $response->getBody();
        $json = Zend_Json::decode($body);
        
        $this->verifyError($json, ERROR_LOGIN_NOT_VALID);
    }

    public function testLoginActionValidCredentials()
    {
        
                
        $this->client->setUri('http://127.0.0.1/quizlet/login/');
        $this->client->setParameterPost('username', USERNAME);
        $this->client->setParameterPost('password', CORRECT_PASSWORD);
        $this->client->setParameterPost('alreadyDecrypted', 1);
        $response = $this->client->request('POST');
        $body = $response->getBody();
        $json = Zend_Json::decode($body);
        
        // assertions: has proper keys
        $this->assertArrayHasKey('response_type', $json, "assertJsonHasKey('response_type')");
        $this->assertEquals($json['response_type'], 'ok', "assertEquals(response_type, ok)");
        $this->assertArrayHasKey('api_method', $json, "assertJsonHasKey('api_method')");
        $this->assertEquals($json['api_method'], FLASHCARDS_API, "assertEquals(api_method, FLASHCARDS_API)");
        $this->assertArrayHasKey('is_logged_in', $json, "assertJsonHasKey('is_logged_in')");
        $this->assertEquals($json['is_logged_in'], 1, "assertEquals(is_logged_in, 1)");
        
    }

    public function testUserActionNotLoggedIn()
    {
        
        $this->client->setUri('http://127.0.0.1/quizlet/user/name/'.urlencode(USERNAME));
        $response = $this->client->request('POST');
        $body = $response->getBody();
        $json = Zend_Json::decode($body);
        
        $bodyTest = '{"response_type":"ok","total_results":2,"page":1,"total_pages":1,"sets_with_images":2,"sets":[{"url":"http:\/\/quizlet.com\/1234\/private-set-with-password-flash-cards\/","title":"Private set with password","creator":"username","term_count":"4","last_modified":"1302651502","is_private":true,"has_images":true,"id":"1234"},{"url":"http:\/\/quizlet.com\/1234\/test-set-1-flash-cards\/","title":"Test set 1","creator":"username","term_count":"4","last_modified":"1302640433","is_private":false,"has_images":true,"id":"1234"}],"api_method":"flashcards_api","is_logged_in":0}';
        $jsonTest = Zend_Json::decode($bodyTest);
        
        $this->verifyCardSetList($json, $jsonTest);
                
    }

    public function testUserActionYesLoggedIn()
    {
        $this->client->setUri('http://127.0.0.1/quizlet/user/name/'.urlencode(USERNAME));
        $this->client->setParameterPost('username', USERNAME);
        $this->client->setParameterPost('password', CORRECT_PASSWORD);
        $this->client->setParameterPost('alreadyDecrypted', 1);
        $response = $this->client->request('POST');
        $body = $response->getBody();
        $json = Zend_Json::decode($body);
        
        $bodyTest = '{"response_type":"ok","total_results":3,"page":1,"total_pages":1,"sets_with_images":1,"sets":[{"url":"http:\/\/quizlet.com\/1234\/private-set-with-password-flash-cards\/","title":"Private set with password","creator":"username","term_count":"4","last_modified":"1302651502","is_private":true,"has_images":false,"id":"1234"},{"url":"http:\/\/quizlet.com\/1234\/private-set-1-flash-cards\/","title":"Private set 1","creator":"username","term_count":"5","last_modified":"1302640489","is_private":true,"has_images":false,"id":"1234"},{"url":"http:\/\/quizlet.com\/1234\/test-set-1-flash-cards\/","title":"Test set 1","creator":"username","term_count":"4","last_modified":"1302640433","is_private":false,"has_images":true,"id":"1234"}],"api_method":"flashcards_api","is_logged_in":1}';
        $jsonTest = Zend_Json::decode($bodyTest);
        
        $this->verifyCardSetList($json, $jsonTest);
    }

    public function testUserActionDoesNotExist()
    {
        $this->client->setUri('http://127.0.0.1/quizlet/user/name/zasdflasfasdsadf');
        $response = $this->client->request('POST');
        $body = $response->getBody();
        $json = Zend_Json::decode($body);
        
        $this->verifyError($json, ERROR_OBJECT_DOES_NOT_EXIST);
    }

    public function testCardsetActionNoSetId()
    {
        
        $this->client->setUri('http://127.0.0.1/quizlet/cardset/');
        $response = $this->client->request('POST');
        $body = $response->getBody();
        $json = Zend_Json::decode($body);
        
        $this->verifyError($json, ERROR_NO_CARDSET_ID);

    }

    public function testCardsetActionPublicSetNotLoggedIn()
    {
        $this->client->setUri('http://127.0.0.1/quizlet/cardset/id/'.urlencode(PUBLIC_CARDSET_ID));
        $response = $this->client->request('POST');
        $body = $response->getBody();
        $json = Zend_Json::decode($body);

        $bodyTest = '{"response_type":"ok","total_results":1,"page":1,"total_pages":1,"sets_with_images":1,"sets":[{"id":"1234","title":"Test set 1 flashcards","url":"http:\/\/quizlet.com\/1234","creator":"username","created":1302639138,"term_count":4,"has_images":1,"terms":[["\u05e9\u05dc\u05d5\u05dd","peace",""],["film","\u0444\u0438\u043b\u044c\u043c",""],["gro\u00df","big, great",""],["test image front","test image back","<img src=\"http:\/\/farm3.static.flickr.com\/2101\/2263988203_96ca17ca43_m.jpg\" width=\"100\" height=\"100\" \/>"]]}],"api_method":"flashcards_api","is_logged_in":0}';
        $jsonTest = Zend_Json::decode($bodyTest);

        $this->verifyCardset($json, $jsonTest);
    }

    public function testCardsetActionPrivateSetNotLoggedIn()
    {
        $this->client->setUri('http://127.0.0.1/quizlet/cardset/id/'.urlencode(PRIVATE_CARDSET_ID));
        $response = $this->client->request('POST');
        $body = $response->getBody();
        $json = Zend_Json::decode($body);

        $this->verifyError($json, ERROR_PRIVATE_CARDSET);
    }

    public function testCardsetActionPrivateSetLoggedIn()
    {
        $this->client->setUri('http://127.0.0.1/quizlet/cardset/id/'.urlencode(PRIVATE_CARDSET_ID));
        $this->client->setParameterPost('username', USERNAME);
        $this->client->setParameterPost('password', CORRECT_PASSWORD);
        $this->client->setParameterPost('alreadyDecrypted', 1);
        $response = $this->client->request('POST');
        $body = $response->getBody();
        $json = Zend_Json::decode($body);

        $bodyTest = '{"response_type":"ok","total_results":1,"page":1,"total_pages":1,"sets_with_images":0,"sets":[{"id":"5152378","title":"Private set 1 flashcards","url":"http:\/\/quizlet.com\/5152378","creator":"username","created":1302639729,"term_count":5,"has_images":0,"terms":[["Term 1 front","Term 1 back",""],["Term 2 front","Term 2 back",""],["Term 3 front","Term 3 back",""],["Term 4 front","Term 4 back",""],["Term 5 front","Term 5 back",""]]}],"api_method":"flashcards_api","is_logged_in":1}';
        $jsonTest = Zend_Json::decode($bodyTest);

        $this->verifyCardset($json, $jsonTest);

    }

    public function testCardsetActionPasswordSetCreatorNotLoggedIn()
    {
        $this->client->setUri('http://127.0.0.1/quizlet/cardset/id/'.urlencode(PASSWORD_CARDSET_ID));
        $response = $this->client->request('POST');
        $body = $response->getBody();
        $json = Zend_Json::decode($body);

        $this->verifyError($json, ERROR_PRIVATE_CARDSET_PASSWORD);
    }

    public function testCardsetActionPasswordSetCreatorLoggedIn()
    {
        $this->client->setUri('http://127.0.0.1/quizlet/cardset/id/'.urlencode(PASSWORD_CARDSET_ID));
        $this->client->setParameterPost('username', USERNAME);
        $this->client->setParameterPost('password', CORRECT_PASSWORD);
        $this->client->setParameterPost('alreadyDecrypted', 1);
        $response = $this->client->request('POST');
        $body = $response->getBody();
        $json = Zend_Json::decode($body);

        $bodyTest = '{"response_type":"ok","total_results":1,"page":1,"total_pages":1,"sets_with_images":0,"sets":[{"id":"5155442","title":"Private set with password flashcards","url":"http:\/\/quizlet.com\/5155442","creator":"username","created":1302651491,"term_count":4,"has_images":0,"terms":[["Front card 1","Back card 2",""],["\u0435\u0434\u0430","food",""],["tomorrow","\u0437\u0430\u0432\u0442\u0440\u0430",""],["yesterday","today",""]]}],"api_method":"flashcards_api","is_logged_in":1}';
        $jsonTest = Zend_Json::decode($bodyTest);

        $this->verifyCardset($json, $jsonTest);
    }

    public function testCardsetActionPasswordSetValidPassword()
    {
        $this->client->setUri('http://127.0.0.1/quizlet/cardset/id/'.urlencode(PASSWORD_CARDSET_ID));
        $this->client->setParameterPost('setPassword', CORRECT_SET_PASSWORD);
        $response = $this->client->request('POST');
        $body = $response->getBody();
        $json = Zend_Json::decode($body);

        $bodyTest = '{"response_type":"ok","total_results":1,"page":1,"total_pages":1,"sets_with_images":0,"sets":[{"id":"5155442","title":"Private set with password flashcards","url":"http:\/\/quizlet.com\/5155442","creator":"username","created":1302651491,"term_count":4,"has_images":0,"terms":[["Front card 1","Back card 2",""],["\u0435\u0434\u0430","food",""],["tomorrow","\u0437\u0430\u0432\u0442\u0440\u0430",""],["yesterday","today",""]]}],"api_method":"flashcards_api","is_logged_in":0}';
        $jsonTest = Zend_Json::decode($bodyTest);

        $this->verifyCardset($json, $jsonTest);
    }

    public function testCardsetActionPasswordSetInvalidPassword()
    {
        $this->client->setUri('http://127.0.0.1/quizlet/cardset/id/'.urlencode(PASSWORD_CARDSET_ID));
        $this->client->setParameterPost('setPassword', INCORRECT_PASSWORD); // this is the wrong password for the set
        $response = $this->client->request('POST');
        $body = $response->getBody();
        $json = Zend_Json::decode($body);
        
        $this->verifyError($json, ERROR_PRIVATE_CARDSET_PASSWORD_NOT_VALID);

    }

    public function testGroupActionNoGroupId()
    {
        $this->client->setUri('http://127.0.0.1/quizlet/group/');
        $response = $this->client->request('POST');
        $body = $response->getBody();
        $json = Zend_Json::decode($body);

        $this->verifyError($json, ERROR_NO_GROUP_ID);
    }

    public function testGroupActionDeletedGroup() {
        $this->client->setUri('http://127.0.0.1/quizlet/group/id/'.urlencode(DELETED_GROUP_ID));

        $response = $this->client->request('POST');
        $body = $response->getBody();
        $json = Zend_Json::decode($body);

        $this->verifyError($json, ERROR_OBJECT_DELETED);
    }

    public function testGroupActionPublicGroup()
    {
    }

    public function testGroupActionPrivateGroupNotLoggedIn()
    {
        $this->client->setUri('http://127.0.0.1/quizlet/group/id/'.urlencode(PRIVATE_GROUP_ID));
        $response = $this->client->request('POST');
        $body = $response->getBody();
        $json = Zend_Json::decode($body);

        $this->verifyError($json, ERROR_PRIVATE_CARDSET);
    }

    public function testGroupActionPrivateGroupYesLoggedInYesInvited() {
        $this->client->setUri('http://127.0.0.1/quizlet/group/id/'.urlencode(INVITED_GROUP_ID));
        $this->client->setParameterPost('username', OTHERUSERNAME);
        $this->client->setParameterPost('password', CORRECT_PASSWORD);
        $this->client->setParameterPost('alreadyDecrypted', 1);

        $response = $this->client->request('POST');
        $body = $response->getBody();
        $json = Zend_Json::decode($body);

        $this->verifyError($json, ERROR_GROUP_ACCESS_INVITED);
    }
    
    public function testGroupActionPrivateGroupYesLoggedInYesRemoved() {
        $this->client->setUri('http://127.0.0.1/quizlet/group/id/'.urlencode(REMOVED_GROUP_ID));
        $this->client->setParameterPost('username', OTHERUSERNAME);
        $this->client->setParameterPost('password', CORRECT_PASSWORD);
        $this->client->setParameterPost('alreadyDecrypted', 1);

        $response = $this->client->request('POST');
        $body = $response->getBody();
        $json = Zend_Json::decode($body);

        $this->verifyError($json, ERROR_GROUP_ACCESS_REMOVED);
    }

    public function testGroupActionPrivateGroupYesLoggedInYesPending() {
        $this->client->setUri('http://127.0.0.1/quizlet/group/id/'.urlencode(PENDING_GROUP_ID));
        $this->client->setParameterPost('username', OTHERUSERNAME);
        $this->client->setParameterPost('password', CORRECT_PASSWORD);
        $this->client->setParameterPost('alreadyDecrypted', 1);

        $response = $this->client->request('POST');
        $body = $response->getBody();
        $json = Zend_Json::decode($body);

        $this->verifyError($json, ERROR_GROUP_ACCESS_PENDING);
    }

    public function testGroupActionPrivateGroupYesLoggedIn()
    {
    }

    public function testGroupActionPasswordGroupYesLoggedInYesMember()
    {
    }

    public function testGroupActionPasswordGroupYesLoggedInNotMember()
    {
    }

    public function testGroupActionPasswordGroupNotLoggedIn()
    {
        // since the user is not logged in, all they see is that it is private - not that it requires
        // a password.
        $this->client->setUri('http://127.0.0.1/quizlet/group/id/'.urlencode(PASSWORD_GROUP_ID));
        $response = $this->client->request('POST');
        $body = $response->getBody();
        $json = Zend_Json::decode($body);

        $this->verifyError($json, ERROR_PRIVATE_CARDSET);
    }

    public function testJoinGroupActionNoGroupId()
    {
        $this->client->setUri('http://127.0.0.1/quizlet/joinGroup/');
        $response = $this->client->request('POST');
        $body = $response->getBody();
        $json = Zend_Json::decode($body);

        $this->verifyError($json, ERROR_NO_GROUP_ID);
    }

    public function testJoinGroupActionPasswordGroupNoPawword()
    {
        $this->client->setUri('http://127.0.0.1/quizlet/joinGroup/id/'.urlencode(PASSWORD_GROUP_ID));
        $this->client->setParameterPost('username', OTHERUSERNAME);
        $this->client->setParameterPost('password', CORRECT_PASSWORD);
        $this->client->setParameterPost('alreadyDecrypted', 1);

        $this->client->setParameterPost('joinType', 'password');
        $response = $this->client->request('POST');
        $body = $response->getBody();
        $json = Zend_Json::decode($body);

        $this->verifyError($json, ERROR_NO_PASSWORD);
    }

    public function testJoinGroupActionPrivateGroupNoMessage()
    {
        $this->client->setUri('http://127.0.0.1/quizlet/joinGroup/id/'.urlencode(PASSWORD_GROUP_ID));
        $this->client->setParameterPost('username', OTHERUSERNAME);
        $this->client->setParameterPost('password', CORRECT_PASSWORD);
        $this->client->setParameterPost('alreadyDecrypted', 1);
        
        $this->client->setParameterPost('joinType', 'message');

        $response = $this->client->request('POST');
        $body = $response->getBody();
        $json = Zend_Json::decode($body);

        $this->verifyError($json, ERROR_NO_MESSAGE);
    }

    public function testJoinGroupActionNotLoggedIn()
    {
        $this->client->setUri('http://127.0.0.1/quizlet/joinGroup/id/'.urlencode(PUBLIC_GROUP_ID));
        $response = $this->client->request('POST');
        $body = $response->getBody();
        $json = Zend_Json::decode($body);

        $this->verifyError($json, ERROR_USER_NOT_LOGGED_IN);
    }

    public function testJoinGroupActionPasswordGroupInvalidPassword()
    {
        $this->client->setUri('http://127.0.0.1/quizlet/joinGroup/id/'.urlencode(PASSWORD_GROUP_ID));
        $this->client->setParameterPost('username', OTHERUSERNAME);
        $this->client->setParameterPost('password', CORRECT_PASSWORD);
        $this->client->setParameterPost('alreadyDecrypted', 1);
        
        $this->client->setParameterPost('joinType', 'password');
        $this->client->setParameterPost('groupPassword', INCORRECT_PASSWORD);

        $response = $this->client->request('POST');
        $body = $response->getBody();
        $json = Zend_Json::decode($body);

        $this->verifyError($json, ERROR_PRIVATE_CARDSET_PASSWORD);
    }

    public function testJoinGroupActionPasswordGroupValidPassword()
    {
        $this->client->setUri('http://127.0.0.1/quizlet/joinGroup/id/'.urlencode(PASSWORD_GROUP_ID));
        $this->client->setParameterPost('username', OTHERUSERNAME);
        $this->client->setParameterPost('password', CORRECT_PASSWORD);
        $this->client->setParameterPost('alreadyDecrypted', 1);
        
        $this->client->setParameterPost('joinType', 'password');
        $this->client->setParameterPost('groupPassword', CORRECT_GROUP_PASSWORD);

        $response = $this->client->request('POST');
        $body = $response->getBody();
        $json = Zend_Json::decode($body);

        // TODO: HAVE MORE ROBUST ASSERTIONS HERE:
        $this->assertEquals($json['response_type'], 'ok');

        $this->client->setUri('http://127.0.0.1/quizlet/leaveGroup/id/'.urlencode(PASSWORD_GROUP_ID));
        $this->client->setParameterPost('username', OTHERUSERNAME);
        $this->client->setParameterPost('password', CORRECT_PASSWORD);
        $this->client->setParameterPost('alreadyDecrypted', 1);
        
        $response = $this->client->request('POST');
        $body = $response->getBody();
        $json = Zend_json::decode($body);
        
        $this->verifyError($json, ERROR_GROUP_REMOVED_OK, 'ok');
        
    }

    public function testJoinGroupActionAlreadyInvited()
    {
/*
        $this->client->setUri('http://127.0.0.1/quizlet/joinGroup/id/'.urlencode(INVITED_GROUP_ID));
        $this->client->setParameterPost('username', OTHERUSERNAME);
        $this->client->setParameterPost('password', CORRECT_PASSWORD);
        $this->client->setParameterPost('alreadyDecrypted', 1);
        
           $this->client->setParameterPost('joinType', 'password');
        $this->client->setParameterPost('groupPassword', CORRECT_GROUP_PASSWORD);

        $response = $this->client->request('POST');
        $body = $response->getBody();
        $json = Zend_Json::decode($body);

        $this->verifyError($json, ERROR_GROUP_ACCESS_INVITED);
        */
    }

    public function testUserGroupsActionNoUserName()
    {
    
        $this->client->setUri('http://127.0.0.1/quizlet/userGroups/');
        $response = $this->client->request('POST');
        $body = $response->getBody();
        $json = Zend_Json::decode($body);

        $this->verifyError($json, ERROR_NO_USERNAME);
    }

    public function testUserGroupsActionDoesNotExist()
    {
        $this->client->setUri('http://127.0.0.1/quizlet/userGroups/name/zasdflasfasdsadf');
        $response = $this->client->request('POST');
        $body = $response->getBody();
        $json = Zend_Json::decode($body);
        
        $this->verifyError($json, ERROR_OBJECT_DOES_NOT_EXIST);
    }

    public function testUserGroupsActionNotLoggedIn()
    {
    }

    public function testUserGroupsActionLoggedIn()
    {
    }

    public function testSearchGroupsActionNoSearchTerm()
    {
        $this->client->setUri('http://127.0.0.1/quizlet/search/');
        $response = $this->client->request('POST');
        $body = $response->getBody();
        $json = Zend_Json::decode($body);

        $this->verifyError($json, ERROR_NO_SEARCH_TERM);
    }

    public function testSearchGroupsActionWackySearchTermWithNoResults()
    {
    }

    public function testSearchGroupsActionWackySearchTermWithYesResults()
    {
    }

    public function assertArrayHasKeyMsg($key, $array, $type)
    {
        $this->assertArrayHasKey($key, $array, 'assert'.$type.'HasKey('.$key.')');
    }

    public function verifyError($json, $error_number, $response_type = 'error')
    {
        $this->assertArrayHasKey('response_type', $json, "assertJsonHasKey('response_type')");
        $this->assertEquals($json['response_type'], 'error', "assertEquals(response_type, error)");
        $this->assertArrayHasKey('error_number', $json, "assertJsonHasKey('error_number')");
        $this->assertEquals($json['error_number'], $error_number, "assertEquals(error_number)");
        $this->assertArrayHasKey('short_text', $json, "assertJsonHasKey('short_text')");
        $this->assertArrayHasKey('long_text', $json, "assertJsonHasKey('long_text')");
    }

    public function verifyCardset($json, $jsonTest)
    {
                // assertions: has proper keys
        $this->assertArrayHasKeyMsg('response_type', $json, 'Json');
        $this->assertArrayHasKeyMsg('total_results', $json, 'Json');
        $this->assertArrayHasKeyMsg('page', $json, 'Json');
        $this->assertArrayHasKeyMsg('total_pages', $json, 'Json');
        $this->assertArrayHasKeyMsg('sets_with_images', $json, 'Json');
        $this->assertArrayHasKeyMsg('api_method', $json, 'Json');
        $this->assertArrayHasKeyMsg('is_logged_in', $json, 'Json');
        $this->assertArrayHasKeyMsg('sets', $json, 'Json');

        $this->assertEquals($json['response_type'], 'ok', "assertEquals(response_type, ok)");
        $this->assertEquals($json['total_results'], $jsonTest['total_results'], "assertEquals(total_results, 1)");
        $this->assertEquals($json['page'], $jsonTest['page'], "assertEquals(page, 1)");
        $this->assertEquals($json['total_pages'], $jsonTest['total_pages'], "assertEquals(total_pages, 1)");
        $this->assertEquals($json['sets_with_images'], $jsonTest['sets_with_images'], "assertEquals(sets_with_images, 1)");
        $this->assertEquals($json['api_method'], FLASHCARDS_API, "assertEquals(api_method, FLASHCARDS_API)");
        $this->assertEquals($json['is_logged_in'], $jsonTest['is_logged_in'], "assertEquals(is_logged_in, 0)");
        
        foreach ($json['sets'] as $setId => $set) {
            $this->assertArrayHasKeyMsg('url', $set, "Set");
            $this->assertArrayHasKeyMsg('title', $set, "Set");
            $this->assertArrayHasKeyMsg('creator', $set, "Set");
            $this->assertArrayHasKeyMsg('term_count', $set, "Set");
            $this->assertArrayHasKeyMsg('created', $set, "Set");
            $this->assertArrayHasKeyMsg('has_images', $set, "Set");
            $this->assertArrayHasKeyMsg('id', $set, "Set");
            $this->assertArrayHasKeyMsg('terms', $set, "Set");
            
            
            foreach ($set as $key => $value) {
                switch ($key) {
                    case 'created':
                        // make sure that it's an integer:
                        // it may not match up, because '4 hours ago' from now is not the same as '4 hours ago' from three minutes ago.
                        // as long as it's numeric, we know that it is correct.
                        $this->assertTrue(is_numeric($set['created']), "assertTrue(is_numeric(sets/last_modified))");
                        break;
                    case 'creator':
                        $this->assertEquals(strtolower($jsonTest['sets'][$setId][$key]), strtolower($set[$key]), "assertEquals(sets/$key)");
                        break;
                    case 'terms':
                        foreach ($set['terms'] as $termId => $term) {
                            $this->assertTrue((count($term) == 3), "assertTrue(term has three items)");
                            foreach ($term as $k => $item) {
                                $this->assertEquals($jsonTest['sets'][$setId][$key][$termId][$k], $item, "assertEquals(set/terms/item)");
                            }
                        }
                        break;
                    default:
                        
                        $this->assertEquals($jsonTest['sets'][$setId][$key], $set[$key], "assertEquals(sets/$key)"); 
                        break;
                }
            }
        }

    }

    public function verifyCardSetList($json, $jsonTest)
    {
        // assertions: has proper keys
        $this->assertArrayHasKeyMsg('response_type', $json, 'Json');
        $this->assertArrayHasKeyMsg('total_results', $json, 'Json');
        $this->assertArrayHasKeyMsg('page', $json, 'Json');
        $this->assertArrayHasKeyMsg('total_pages', $json, 'Json');
        $this->assertArrayHasKeyMsg('sets_with_images', $json, 'Json');
        $this->assertArrayHasKeyMsg('api_method', $json, 'Json');
        $this->assertArrayHasKeyMsg('is_logged_in', $json, 'Json');
        $this->assertArrayHasKeyMsg('sets', $json, 'Json');

        $this->assertEquals($json['response_type'], 'ok', "assertEquals(response_type, ok)");
        $this->assertEquals($json['total_results'], $jsonTest['total_results'], "assertEquals(total_results, 1)");
        $this->assertEquals($json['page'], $jsonTest['page'], "assertEquals(page, 1)");
        $this->assertEquals($json['total_pages'], $jsonTest['total_pages'], "assertEquals(total_pages, 1)");
        $this->assertEquals($json['sets_with_images'], $jsonTest['sets_with_images'], "assertEquals(sets_with_images, 1)");
        $this->assertEquals($json['api_method'], FLASHCARDS_API, "assertEquals(api_method, FLASHCARDS_API)");
        $this->assertEquals($json['is_logged_in'], $jsonTest['is_logged_in'], "assertEquals(is_logged_in, 0)");
        
        foreach ($json['sets'] as $setId => $set) {
            $this->assertArrayHasKeyMsg('url', $set, "Set");
            $this->assertArrayHasKeyMsg('title', $set, "Set");
            $this->assertArrayHasKeyMsg('creator', $set, "Set");
            $this->assertArrayHasKeyMsg('term_count', $set, "Set");
            $this->assertArrayHasKeyMsg('last_modified', $set, "Set");
            $this->assertArrayHasKeyMsg('is_private', $set, "Set");
            $this->assertArrayHasKeyMsg('has_images', $set, "Set");
            $this->assertArrayHasKeyMsg('id', $set, "Set");
            
            foreach ($set as $key => $value) {
                switch ($key) {
                    case 'last_modified':
                        // make sure that it's an integer:
                        $this->assertTrue(is_numeric($set['last_modified']), "assertTrue(is_numeric(sets/last_modified))");
                        break;
                    case 'creator':
                        $this->assertEquals(strtolower($jsonTest['sets'][$setId][$key]), strtolower($set[$key]), "assertEquals(sets/$key)");
                        break;
                    default:
                        
                        $this->assertEquals($jsonTest['sets'][$setId][$key], $set[$key], "assertEquals(sets/$key)"); 
                        break;
                }
            }
        }
        
    }
    
    public function verifyUserGroupsList($json, $jsonTest)
    {
        // assertions: has proper keys
        $this->assertArrayHasKeyMsg('response_type', $json, 'Json');
        $this->assertArrayHasKeyMsg('total_results', $json, 'Json');
        $this->assertArrayHasKeyMsg('page', $json, 'Json');
        $this->assertArrayHasKeyMsg('total_pages', $json, 'Json');
        $this->assertArrayHasKeyMsg('api_method', $json, 'Json');
        $this->assertArrayHasKeyMsg('is_logged_in', $json, 'Json');
        $this->assertArrayHasKeyMsg('groups', $json, 'Json');

        $this->assertEquals($json['response_type'], 'ok', "assertEquals(response_type, ok)");
        $this->assertEquals($json['total_results'], $jsonTest['total_results'], "assertEquals(total_results, 1)");
        $this->assertEquals($json['page'], $jsonTest['page'], "assertEquals(page, 1)");
        $this->assertEquals($json['total_pages'], $jsonTest['total_pages'], "assertEquals(total_pages, 1)");
        $this->assertEquals($json['api_method'], FLASHCARDS_API, "assertEquals(api_method, FLASHCARDS_API)");
        $this->assertEquals($json['is_logged_in'], $jsonTest['is_logged_in'], "assertEquals(is_logged_in, 0)");
        
        foreach ($json['groups'] as $setId => $set) {
            $this->assertArrayHasKeyMsg('url', $set, "Group");
            $this->assertArrayHasKeyMsg('title', $set, "Group");
            $this->assertArrayHasKeyMsg('set_count', $set, "Group");
            $this->assertArrayHasKeyMsg('user_count', $set, "Group");
            $this->assertArrayHasKeyMsg('id', $set, "Group");
            $this->assertArrayHasKeyMsg('is_private', $set, "Group");
            
            foreach ($set as $key => $value) {
                $this->assertEquals($jsonTest['groups'][$setId][$key], $set[$key], "assertEquals(groups/$key)"); 
            }
        }
        
    }

    public function getQuizletAPICall($uri)
    {
        $this->client->setUri($uri);
        $response = $this->client->request();
        $body = $response->getBody();
        $json = Zend_Json::decode($body);
        return $json;
    }

}

?>