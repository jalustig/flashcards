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

class ImportController extends Zend_Controller_Action
{

    public function init()
    {
        /* Initialize action controller here */
    }

    public function indexAction()
    {
        
        header('content-type: text/html; charset: utf-8');
        
        // as per: http://stackoverflow.com/questions/1498692/how-do-you-make-zend-framework-not-render-a-view-layout-when-sending-an-ajax-resp/1498701#1498701
        $this->_helper->viewRenderer->setNoRender();

        $internal = $this->getRequest()->getParam('internal', 0);
        if (!$internal) {
            $db = Zend_Registry::get("db");
            $data = array(
                'controller' => $this->getRequest()->getControllerName(),
                'action' => $this->getRequest()->getActionName(),
                'search_term' => $_FILES['spreadsheet']['name'],
                'ip_address' => $_SERVER['REMOTE_ADDR'],
                'app_version' => $this->getRequest()->getParam('appVersion', ''),
                'ios_version' => $this->getRequest()->getParam('iosVersion', ''),
                );
            $db->insert('api_log', $data);
        }

        if (!isset($_FILES['spreadsheet'])) {
            $e = new FlashcardsServer_Exception('No file uploaded');
            die($e->toJson(ERROR_NO_FILE_UPLOADED));
        }
        $inputFileName = $_FILES['spreadsheet']['tmp_name'];
        $outputFileName = tempnam('/tmp', 'csv');
        try {
            
            /** Load $inputFileName to a PHPExcel Object  **/
            $objPHPExcel = @PHPExcel_IOFactory::load($inputFileName);
        } catch (FlashcardsServer_Exception $e) {
            die($e->toJson(ERROR_CANNOT_READ_FILE));
        }

        $objPHPCSV = new PHPExcel_Writer_CSV($objPHPExcel);
        $objPHPCSV->setUseBOM(false);
        try {
            $objPHPCSV->save($outputFileName);
            $response = array(
                'response_type' => 'ok',
                'results' => array(
                    'file_data' => file_get_contents($outputFileName),
                    )
                );
            if ($internal) {
                echo file_get_contents($outputFileName);
                die;
            }
            echo Zend_Json::encode($response);
        } catch (Exception $e) {
            die($e->toJson(ERROR_CANNOT_WRITE_FILE));
        }
        
    }
    
    public function uploadAction() {
        $this->_helper->viewRenderer->setNoRender();
        ?>
        <form action="http://api.iphoneflashcards.com/import" method="post" enctype="multipart/form-data">
        Spreadsheet file: <input type="file" name="spreadsheet" />
        <br />
        <input type="submit" value="go!" />
        <input type="hidden" name="internal" value="1" />
        </form>
        <?php
    }

    public function parseExcelAction()
    {
        // action body
        
        $inputFileName = 'ratings.xlsx';
        /** Load $inputFileName to a PHPExcel Object  **/
        $objPHPExcel = PHPExcel_IOFactory::load($inputFileName);
        
        var_dump($objPHPExcel);
        
    }


}



