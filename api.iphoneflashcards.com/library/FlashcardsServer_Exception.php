<?php

require_once 'Zend/Exception.php';
require_once 'Zend/Json.php';

class FlashcardsServer_Exception extends Zend_Exception {
    
    public $isError = true;
    
    function toJson($error_number) {
        $response = array(
            'response_type' => ($this->isError ? 'error' : 'ok'),
            'error_number' => $error_number,
            'short_text' => $this->getMessage(),
            'long_text' => $this->getMessage(),
            );
        return Zend_Json::encode($response);
    }

}

?>