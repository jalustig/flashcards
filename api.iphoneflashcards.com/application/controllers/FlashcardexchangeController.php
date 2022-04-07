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
 
class FlashcardexchangeController extends Zend_Controller_Action
{

    public function init() 
    {
        /* Initialize action controller here */

        header('Content-Type: text/html; Charset: UTF-8');
        header('Content-Encoding: UTF-8');
        
        // as per: http://stackoverflow.com/questions/1498692/how-do-you-make-zend-framework-not-render-a-view-layout-when-sending-an-ajax-resp/1498701#1498701
        $this->_helper->viewRenderer->setNoRender();
    }
    
    public function indexAction()
    {
            $db = Zend_Registry::get("db");

            $data = array(
                'controller' => 'FlashcardExchange',
                'action' => $this->getRequest()->getParam('method', ''),
                'is_logged_in' => $this->getRequest()->getParam('is_logged_in', 0),
                'username' => $this->getRequest()->getParam('username', ''),
                'search_term' => $this->getRequest()->getParam('search_term', ''),
                'ip_address' => $_SERVER['REMOTE_ADDR'],
                'app_version' => $this->getRequest()->getParam('appVersion', ''),
                'is_authenticated' => 1,
                'encryption_key' => '',
                'ios_version' => $this->getRequest()->getParam('iosVersion', ''),
                );
            $db->insert('api_log', $data);
    }
}
?>