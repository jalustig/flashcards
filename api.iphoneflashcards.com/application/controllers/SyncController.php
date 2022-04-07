<?php

require_once 'PHPExcel/PHPExcel.php';
require_once 'Zend/Json.php';
require_once 'Zend/Db.php';
require_once 'Zend/Http/Client.php';
require_once 'Zend/Mail.php';
require_once 'UUID.php';

require_once 'FlashcardsServer_Exception.php';

define('API_KEY', 'api-key');
define('SECONDARY_KEY_ENCRYPTION_KEY', 'secondary-key');
define('CALL_KEY_ENCRYPTION_KEY', 'call-key');
define('FLASHCARDS_SERVER', 'api.iphoneflashcards.com');

// as per: http://stackoverflow.com/a/6914978/353137
// Read a file and display its content chunk by chunk
define('CHUNK_SIZE', 1024*1024); // Size (in bytes) of tiles chunk
function readfile_chunked($filename, $retbytes = TRUE) {
  $buffer = '';
  $cnt =0;
  // $handle = fopen($filename, 'rb');
  $handle = fopen($filename, 'rb');
  if ($handle === false) {
    return false;
  }
  while (!feof($handle)) {
    $buffer = fread($handle, CHUNK_SIZE);
    echo $buffer;
    ob_flush();
    flush();
    if ($retbytes) {
      $cnt += strlen($buffer);
    }
  }
  $status = fclose($handle);
  if ($retbytes && $status) {
    return $cnt; // return num. bytes delivered like readfile() does.
  }
  return $status;
}

class SyncController extends Zend_Controller_Action
{

    public $_user_id;
    
    public function getUserId() {
        return $this->_user_id;
    }
    
    public function init()
    {
        /* Initialize action controller here */
        if (!isset($_POST['email'])) {
            $_POST['email'] = '';
        }
        if (!isset($_REQUEST['email'])) {
            $_REQUEST['email'] = '';
        }
        if (!isset($_POST['login_key'])) {
            $_POST['login_key'] = '';
        }
        if (!isset($_REQUEST['login_key'])) {
            $_REQUEST['login_key'] = '';
        }
        if (!isset($_POST['device_id'])) {
            $_POST['device_id'] = '';
        }
        if (!isset($_REQUEST['device_id'])) {
            $_REQUEST['device_id'] = '';
        }
        if (!isset($_POST['filePath'])) {
            $_POST['filePath'] = '';
        }
        if (!isset($_REQUEST['filePath'])) {
            $_REQUEST['filePath'] = '';
        }

        $internal = $this->getRequest()->getParam('internal', 0);

        $this->_user_id = $this->userId($_REQUEST['email'], $_REQUEST['login_key'], '');

        // as per: http://stackoverflow.com/questions/1498692/how-do-you-make-zend-framework-not-render-a-view-layout-when-sending-an-ajax-resp/1498701#1498701
        $this->_helper->viewRenderer->setNoRender();

        $is_authenticated = $this->authenticateRequest();
    }

    public function indexAction()
    {
        die();
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
        $expectedPrimaryKey = strtolower(API_KEY.'/user/'.$this->getRequest()->getActionName());
        // echo 'Expected key: '.$expectedPrimaryKey."\n";
        return ($primaryKey == $expectedPrimaryKey) ? 1 : 0;
    }

    public function generateLoginKey($email) {
        return md5(microtime().$email.time());
    }
    
    public function folder($login_key = '') {
        $db = Zend_Registry::get("db");
        $sql = "
        select flashcards_users.sync_folder
        from flashcards_users
        where user_id = ".$db->quote($this->getUserId());
        $results = $db->query($sql)->fetchAll();
        $sync_folder = $results[0]['sync_folder'];
        $folder = '/home/iphonefl/sync/'.$sync_folder;
        return $folder;
    }
    
    public function userId($email, $login_key, $device_id, $create_new = FALSE) {
        $db = Zend_Registry::get("db");
        $user_id = -1;
        /* check against the email & login key: */
        if (strlen($email) > 0) {
            $sql = "
            select flashcards_users.user_id, has_subscription, subscription_ends, login_key
            from flashcards_users
            where
            email = ".$db->quote($email)." and
                login_key = ".$db->quote($login_key);
            $user = $db->query($sql)->fetchAll();
            if (count($user) > 0) {
                return $user[0]['user_id'];
            }
        }
        if (strlen($device_id) > 0) {
            /* if nothing exists, then check to see if a "dummy" user exists for the non-Apple UUID: */
            $sql = "select flashcards_users.user_id
            from flashcards_users left join flashcards_devices on flashcards_users.user_id = flashcards_devices.user_id
            where
                flashcards_devices.device_uuid = ".$db->quote($device_id);
            $check = $db->query($sql)->fetchAll();
            if (count($check) > 0) {
                $user_id = $check[0]['user_id'];
                if ($user_id > 0) {
                    return $user_id;
                }
            }
        }
        // return 3; // me
        // return 20; // john hanna
        // echo "Email: $email\n";
        // echo "Login key: $login_key\n";
        // echo "Device ID: $device_id\n";
        die("no valid user given");
    }
    
    // check if folder or file exists
    public function existsAction() {
        $file = $_REQUEST['filePath'];
        $fullpath = $this->folder().$file;
        $exists = 0;
        if (file_exists($fullpath)) {
            $exists = 1;
        }
        $return = array(
            'exists' => $exists,
        );
        ob_start("ob_gzhandler");
        echo Zend_JSON::encode($return);
        ob_end_flush();
        die;
    }
    
    public function createFolderHierarchyInFolder($hierarchy, $folder) {
        foreach ($hierarchy as $name => $contents) {
            $newfolder = $folder.$name;
            if (!file_exists($folder)) {
                mkdir($folder);
            }
            if (!file_exists($newfolder)) {
                mkdir($newfolder);
            }
            echo 'create: '.$newfolder."<br>\n";
            if (count($contents) > 0) {
                $this->createFolderHierarchyInFolder($contents, $newfolder.'/');
            }
        }
    }
    
    public function createfolderAction() {
        $rootFolder = $this->folder();
        if (!isset($_REQUEST['folders'])) {
            die;
        }
        foreach ($_REQUEST['folders'] as $folderName) {
            $parts = explode('/', $folderName);
            $currentFolder = $rootFolder;
            foreach ($parts as $part) {
                $currentFolder .= '/'.$part;
                if (!file_exists($currentFolder)) {
                    mkdir($currentFolder);
                }
            }
        }
    }
    
    // creates a hierarchy of folders, allowing the sync API to set up the data all at once
    // e.g.: http://api.iphoneflashcards.com/sync/establish?hierarchy={%22test%22:{%22folder1%22:{},%20%22folder2%22:{},%20%22folder3%22:{}},%22test2%22:{}}
    public function establishAction() {
        $hierarchy = Zend_JSON::decode($_REQUEST['hierarchy']);
        $folder = $this->folder();
        $inFolder = "";
        if (isset($_REQUEST['in_folder'])) {
            $inFolder = $_REQUEST['in_folder'];
        }
        if (strlen($inFolder) > 0) {
            if (!file_exists($folder.$inFolder)) {
                $parts = explode('/', $inFolder);
                $directory = $folder;
                foreach ($parts as $part) {
                    $directory .= '/'.$part;
                    if (!file_exists($directory)) {
                        echo "Creating: $directory<br>\n";
                        mkdir($directory);
                    } else {
                        echo "$directory currently exists<br>\n";
                    }
                }
            }
        }
        $folder .= $inFolder;
        echo "<b>$folder</b><br>\n";
        $this->createFolderHierarchyInFolder($hierarchy, $folder.'/');

        $db = Zend_Registry::get("db");
        $sql = "
        update flashcards_users
        set sync_created = '1'
        where user_id = ".$db->quote($this->getUserId());
        $db->query($sql);
    }
    
    public function recursive_remove_directory($directory, $empty=FALSE)
    {
        // if the path has a slash at the end we remove it here
        if(substr($directory,-1) == '/')
        {
            $directory = substr($directory,0,-1);
        }
     
        // if the path is not valid or is not a directory ...
        if(!file_exists($directory) || !is_dir($directory))
        {
            // ... we return false and exit the function
            return FALSE;
     
        // ... if the path is not readable
        }elseif(!is_readable($directory))
        {
            // ... we return false and exit the function
            return FALSE;
     
        // ... else if the path is readable
        }else{
     
            // we open the directory
            $handle = opendir($directory);
     
            // and scan through the items inside
            while (FALSE !== ($item = readdir($handle)))
            {
                // if the filepointer is not the current directory
                // or the parent directory
                if($item != '.' && $item != '..')
                {
                    // we build the new path to delete
                    $path = $directory.'/'.$item;
     
                    // if the new path is a directory
                    if(is_dir($path)) 
                    {
                        // we call this function with the new path
                        $this->recursive_remove_directory($path);
     
                    // if the new path is a file
                    }else{
                        // we remove the file
                        unlink($path);
                    }
                }
            }
            // close the directory
            closedir($handle);
     
            // if the option to empty is not set to true
            if($empty == FALSE)
            {
                // try to delete the now empty directory
                if(!rmdir($directory))
                {
                    // return false if not possible
                    return FALSE;
                }
            }
            // return success
            return TRUE;
        }
    }
    
    // allows user to empty out all of the data in his/her folder
    public function clearAction() {
        $folder = $this->folder();
        $this->recursive_remove_directory($folder);
        mkdir($folder);

        $db = Zend_Registry::get("db");
        $sql = "
        update flashcards_users
        set sync_created = '0'
        where user_id = ".$db->quote($this->getUserId());
        $db->query($sql);
    }
    
    public function uploadchunkAction() {
        $db = Zend_Registry::get("db");
        $db->beginTransaction();
        if (isset($_REQUEST['uploadUUID'])) {
            $upload_uuid = $_REQUEST['uploadUUID'];
            $sql = 'select upload_id from flashcards_uploads where upload_uuid = '.$db->quote($upload_uuid);
            $results = $db->query($sql)->fetchAll();
            if (count($results) == 0) {
                die;
            }
            $upload_id = $results[0]['upload_id'];
        } else {
            if (!isset($_REQUEST['totalFilesizeExpected'])) {
                $_REQUEST['totalFilesizeExpected'] = 0;
            }
            $upload_uuid = UUID::v4();
            $data = array(
                'upload_uuid' => $upload_uuid,
                'total_filesize_expected' => $_REQUEST['totalFilesizeExpected'],
            );
            $db->insert('flashcards_uploads', $data);
            $upload_id = $db->lastInsertId('upload_id');
        }
        if (!UUID::is_valid($upload_uuid)) {
            die;
        }
        $folder = '/home/iphonefl/uploads/'.$upload_uuid;
        if (!file_exists($folder)) {
            mkdir($folder);
        }
        
        $sql = 'select total_bytes_uploaded, total_filesize_expected from flashcards_uploads where upload_id = '.$db->quote($upload_id);
        $results = $db->query($sql)->fetchAll();
        if (count($results) == 0) {
            die;
        }
        $total_bytes_uploaded = $results[0]['total_bytes_uploaded'];
        $total_filesize_expected = $results[0]['total_filesize_expected'];
        
        $gzippedFinalFileName = $folder.'/'.((int)$total_bytes_uploaded).'.chunk.gz';
        
        $finalFileName = $folder.'/'.((int)$total_bytes_uploaded).'.chunk';

        move_uploaded_file($_FILES['chunkData']['tmp_name'], $gzippedFinalFileName);

        exec('gunzip '.$gzippedFinalFileName);
        if (file_exists($gzippedFinalFileName)) {
            unlink($gzippedFinalFileName);
        }
        
        $new_total_bytes_uploaded = (int)($total_bytes_uploaded + filesize($finalFileName)); 
        
        $sql = '
        update flashcards_uploads
        set total_bytes_uploaded = '.$new_total_bytes_uploaded.'
        where upload_id = '.$db->quote($upload_id);
        $db->query($sql);
        
        $db->commit();
        
        $responseData = array(
            'upload_uuid' => $upload_uuid,
            'offset' => $new_total_bytes_uploaded,
            'total_filesize_expected' => $total_filesize_expected,
        );
        ob_start("ob_gzhandler");
        echo Zend_JSON::encode($responseData);
        ob_end_flush();
    }
    
    public function chunksInOrder($source) {
        $d = dir($source);
        $navFolders = array('.', '..');
        $files = array();
        while (false !== ($fileEntry=$d->read() )) {//copy one by one
            //skip if it is navigation folder . or ..
            if (in_array($fileEntry, $navFolders) ) {
                continue;
            }
            $s = "$source/$fileEntry";
            $files[] = $s;
            // $this->delete($s);
        }
        
        natsort ($files);
        return $files;
    }
    
    public function checkuploadAction() {
        $source = '/home/iphonefl/uploads/'.$_REQUEST['uuid'];
        
        $files = $this->chunksInOrder($source);
        
        foreach ($files as $f) {
            echo "$f<br>";
        }
        die;
    
    }
    
    public function finishuploadAction() {
        $db = Zend_Registry::get("db");
        $db->beginTransaction();

        if (!isset($_REQUEST['uploadUUID'])) {
            die;
        }
        $upload_uuid = $_REQUEST['uploadUUID'];
        if (!UUID::is_valid($upload_uuid)) {
            die;
        }

        $sql = 'select upload_id, total_filesize_expected from flashcards_uploads where upload_uuid = '.$db->quote($upload_uuid);
        $results = $db->query($sql)->fetchAll();
        if (count($results) == 0) {
            die;
        }
        $upload_id = $results[0]['upload_id'];
        $total_filesize_expected = $results[0]['total_filesize_expected'];

        $uploadFolder = '/home/iphonefl/uploads/'.$upload_uuid.'/';
        if (!file_exists($uploadFolder)) {
            die;
        }
        
        $userFolder = $this->folder();

        $finalFileName = $userFolder.$_REQUEST['finalLocation'];
        if ($finalFileName[strlen($finalFileName)-1] != '/') {
            $finalFileName .= '/';
        }
        $finalFileName .= $_REQUEST['finalFileName'];

        $files = $this->chunksInOrder($uploadFolder);
        if (file_exists($finalFileName)) {
            if (!is_file($finalFileName)) {
                die('exists but is a directory');
            }
            unlink($finalFileName);
        }
        if (!file_exists($finalFileName)) {
            $asciifile = fopen($finalFileName, "w");
            fclose($asciifile);
        }
        foreach ($files as $f) {
            // echo "<hr>".$f."<br>";
            file_put_contents($finalFileName, file_get_contents($f), FILE_APPEND);
        }
        if (filesize($finalFileName) != $total_filesize_expected) {
            die('incorrect file size');
        }
        
        $sql = "update flashcards_uploads set is_finished = 't' where upload_id = ".$db->quote($upload_id);
        $db->query($sql);
        
        $this->delete($uploadFolder);
        
        $db->commit();
    }
    
    public function deletechunksAction() {
        $db = Zend_Registry::get("db");
        $db->beginTransaction();
        $sql = "select upload_id, upload_uuid from flashcards_uploads where date_created <= (now() - interval '24 hours')";
        $results = $db->query($sql)->fetchAll();
        foreach ($results as $upload) {
            $uploadFolder = '/home/iphonefl/uploads/'.$upload['upload_uuid'].'/';
            if (file_exists($uploadFolder)) {
                echo "delete: $uploadFolder<br />";
                $this->delete($uploadFolder);
            }
            $sql = 'delete from flashcards_uploads wehre upload_id = '.$db->quote($upload['upload_id']);
            $db->query($sql);
        }
        $db->commit();
    }
    
    public function uploadAction() {
        $folder = $this->folder();
        echo 'test';
        $finalFileName = $folder.$_REQUEST['toPath'];
        if ($finalFileName[strlen($finalFileName)-1] != '/') {
            $finalFileName .= '/';
        }
        $finalFileName .= $_REQUEST['fileName'];
        move_uploaded_file($_FILES['fileData']['tmp_name'], $finalFileName);
    }
    public function downloadAction() {
        $folder = $this->folder();
        $finalFileName = $folder.$_REQUEST['filePath'];
        if (!file_exists($finalFileName)) {
            header('HTTP/1.0 404 Not Found');
            echo "404 file not found";
            die;
        }
        $pack = true;
        if(!empty($_SERVER["HTTP_ACCEPT_ENCODING"]) && strpos("gzip",$_SERVER["HTTP_ACCEPT_ENCODING"]) === NULL) {
            $pack = false;
        }
        header("Content-Type: application/octet-stream");

        if($pack) {
            $tempName = $finalFileName.'-'.md5(microtime()).'-copy';
            exec('cp '.$finalFileName.' '.$tempName.'; gzip '.$tempName);
            header("Content-Encoding: gzip");
            header("Content-Length: ".filesize($tempName.'.gz'));
            readfile_chunked($tempName.'.gz');
            if (file_exists($tempName)) {
                unlink($tempName);
            }
            if (file_exists($tempName.'.gz')) {
                unlink($tempName.'.gz');
            }
        } else {
            header("Content-Length: ".filesize($finalFileName));
            readfile_chunked($finalFileName);
        }
    }
    
    public function deleteAction() {
        $rootFolder = $this->folder();
        if (!isset($_REQUEST['files'])) {
            die;
        }
        foreach ($_REQUEST['files'] as $fileName) {
            $finalFileName = $rootFolder.$fileName;
            $this->delete($finalFileName);
        }
    }
    
    public function delete($source) {
        if (!is_dir($source)) {//it is a file, do a normal copy
            unlink($source);
            return;
        }

        //it is a folder, copy its files & sub-folders
        $d = dir($source);
        $navFolders = array('.', '..');
        while (false !== ($fileEntry=$d->read() )) {//copy one by one
            //skip if it is navigation folder . or ..
            if (in_array($fileEntry, $navFolders) ) {
                continue;
            }
            $s = "$source/$fileEntry";
            $this->delete($s);
        }
        $d->close();
        rmdir($source);
    }
    
    public function copyAction() {
        $folder = $this->folder();
        $fromFilePath = $folder.$_REQUEST['fromPath'];
        $toFilePath = $folder.$_REQUEST['toPath'];
        
        echo "From: $fromFilePath\n";
        echo "To: $toFilePath\n";
        
        $this->copy($fromFilePath, $toFilePath);
        if (!(strpos($fromFilePath, '/TemporaryFiles/WholeStore/') === false)) {
            $this->delete($fromFilePath);
        }
    }
    
    // as per: http://stackoverflow.com/a/8459443/353137
    public function copy($source, $target) {
        if (!is_dir($source)) {//it is a file, do a normal copy
            copy($source, $target);
            return;
        }

        //it is a folder, copy its files & sub-folders
        @mkdir($target);
        $d = dir($source);
        $navFolders = array('.', '..');
        while (false !== ($fileEntry=$d->read() )) {//copy one by one
            //skip if it is navigation folder . or ..
            if (in_array($fileEntry, $navFolders) ) {
                continue;
            }

            //do copy
            $s = "$source/$fileEntry";
            $t = "$target/$fileEntry";
            $this->copy($s, $t);
        }
        $d->close();
    }
    

    public function moveAction() {
        $folder = $this->folder();
        $fromFilePath = $folder.$_REQUEST['fromPath'];
        $toFilePath = $folder.$_REQUEST['toPath'];
        copy($fromFilePath, $toFilePath);
    }
    
    public function metadataAction() {
        $folder = $this->folder();
        if ($_REQUEST['filePath'] == '/') {
            $_REQUEST['filePath'] = '';
        }
        $finalPath = $this->folder().$_REQUEST['filePath'];
        $recursive = 0;
        if (isset($_REQUEST['recursive'])) {
            $recursive = $_REQUEST['recursive'];
        }
        $directories = 1;
        if (isset($_REQUEST['directories'])) {
            $directories = $_REQUEST['directories'];
        }
        $files = 1;
        if (isset($_REQUEST['files'])) {
            $files = $_REQUEST['files'];
        }
        if (!file_exists($finalPath)) {
            header('HTTP/1.0 404 Not Found');
            echo "404 file not found";
            die;
        }
        $metadata = $this->metadata($finalPath, $folder);
        if ($metadata['isDirectory']) {
            $contents = array();
            if ($handle = opendir($finalPath)) {
                while (false !== ($entry = readdir($handle))) {
                    if ($entry == "." || $entry == "..") {
                        continue;
                    }
                    $totalFileName = $finalPath.'/'.$entry;
                    if (is_dir($totalFileName)) {
                        if (!$directories) {
                            continue;
                        }
                    } else {
                        if (!$files) {
                            continue;
                        }
                    }
                    $contents[] = $this->metadata($totalFileName, $folder, $recursive);
                }
                closedir($handle);
            }
            $metadata['contents'] = $contents;
        }
        ob_start("ob_gzhandler");
        echo Zend_JSON::encode($metadata);
        ob_end_flush();
        die;
    }
    
    public function metadata($finalPath, $mainFolder, $recursive = 0, $directories = 1, $files = 1) {
        $pathData = explode('/', $finalPath);
        $metadata = array();
        $metadata['fileName'] = $pathData[count($pathData)-1];
        $metadata['relativeFilePath'] = substr($finalPath, strlen($mainFolder));
        $metadata['isDirectory'] = is_dir($finalPath);
        $metadata['dateModified'] = filemtime($finalPath);
        $metadata['contents'] = array();
        if (!$metadata['isDirectory']) {
            $metadata['fileSize'] = filesize($finalPath);
            $pathinfo = pathinfo($finalPath);
            if (!isset($pathinfo['extension'])) {
                $pathinfo['extension'] = '';
            }
            $metadata['extension'] = $pathinfo['extension'];
        }
        if ($metadata['isDirectory'] && $recursive) {
            $contents = array();
            if ($handle = opendir($finalPath)) {
                while (false !== ($entry = readdir($handle))) {
                    if ($entry == "." || $entry == "..") {
                        continue;
                    }
                    $totalFileName = $finalPath.'/'.$entry;
                    if (is_dir($totalFileName)) {
                        if (!$directories) {
                            continue;
                        }
                    } else {
                        if (!$files) {
                            continue;
                        }
                    }
                    $contents[] = $this->metadata($totalFileName, $mainFolder, $recursive);
                }
                closedir($handle);
            }
            $metadata['contents'] = $contents;
        }
        return $metadata;
    }
    
    public function uploadbeganAction() {
        $db = Zend_Registry::get("db");
        $sql = "
        update flashcards_users
        set sync_currently_uploading = 't'
        where user_id = ".$db->quote($this->getUserId());
        $db->query($sql);
    }
    
    public function uploadfinishedAction() {
        $db = Zend_Registry::get("db");
        $sql = "
        update flashcards_users
        set sync_currently_uploading = 'f'
        where user_id = ".$db->quote($this->getUserId());
        $db->query($sql);
    }
    
    public function updatesyncdatesAction() {
        $db = Zend_Registry::get("db");
        
        $sync_last_upload_database_wait = -1;
        $sync_last_upload_database_prompt = -1;
        $sync_last_upload_database = -1;
        $quizlet_last_sync = -1;
        $flashcard_exchange_last_sync = -1;
        $sync_last_sync = -1;
        if (isset($_REQUEST['quizlet'])) {
            $quizlet_last_sync = (int)$_REQUEST['quizlet'];
        }
        if (isset($_REQUEST['flashcardExchange'])) {
            $flashcard_exchange_last_sync = (int)$_REQUEST['flashcardExchange'];
        }
        if (isset($_REQUEST['fcpp'])) {
            $sync_last_sync = (int)$_REQUEST['fcpp'];
        }
        if (isset($_REQUEST['sync_last_upload_database_wait'])) {
            $sync_last_upload_database_wait = (int)$_REQUEST['sync_last_upload_database_wait'];
        }
        if (isset($_REQUEST['sync_last_upload_database_prompt'])) {
            $sync_last_upload_database_prompt = (int)$_REQUEST['sync_last_upload_database_prompt'];
        }
        if (isset($_REQUEST['sync_last_upload_database'])) {
            $sync_last_upload_database = (int)$_REQUEST['sync_last_upload_database'];
        }
        
        if ($sync_last_upload_database_wait > 0) {
            $sql = "
            update flashcards_users
            set 
            sync_last_upload_database_wait = ".$db->quote($sync_last_upload_database_wait)."
            where user_id = ".$db->quote($this->getUserId());
            $db->query($sql);
        }
        
        if ($sync_last_upload_database_prompt > 0) {
            $sql = "
            update flashcards_users
            set 
            sync_last_upload_database_prompt = ".$db->quote($sync_last_upload_database_prompt)."
            where user_id = ".$db->quote($this->getUserId())."
                and
                sync_last_upload_database_prompt < ".$db->quote($sync_last_upload_database_prompt);
            $db->query($sql);
        }
        
        if ($sync_last_upload_database > 0) {
            $sql = "
            update flashcards_users
            set 
            sync_last_upload_database = ".$db->quote($sync_last_upload_database)."
            where
                user_id = ".$db->quote($this->getUserId())."
                and
                sync_last_upload_database < ".$db->quote($sync_last_upload_database);
            $db->query($sql);
        }
        
        if ($sync_last_sync > 0) {
            $sql = "
            update flashcards_users
            set 
            sync_last_sync = ".$db->quote($sync_last_sync)."
            where
                user_id = ".$db->quote($this->getUserId())."
                and
                sync_last_sync < ".$db->quote($sync_last_sync);
            $db->query($sql);
        }
        
        if ($quizlet_last_sync > 0) {
            $sql = "
            update flashcards_users
            set 
            quizlet_last_sync = ".$db->quote($quizlet_last_sync)."
            where user_id = ".$db->quote($this->getUserId())."
                and
                quizlet_last_sync < ".$db->quote($quizlet_last_sync);
            $db->query($sql);
        }

        if ($flashcard_exchange_last_sync > 0) {
            $sql = "
            update flashcards_users
            set 
            flashcard_exchange_last_sync = ".$db->quote($flashcard_exchange_last_sync)."
            where user_id = ".$db->quote($this->getUserId())."
                and
                flashcard_exchange_last_sync < ".$db->quote($flashcard_exchange_last_sync);
            $db->query($sql);
        }
    }
    
    public function phpinfoAction() {
        phpinfo();
    }
}



?>