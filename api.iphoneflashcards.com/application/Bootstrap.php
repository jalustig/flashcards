<?php

// as per: http://stackoverflow.com/a/11902451/353137

class Application_Router_Cli extends Zend_Controller_Router_Abstract
{
    public function route (Zend_Controller_Request_Abstract $dispatcher)
    {
        $getopt     = new Zend_Console_Getopt (array ());
        $arguments  = $getopt->getRemainingArgs();

        if ($arguments)
        {
            $command = array_shift( $arguments );
            $action  = array_shift( $arguments );
            if(!preg_match ('~\W~', $command) )
            {
                $dispatcher->setControllerName( $command );
                $dispatcher->setActionName( $action );
                $dispatcher->setParams( $arguments );
                return $dispatcher;
            }

            echo "Invalid command.\n", exit;

        }

        echo "No command given.\n", exit;
    }


    public function assemble ($userParams, $name = null, $reset = false, $encode = true)
    {
        echo "Not implemented\n", exit;
    }
}

class Bootstrap extends Zend_Application_Bootstrap_Bootstrap
{
    protected function _initDb() {
        $db = Zend_Db::factory('Pdo_Pgsql', array(
            'host' => '127.0.0.1',
            'username' => 'username',
            'password' => 'password',
            'dbname' => 'dbname',
            ));
        Zend_Registry::set("db", $db);
        return $db;
    }

    protected function _initRouter()
    {
        if( PHP_SAPI == 'cli' )
        {
            $this->bootstrap( 'FrontController' );
            $front = $this->getResource( 'FrontController' );
            $front->setParam('disableOutputBuffering', true);
            $front->setRouter( new Application_Router_Cli() );
            $front->setRequest( new Zend_Controller_Request_Simple() );
        }
    }
    /*
    protected function _initError ()
    {
        $this->bootstrap( 'FrontController' );
        $front = $this->getResource( 'FrontController' );
        $front->registerPlugin( new Zend_Controller_Plugin_ErrorHandler() );
        $error = $front->getPlugin ('Zend_Controller_Plugin_ErrorHandler');
        $error->setErrorHandlerController('index');

        if (PHP_SAPI == 'cli')
        {
            $error->setErrorHandlerController ('error');
            $error->setErrorHandlerAction ('cli');
        }
    }
    */
    

}



