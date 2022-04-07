<?php

require_once 'PHPExcel/PHPExcel.php';
require_once 'Zend/Json.php';
require_once 'Zend/Db.php';

require_once 'FlashcardsServer_Exception.php';

/*
Potential error codes:
 - File too large
 - No file (size = 0)
 - Unrecognized file type
 - Unable to read object
 - unable to write object
*/

define('ERROR_NO_FILE_UPLOADED',     100);
define('ERROR_FILE_TOO_LARGE',         200);
define('ERROR_FILE_TYPE',             300);
define('ERROR_CANNOT_READ_FILE',     400);
define('ERROR_CANNOT_WRITE_FILE',     500);

class ImagesController extends Zend_Controller_Action
{

    public function init()
    {
        /* Initialize action controller here */
    }

    public function indexAction()
    {
    }
    
    public function uploadAction() {
        header('content-type: text/html; charset: utf-8');
        
        // as per: http://stackoverflow.com/questions/1498692/how-do-you-make-zend-framework-not-render-a-view-layout-when-sending-an-ajax-resp/1498701#1498701
        $this->_helper->viewRenderer->setNoRender();

        if (!isset($_FILES['image'])) {
            $e = new FlashcardsServer_Exception('No file uploaded');
            die($e->toJson(ERROR_NO_FILE_UPLOADED));
        }

        $internal = $this->getRequest()->getParam('internal', 0);
        if (!$internal) {
            $db = Zend_Registry::get("db");
            $data = array(
                'controller' => $this->getRequest()->getControllerName(),
                'action' => $this->getRequest()->getActionName(),
                'search_term' => $_FILES['image']['name'],
                'ip_address' => $_SERVER['REMOTE_ADDR'],
                'app_version' => $this->getRequest()->getParam('appVersion', ''),
                'ios_version' => $this->getRequest()->getParam('iosVersion', ''),
                );
            $db->insert('api_log', $data);
        }

        $inputFileName = $_FILES['image']['tmp_name'];

        $uploaddir = '/home/iphonefl/api.iphoneflashcards.com/userimages/';
        $newfilename = uniqid('', true);
        $uploadfile = $uploaddir . $newfilename;
        if (move_uploaded_file($_FILES['image']['tmp_name'], $uploadfile)) {
            $fileUrl = 'http://api.iphoneflashcards.com/images/get/id/'.$newfilename;
            
            $response = array(
                'response_type' => 'ok',
                'url' => $fileUrl,
                );
            echo Zend_Json::encode($response);
            die;
        } else {
            $e = new FlashcardsServer_Exception('No file uploaded');
            die($e->toJson(ERROR_NO_FILE_UPLOADED));
        }

        
    }
    
    public function getAction() {
        $this->_helper->viewRenderer->setNoRender();

        $imagename = trim($this->getRequest()->getParam('id', ''));
        
        if (strlen($imagename) == 0) {
            die;
        }
        
        $internal = $this->getRequest()->getParam('internal', 0);
        if (!$internal) {
            $db = Zend_Registry::get("db");
            $data = array(
                'controller' => $this->getRequest()->getControllerName(),
                'action' => $this->getRequest()->getActionName(),
                'search_term' => $imagename,
                'ip_address' => $_SERVER['REMOTE_ADDR'],
                'app_version' => $this->getRequest()->getParam('appVersion', ''),
                'ios_version' => $this->getRequest()->getParam('iosVersion', ''),
                );
            $db->insert('api_log', $data);
        }
        
        $uploaddir = '/home/iphonefl/api.iphoneflashcards.com/userimages/';
        $filename = $uploaddir . $imagename;
        if (!is_file($filename)) {
            die;
        }
        echo file_get_contents($filename);
    }

    public function parseExcelAction()
    {
        // action body
        
        $inputFileName = 'input.xlsx';
        /** Load $inputFileName to a PHPExcel Object  **/
        $objPHPExcel = PHPExcel_IOFactory::load($inputFileName);
        
        var_dump($objPHPExcel);
        
    }


}



