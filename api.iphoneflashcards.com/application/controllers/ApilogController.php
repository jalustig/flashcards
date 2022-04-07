<?php

class ApilogController extends Zend_Controller_Action
{
    public $db;
    
    public function init()
    {
        /* Initialize action controller here */
    }

    public function indexAction()
    {
        // action body
        $db = Zend_Registry::get("db");
        $sql = 'select *, datestamp - interval \'7 hours\' as datestamp_tz from api_log order by datestamp desc limit 2000';
        $results = $db->query($sql)->fetchAll();
        $this->view->results = $results;
    }

    public function versionsAction()
    {
        
        if (!isset($_GET['see']) || $_GET['see'] != 'numbers') {
            $_GET['see'] = 'percent';
        }
        if (!isset($_GET['groupby']) || ($_GET['groupby'] != 'day' && $_GET['groupby'] != 'month')) {
            $_GET['groupby'] = 'week';
        }
        
        $db = Zend_Registry::get("db");
        
        if ($_GET['groupby'] == 'week') {
            $group_by1 = 'extract(week from cast(datestamp - interval \'7 hours\' AS DATE))';
        } else if ($_GET['groupby'] == 'month') {
            $group_by1 = 'extract(month from cast(datestamp - interval \'7 hours\' AS DATE))';
        } else {
            $group_by1 = 'cast(datestamp - interval \'7 hours\' AS DATE)';
        }
        $group_by2 = 'extract(year from cast(datestamp - interval \'7 hours\' AS DATE))';
        $sql = 'select '.$group_by1.' as the_date, '.$group_by2.' as the_year, count(app_version) as number_calls, app_version
                from api_log
                where length(app_version) > 0 and 
                ip_address != '.$db->quote($_SERVER['REMOTE_ADDR']).' and
                group by the_year, the_date, app_version
                order by the_year desc, the_date desc, app_version asc';
        $data = $db->query($sql)->fetchAll();
        
        $results = array();
        $app_versions = array();
        foreach ($data as $d) {
            $key = "$d[the_year]-$d[the_date]";
            if (!isset($results[$key])) {
                $results[$key] = array();
            }
            $results[$key][$d['app_version']] = $d['number_calls'];
            if (!in_array($d['app_version'], $app_versions)) {
                $app_versions[] = $d['app_version'];
            }
        }
        
        $app_versions = array(
            '2.0',
            '2.1',
            '4.0',
            '4.0.1',
            '4.0.2',
            '4.0.3',
            '4.1',
            '4.2',
            '4.2.1',    
            '4.3',
            '4.3.5',
            '4.4',
            '4.4.11',
            '4.5',
            '4.5.1',
            '4.5.2',
            '4.5.3',
            '5.0',
    );
        
        $this->view->app_versions = $app_versions;
        $this->view->results = $results;
    }

    public function websitesAction() {
        if (!isset($_GET['see']) || $_GET['see'] != 'numbers') {
            $_GET['see'] = 'percent';
        }
        if (!isset($_GET['groupby']) || ($_GET['groupby'] != 'day' && $_GET['groupby'] != 'month')) {
            $_GET['groupby'] = 'week';
        }
        
        $db = Zend_Registry::get("db");
        
        if ($_GET['groupby'] == 'week') {
            $group_by1 = 'extract(week from cast(datestamp - interval \'7 hours\' AS DATE))';
        } else if ($_GET['groupby'] == 'month') {
            $group_by1 = 'extract(month from cast(datestamp - interval \'7 hours\' AS DATE))';
        } else {
            $group_by1 = 'cast(datestamp - interval \'7 hours\' AS DATE)';
        }
        $group_by2 = 'extract(year from cast(datestamp - interval \'7 hours\' AS DATE))';
        $sql = 'select '.$group_by1.' as the_date, '.$group_by2.' as the_year, count(controller) as number_calls, controller as website
                from api_log
                where
                (app_version = \'4.5\' or
                app_version = \'4.5.1\' or
                app_version = \'4.5.2\' or
                app_version = \'4.5.3\' or
                app_version = \'5.0\') and
                
                 length(controller) > 0
 
                group by the_year, the_date, controller
                order by the_year desc, the_date desc, controller asc';
        $data = $db->query($sql)->fetchAll();
        
        $results = array();
        $app_versions = array();
        foreach ($data as $d) {
            $key = "$d[the_year]-$d[the_date]";
            if (!isset($results[$key])) {
                $results[$key] = array();
            }
            $results[$key][$d['website']] = $d['number_calls'];
            if (!in_array($d['website'], $app_versions)) {
                $app_versions[] = $d['website'];
            }
        }
        
        $app_versions = array(
            'quizlet',
            'FlashcardExchange',
            'import',
            );
        
        $this->view->app_versions = $app_versions;
        $this->view->results = $results;
    
    }

    public function iosversionsAction()
    {
        
        if (!isset($_GET['see']) || $_GET['see'] != 'numbers') {
            $_GET['see'] = 'percent';
        }
        if (!isset($_GET['groupby']) || ($_GET['groupby'] != 'day' && $_GET['groupby'] != 'month')) {
            $_GET['groupby'] = 'week';
        }
        
        $db = Zend_Registry::get("db");
        
        if ($_GET['groupby'] == 'week') {
            $group_by1 = 'extract(week from cast(datestamp - interval \'7 hours\' AS DATE))';
        } else if ($_GET['groupby'] == 'month') {
            $group_by1 = 'extract(month from cast(datestamp - interval \'7 hours\' AS DATE))';
        } else {
            $group_by1 = 'cast(datestamp - interval \'7 hours\' AS DATE)';
        }
        $group_by2 = 'extract(year from cast(datestamp - interval \'7 hours\' AS DATE))';
        $sql = 'select '.$group_by1.' as the_date, '.$group_by2.' as the_year, count(substring(ios_version for 3)) as number_calls, substring(ios_version for 3) as ios_version
                from api_log
                where
                app_version != \'4.0b1\' and
                app_version != \'4.0b2\' and
                app_version != \'4.0b3\' and
                app_version != \'4.1b1\' and
                app_version != \'4.1b2\' and
                app_version != \'4.1b3\' and
                app_version != \'4.2b1\' and
                app_version != \'4.2b2\' and
                app_version != \'4.3b1\' and
                app_version != \'4.3b2\' and
                app_version != \'4.5b1\' and
                app_version != \'4.5b2\' and
                app_version != \'4.5b3\' and
                app_version != \'4.5b4\' and
                app_version != \'4.4.11fce\' and
                app_version != \'4.5fce\' and
                app_version != \'5.0b1\' and
                app_version != \'5.0b2\' and
                app_version != \'5.0b3\' and
                app_version != \'5.0b4\' and

                 length(ios_version) > 0
 
                group by the_year, the_date, substring(ios_version for 3)
                order by the_year desc, the_date desc, substring(ios_version for 3) asc';
        $data = $db->query($sql)->fetchAll();
        
        $results = array();
        $app_versions = array();
        foreach ($data as $d) {
            $key = "$d[the_year]-$d[the_date]";
            if (!isset($results[$key])) {
                $results[$key] = array();
            }
            $results[$key][$d['ios_version']] = $d['number_calls'];
            if (!in_array($d['ios_version'], $app_versions)) {
                $app_versions[] = $d['ios_version'];
            }
        }
        
        $app_versions = array(
            '3.2',
#            '3.2.1',
#            '3.2.2',
            '4.0',
#            '4.0.1',
#            '4.0.2',
            '4.1',
            '4.2',
#            '4.2.1',
#            '4.2.5',
#            '4.2.6',
#            '4.2.7',
#            '4.2.8',
#            '4.2.9',
#            '4.2.10',
            '4.3',
#            '4.3.1',
#            '4.3.2',
#            '4.3.3',
#            '4.3.4',
#            '4.3.5',
            '5.0',
            '5.1',
            '6.0',
            );
        
        $this->view->app_versions = $app_versions;
        $this->view->results = $results;
    }

}

