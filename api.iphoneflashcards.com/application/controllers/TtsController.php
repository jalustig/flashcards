
<?php

require_once 'PHPExcel/PHPExcel.php';
require_once 'Zend/Json.php';
require_once 'Zend/Db.php';
require_once 'Zend/Http/Client.php';

require_once 'FlashcardsServer_Exception.php';

class TtsController extends Zend_Controller_Action
{

    public function init()
    {
        /* Initialize action controller here */
    }

    public function indexAction()
    {
        die();
    }
    
    public function postAction() {
        if (!isset($_FILES['files'])) {
            die;
        }
        // var_dump($_FILES);
        foreach ($_FILES['files']['name'] as $key => $name) {
            $name = str_replace('/', '', $name);
            $name = str_replace('..', '', $name);
            $filename = '/home/iphonefl/tts/'.$name;
            // echo $filename."\n";
            move_uploaded_file($_FILES['files']['tmp_name'][$key], $filename);
        }
        die;
    }
    
    public function getAction() {
        $returnData = array();
        if (!isset($_REQUEST['file'])) {
            die;
        }
        $name = str_replace('/', '', $_REQUEST['file']);
        $name = str_replace('..', '', $name);
        $filename = '/home/iphonefl/tts/'.$name;
        header("Content-Type: audio/mp3");
        if (file_exists($filename)) {
            echo file_get_contents($filename);
        }
        die;
    }
    
    public function listAction() {
        $io = popen('/usr/bin/du -sb /home/iphonefl/tts', 'r');
        $size = intval(fgets($io,80));
        pclose($io);
        $size /= 1024;
        $size /= 1024;
        
        $directory = '/home/iphonefl/tts/';
        echo "Directory: $directory<br>\n";
        $d = count(glob($directory . "*.mp3"));
        echo "$d Entries, ".round($size,2)." MB<br>\n";
        foreach (glob($directory . "*.mp3") as $filename) {
            $parts = explode("/", $filename);
            echo "<a href='http://api.iphoneflashcards.com/tts/get?file=".$parts[count($parts)-1]."'>".$filename."</a> - ".filesize($filename)."<br>";
        }
        die;
    
    }
    
    public function prepareAction() {
        $db = Zend_Registry::get("db");
        if (isset($_REQUEST['device_id'])) {
            $device_id = $_REQUEST['device_id'];
        } else {
            $device_id = "";
        }
        foreach ($_REQUEST['text'] as $k => $text) {
            $language = $_REQUEST['language'][$k];
            if (strlen($text) > 100) {
                $text = substr($text, 0, 100);
            }
            $db->beginTransaction();
            $sql = "select term_id from offline_tts_terms where language = ".$db->quote($language)." and tts_text = ".$db->quote(strtolower($text));
            $results = $db->query($sql)->fetchAll();
            if (count($results) > 0) {
                $term_id = $results[0]['term_id'];
            } else {
                $data = array(
                    'tts_text' => strtolower($text),
                    'language' => $language,
                );
                $db->insert('offline_tts_terms', $data);
                $term_id = $db->lastInsertId('term_id');
            }
            $sql = "select term_id from offline_tts_devices where term_id = ".$db->quote($term_id)." and device_uuid = ".$db->quote($device_id);
            $results = $db->query($sql)->fetchAll();
            if (count($results) == 0) {
                if (strlen($device_id) > 0) {
                    $data = array(
                        'term_id' => $term_id,
                        'device_uuid' => $device_id, 
                    );
                    $db->insert('offline_tts_devices', $data);
                }
                $sql = "update offline_tts_terms set term_count = term_count + 1 where term_id = ".$db->quote($term_id);
                $db->query($sql);
            }
            $db->commit();
            // var_dump($data);
        }
        die;
    }
    
    public function transferAction() {
        $lockpath = '/home/iphonefl/tts/istransferring.txt';
        if (file_exists($lockpath) && !isset($_GET['test'])) {
            die;
        }
        $fh = fopen($lockpath, 'a');
        fwrite($fh, '<h1>Hello world!</h1>');
        fclose($fh);
        set_time_limit(10000);
        $db = Zend_Registry::get("db");
        $db->beginTransaction();
        $sql = "select * from offline_tts limit 10000";
        $termResults = $db->query($sql)->fetchAll();
        $i = 0;
        foreach ($termResults as $term) {
            $text = $term['tts_text'];
            $language = $term['language'];
            var_dump($term);
            echo "<br>";
            $sql = "select term_id from offline_tts_terms where language = ".$db->quote($language)." and tts_text = ".$db->quote(strtolower($text));
            $results = $db->query($sql)->fetchAll();
            if (count($results) > 0) {
                $term_id = $results[0]['term_id'];
            } else {
                $data = array(
                    'tts_text' => strtolower($text),
                    'language' => $language,
                );
                $db->insert('offline_tts_terms', $data);
                $term_id = $db->lastInsertId('term_id');
            }
            if ($term['attempted_to_get']) {
                $sql = "update offline_tts_terms set attempted_to_get = true, term_count = term_count + 1 where term_id = ".$db->quote($term_id);
            } else {
                $sql = "update offline_tts_terms set term_count = term_count + 1 where term_id = ".$db->quote($term_id);
            }
            echo $sql;
            $db->query($sql);
            $sql = 'delete from offline_tts where term_id = '.$term['term_id'];
            echo $sql."<br>";
            $db->query($sql);
            echo "<hr>";
            $i++;
            if ($i % 50 == 0) {
                $db->commit();
                $db->beginTransaction();
            }
        }
        $db->commit();
        unlink($lockpath);
        die;
    }
    
    public function makefilenamesAction() {
        $lockpath = '/home/iphonefl/tts/ismakefilenames2.txt';
        if (file_exists($lockpath) && !isset($_GET['test'])) {
            die;
        }
        $fh = fopen($lockpath, 'a');
        fwrite($fh, '<h1>Hello world!</h1>');
        fclose($fh);
        set_time_limit(10000);
        $db = Zend_Registry::get("db");
        $db->beginTransaction();
        $sql = "select term_id, tts_text, language from offline_tts_terms where filename = '' limit 150000";
        $termResults = $db->query($sql)->fetchAll();
        $i = 0;
        foreach ($termResults as $term) {
            $filename = md5($term['tts_text']).'-'.$term['language'].'.mp3';
            $sql = "update offline_tts_terms set filename = ".$db->quote($filename)." where term_id = ".$db->quote($term['term_id']);
            $db->query($sql);
            echo $sql;
            echo "<hr>";
            $i++;
            if ($i % 50 == 0) {
                $db->commit();
                $db->beginTransaction();
            }
        }
        $db->commit();
        unlink($lockpath);
        die;
    }
    
    public function setfilesizesAction() {
        $lockpath = '/home/iphonefl/tts/issetfilesizes3.txt';
        if (file_exists($lockpath) && !isset($_GET['test'])) {
            die('lockfile');
        }
        $fh = fopen($lockpath, 'a');
        fwrite($fh, '<h1>Hello world!</h1>');
        fclose($fh);
        set_time_limit(10000);
        $db = Zend_Registry::get("db");
        $db->beginTransaction();
        $sql = "select term_id, tts_text, language, filename from offline_tts_terms where attempted_to_get = true and filesize_set = false limit 100";
        $termResults = $db->query($sql)->fetchAll();
        $i = 0;
        $directory = '/home/iphonefl/tts/';
        foreach ($termResults as $term) {
            $filesize = filesize($directory.$term['filename']);
            $sql = "update offline_tts_terms set filesize = ".$db->quote($filesize).", filesize_set = true where term_id = ".$db->quote($term['term_id']);
            echo $sql;
            $db->query($sql);
            echo "<hr>";
            $i++;
            if ($i % 50 == 0) {
                $db->commit();
                $db->beginTransaction();
            }
        }
        $db->commit();
        unlink($lockpath);
        die;
    }
    
    public function removeblankfilesAction() {
        $lockpath = '/home/iphonefl/tts/isremoveblankfiles.txt';
        if (file_exists($lockpath) && !isset($_GET['test'])) {
            die('lockfile');
        }
        if (!isset($_GET['test'])) {
            $fh = fopen($lockpath, 'a');
            fwrite($fh, '<h1>Hello world!</h1>');
            fclose($fh);
        }
        set_time_limit(10000);
        $db = Zend_Registry::get("db");
        $db->beginTransaction();
        $sql = "select term_id, tts_text, language, filename from offline_tts_terms where attempted_to_get = true and filesize_set = true and filesize < 5 limit 500";
        $termResults = $db->query($sql)->fetchAll();

        $i = 0;
        $directory = '/home/iphonefl/tts/';
        foreach ($termResults as $term) {
            $fullFilePath = $directory.$term['filename'];
            if (!file_exists($fullFilePath)) {
                echo 'file does not exist<hr>';
                continue;
            }
            $filesize = filesize($fullFilePath);
            if ($filesize < 5) {
                $sql = "update offline_tts_terms set filesize = ".$db->quote($filesize).", filesize_set = false, attempted_to_get = false where term_id = ".$db->quote($term['term_id']);
                echo $sql."<br>";;
                $db->query($sql);
                echo "$fullFilePath<br>";
                unlink($fullFilePath);
            } else {
                echo 'file is larger';
            }
            echo "<hr>";
            $i++;
            if ($i % 50 == 0) {
                $db->commit();
                $db->beginTransaction();
            }
        }
        $db->commit();
        if (!isset($_GET['test'])) {
            unlink($lockpath);
        }
        die;
    }
    
    public function statusAction() {
        set_time_limit(100);
        $db = Zend_Registry::get("db");
        $sql = "select count(*) from offline_tts_terms where attempted_to_get = '0'";
        $result = $db->query($sql)->fetchAll();
        $not_yet_attempted = $result[0]['count'];
        $sql = "select count(*) from offline_tts_terms where attempted_to_get = '1'";
        $result = $db->query($sql)->fetchAll();
        $already_attempted = $result[0]['count'];
        
        echo "# attempted: $already_attempted<br>\n";
        echo "# still to go: $not_yet_attempted<br>\n";
        
        /*
        $io = popen('/usr/bin/du -sb /home/iphonefl/tts', 'r');
        $size = intval(fgets($io,80));
        pclose($io);
        $size /= 1024;
        $size /= 1024;

        echo "<br><hr><br>";
        */
        
        $directory = '/home/iphonefl/tts/';
        echo "Directory: $directory<br>\n";
        
        $sql = "select language, count(language) from offline_tts_terms group by language order by language";
        $languages = $db->query($sql)->fetchAll();
        $sql = "select language, count(language) from offline_tts_terms where attempted_to_get = '0' group by language order by language ";
        $languages_to_go = $db->query($sql)->fetchAll();
        
        foreach ($languages as $k => $l) {
            $languages[$k]['filecount'] = 0;
        }
        
        $count = 0;
        if ($handle = opendir($directory)) {
            while (false !== ($file = readdir($handle))) {
                if (substr($file, -4, 4) == '.mp3') {
                    $count++;
                }
                foreach ($languages as $k => $l) {
                    $match = $l['language'].".mp3";
                    if (substr($file, -1*strlen($match), strlen($match)) == $match) {
                        $languages[$k]['filecount']++;
                        continue;
                    }
                }
            }
            closedir($handle);
        }
        echo "$count Entries<br>\n"; #, ".round($size,2)." MB<br>\n";
        ?>
        <br>
        <hr>
        <br>
        <table border="2">
            <tr>
                <th>Language</th>
                <th># Files</th>
                <th># Terms TOTAL</th>
                <th># Terms REMAINING</th>
            </tr>
            <?php
            foreach ($languages as $l) {
                ?><tr>
                    <td><?php echo htmlspecialchars($l['language']); ?></td>
                    <td><?php echo htmlspecialchars($l['filecount']); ?></td>
                    <td><?php echo htmlspecialchars($l['count']); ?></td>
                    <td>
                        <?php
                    foreach ($languages_to_go as $l2) {
                        if ($l['language'] == $l2['language']) {
                            echo $l2['count'];
                        }
                    }
                        ?>
                    </td>
                </tr>
                <?php
            }
            ?>
        </table>
        <?php
        die;
    
    }
    
    public function countAction() {
        $db = Zend_Registry::get("db");
        if ($_GET['type'] == 'new') {
            $table = '(select * from offline_tts
             where attempted_to_get = \'0\') as tts';
        } else {
            $table = 'offline_tts';
        }
        $sql = "
            select tts_text, count(tts_text) as thecount
            from ".$table."
            group by tts_text
            order by thecount desc
            limit 3000";
        $results = $db->query($sql)->fetchAll();
        ?><table><tr><th>Text</th><th>#</th></tr>
        <?php
        $count = 0;
        foreach ($results as $r) {
            ?>
            <tr>
                <td><?php echo htmlspecialchars($r['tts_text']); ?></td>
                <td><?php echo htmlspecialchars($r['thecount']);
                $count += $r['thecount'];
                 ?></td>
            </tr>
            <?php
        }
        echo "</table>";
echo "TOTAL: $count";
        die;
    }
    
    public function runAction() {
        $lockpath = '/home/iphonefl/tts/isrunning.txt';
        if (file_exists($lockpath) && !isset($_GET['test'])) {
            die;
        }
        $db = Zend_Registry::get("db");
        
        $fh = fopen($lockpath, 'a');
        fwrite($fh, '<h1>Hello world!</h1>');
        fclose($fh);

        // This is actually exactly the same:
        $adapter = new Zend_Http_Client_Adapter_Curl();
        $adapter->setCurlOption(CURLOPT_REFERER, 'http://translate.google.com/');

        $client = new Zend_Http_Client();
        $client->setAdapter($adapter);
        $client->setConfig(array(
            'maxredirects' => 0,
            'timeout'      => 30,
            'useragent'    => 'Mozilla/6.0 (Windows NT 6.2; WOW64; rv:16.0.1) Gecko/20121011 Firefox/16.0.1',
        ));
        
        $sql = 'select term_id, tts_text, language, term_count
             from offline_tts_terms
             where attempted_to_get = \'0\' and language != \'iw\'
            order by term_count desc
             limit 500';
        $terms = $db->query($sql)->fetchAll();
        // var_dump($terms);
        foreach ($terms as $term) {
            $term['tts_text'] = strtolower($term['tts_text']);
            $filename = md5($term['tts_text']).'-'.$term['language'].'.mp3';
            $filepath = '/home/iphonefl/tts/'.$filename;
            if (file_exists($filepath)) {
                $sql = "
                update offline_tts_terms set
                attempted_to_get = '1',
                filename = ".$db->quote($filename)."
                 where term_id = ".$db->quote($term['term_id']);
                $db->query($sql);
                // echo "file found: $term[tts_text] --> $filename<br>";
                continue;
            }
            
            // get the data from google:
            $client->setUri('http://www.translate.google.com/translate_tts?tl='.urlencode($term['language']).'&q='.urlencode($term['tts_text']));
            $response = $client->request('GET');
            if (!$response->isRedirect()) {
                if (strlen($response->getBody()) < 6) {
                    continue;
                }
                file_put_contents($filepath, $response->getBody());
                $filesize = filesize($filepath);
                $sql = "
                update offline_tts_terms set
                attempted_to_get = '1',
                filename = ".$db->quote($filename).",
                filesize = ".$db->quote($filesize)."
                where term_id = ".$db->quote($term['term_id']);
                $db->query($sql);
                echo strlen($response->getBody())." bytes: $filepath<br>\n";
            } else {
                echo "CAUGHT!<br>\n";
            }
            
            $microseconds = 2200000 + rand(0800000, 2200000);
            usleep($microseconds);
        }

        unlink($lockpath);

        die;
    }
    
    public function clearAction() {
        $db = Zend_Registry::get("db");
        $sql = "select distinct lower(tts_text) as tts_text_term, language, attempted_to_get from offline_tts_terms where attempted_to_get = '1'";
        $results = $db->query($sql)->fetchAll();
        foreach ($results as $r) {
            $sql = "
            update offline_tts_terms set attempted_to_get = '1'
            where language = ".$db->quote($r['language'])." and lower(tts_text) = ".$db->quote($r['tts_text']);
            $db->query($sql);
            unset($r);
        }
    }
    
}


?>
