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
define('DEBUG_ENCRYPTION_KEY', 'debug-key');

define('WHITESPACE', 'on');
define('QUIZLET_API_KEY', 'quizlet-key');

class DebugController extends Zend_Controller_Action
{

    public $client = null;

    public $config = null;

    private $_is_logged_in = 0;
    private $_quizlet_access_token = '';

    private $_username = null;
    private $_password = null;
    private $_api_access_id = null;

    public $USE_NATIVE_QUIZLET_API = 1;
    

    public function indexAction()
    {
        ?><form action="#" method="post">
        <textarea name="debug" rows=15 cols=50></textarea>
        <input name="submit" type="submit" value="GO" />
        </form>
        <?php
        $debug = $this->getRequest()->getParam('debug', '');
        if (strlen($debug) > 0) {
            $debug = $this->decrypt($debug, DEBUG_ENCRYPTION_KEY);
            echo nl2br($debug);
        }
        die;
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


}

?>