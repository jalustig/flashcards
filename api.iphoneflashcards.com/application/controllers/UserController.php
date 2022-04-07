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

class UserController extends Zend_Controller_Action
{

    public function init()
    {
        /* Initialize action controller here */
        if (!isset($_POST['email'])) {
            $_POST['email'] = '';
        }
        if (!isset($_POST['login_key'])) {
            $_POST['login_key'] = '';
        }
        if (!isset($_POST['device_id'])) {
            $_POST['device_id'] = '';
        }

        $internal = $this->getRequest()->getParam('internal', 0);

        // as per: http://stackoverflow.com/questions/1498692/how-do-you-make-zend-framework-not-render-a-view-layout-when-sending-an-ajax-resp/1498701#1498701
        $this->_helper->viewRenderer->setNoRender();

        $is_authenticated = $this->authenticateRequest();
    }

    public function testAction() {
        $mail = new Zend_Mail();
        $mail->addTo('oldemail@gmail.com');
        $mail->setSubject('New FlashCards++ subscriber');
        $mail->setBodyText('This is a test message');
        $mail->setFrom('oldemail@gmail.com', 'FlashCards++');

        //Send it!
        $sent = true;
        try {
            $mail->send();
        } catch (Exception $e){
            $sent = false;
        }
        if ($sent) {
            echo "Email sent";
        }
        die();
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
    
    public function appleReceiptToJson($receipt) {
        $receipt_new = $receipt;
        $receipt_new = str_replace(';', ',', $receipt_new);
        $receipt_new = str_replace('" = "', '":"', $receipt_new);
        $receipt_new = str_replace("\n", '', $receipt_new);
        $receipt_new = str_replace("\t", '', $receipt_new);
        $receipt_new = str_replace('",}', '"}', $receipt_new);
        return $receipt_new;
    }
    
    public function validateReceipt($receipt) {
        $purchase_encoded = base64_encode($receipt);

        $receipt_new = $this->appleReceiptToJson($receipt);
        $receipt_new = Zend_JSON::decode($receipt_new);
        if ($receipt_new['environment'] == "Sandbox") {
            $url = "https://sandbox.itunes.apple.com/verifyReceipt";
        } else {
            $url = "https://buy.itunes.apple.com/verifyReceipt";
        }

        $encodedData = json_encode( Array( 
            'receipt-data' => $purchase_encoded 
        ) );
        

        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, $encodedData);
        $encodedResponse = curl_exec($ch);
        curl_close($ch);
        $response = Zend_JSON::decode($encodedResponse);
        if ($response['status'] != 0) {
            $error = array(
                'is_error' => 1,
                'error_message' => 'Transaction could not be verified with Apple.',
            );
            echo Zend_JSON::encode($error);
            die;
        }
        return $encodedResponse;
    }
    
    public function calculateSubscriptionEndDate($user_id) {
        $db = Zend_Registry::get("db");
        $sql = "select apple_data from flashcards_receipts where user_id = ".$db->quote($user_id)." order by date_purchased asc";
        $receipts = $db->query($sql)->fetchAll();
        $dateEnds = 0;
        foreach ($receipts as $receipt) {
            $data = Zend_JSON::decode($receipt['apple_data']);
            $data = $data['receipt'];
            if ($data['product_id'] == 'com.iphoneflashcards.fcpp.subscription.complementary1month') {
                $length = 60 * 60 * 24 * 30 * 1;
            } else if ($data['product_id'] == 'com.iphoneflashcards.fcpp.subscription.3months') {
                $length = 60 * 60 * 24 * 30 * 3;
            } else if ($data['product_id'] == 'com.iphoneflashcards.fcpp.subscription.6months') {
                $length = 60 * 60 * 24 * 182;
            } else {
                $length = 60 * 60 * 24 * 365;
            }
            $purchaseDate = strtotime($data['purchase_date']);
            if ($dateEnds < $purchaseDate) {
                /* set date ends for the first time: */
                $dateEnds = $purchaseDate;
            }
            $dateEnds += $length;
        }
        return $dateEnds;
    }
    
    public function makeAction() {
            
        $db = Zend_Registry::get("db");
        if (isset($_POST['submit'])) {
            if ($_POST['expiration'] != 'phonepro') {
                die;
            }
            
            $email = $_POST['email'];
            $password = $_POST['password'];
            
            $db->beginTransaction();
            
            $login_key = $this->generateLoginKey($email);
            $data = array(
                'email' => $email,
                'password' => $password,
                'login_key' => $login_key,
                'sync_folder' => UUID::v4(),
            );
            $folder = '/home/iphonefl/sync/'.$data['sync_folder'];
            if (!file_exists($folder)) {
                mkdir($folder);
            }
            $db->insert('flashcards_users', $data);
            $user_id = $db->lastInsertId('user_id');
            
            $apple_data = Zend_JSON::decode('{ "receipt":{"original_purchase_date_pst":"2012-11-20 14:44:54 America/Los_Angeles", "unique_identifier":"0000b00929f8", "original_transaction_id":"1000000058920535", "bvrs":"5.0b3", "transaction_id":"1000000058920535", "quantity":"1", "product_id":"com.iphoneflashcards.fcpp.subscription.3months", "item_id":"578041115", "purchase_date_ms":"1353451494945", "purchase_date":"2012-11-20 22:44:54 Etc/GMT", "original_purchase_date":"2012-11-20 22:44:54 Etc/GMT", "purchase_date_pst":"2012-11-20 14:44:54 America/Los_Angeles", "bid":"com.iphoneFlashCards.FlashCards", "original_purchase_date_ms":"1353451494945"}, "status":0}');
        
            switch ($_POST['type']) {
                default:
                case 3:
                $apple_data['receipt']['product_id'] = 'com.iphoneflashcards.fcpp.subscription.3months';
                break;
                
                case 6:
                $apple_data['receipt']['product_id'] = 'com.iphoneflashcards.fcpp.subscription.6months';
                break;
                
                case 12:
                $apple_data['receipt']['product_id'] = 'com.iphoneflashcards.fcpp.subscription.12months';
                break; 
            }
            $apple_data['receipt']['purchase_date'] = date(DATE_RFC822);

            $data = array(
                'receipt' => '',
                'apple_data' => $apple_data,
                'unique_identifier' => $apple_data['receipt']['unique_identifier'],
                'product_id' => $apple_data['receipt']['product_id'],
                'transaction_id' => $apple_data['receipt']['transaction_id'],
                'user_id' => $user_id,
            );
            $db->insert('flashcards_receipts', $data);
            
            $db->commit();
            
            echo 'User '.htmlspecialchars($email).' created!';
        } else {
            ?>
            <form action="http://api.iphoneflashcards.com/user/make" method="post">
                <b>Email:</b> <input name="email" /><br />
                <b>Password:</b> <input name="password" /><br />
                <b>Type:</b>
                <select name="type">
                    <option value="3">Three Months</option>
                    <option value="6">Six Months</option>
                    <option value="12">Twelve Months</option>
                </select> <br />
                <b>Start Date:</b> <input name="expiration" /><br />
                <br />
                <input type="submit" name="submit" value="Submit" />
            </form>
            <?php
        }
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
        if ($create_new) {
            $data = array(
                'has_subscription' => 0,
                'sync_folder' => UUID::v4(),
                'login_key' => $this->generateLoginKey(UUID::v4()),
            );
            $folder = '/home/iphonefl/sync/'.$data['sync_folder'];
            if (!file_exists($folder)) {
                mkdir($folder);
            }
            $db->insert('flashcards_users', $data);
            $user_id = $db->lastInsertId('user_id');
            $data = array(
                'user_id' => $user_id,
                'device_uuid' => $device_id,
                'ip_address' => $_SERVER['REMOTE_ADDR'],
            );
            $db->insert('flashcards_devices', $data);
            return $user_id;
        }
        return -1;
    }
    
    public function registerAction() {
        /****
         * What happens to people who previously bought items???
         * They previously uploaded the receipts to the server, but weren't logged in.
         * What happened was that the server saved it to a "dummy" user that is identified
         * by the device's non-Apple UUID. When a person tries to register,
         * the server first looks to see if there is already a dummy user with the non-Apple
         * UUID. If there is, then we just update that user rather than make a new one; what
         * we have here then is simply creating a new user out of an existing one.
         * If there already is a user, then we end up making a whole new one.
         ****/
        
        $db = Zend_Registry::get("db");
        
        $user_id = $this->userId('', '', $_POST['device_id']);
        $email = $this->decrypt($this->getRequest()->getParam('email', ''), SECONDARY_KEY_ENCRYPTION_KEY);
        $password = $this->decrypt($this->getRequest()->getParam('password', ''), CALL_KEY_ENCRYPTION_KEY);
        
            $sql = "
            select user_id
            from flashcards_users
            where email = ".$db->quote($email);
            $check = $db->query($sql)->fetchAll();
            if (count($check) > 0) {
                $error = array(
                    'is_error' => 1,
                    'error_message' => 'There already is a user account with this email address.',
                );
                echo Zend_JSON::encode($error);
                die;
            }
        
        // $apple_data = $this->validateReceipt($_POST['transaction_receipt']);
        
        // so now we create the account:
        $login_key = $this->generateLoginKey($email);
        if ($user_id > 0) {
            $sql = 'update flashcards_users
            set
            email = '.$db->quote($email).',
            password = '.$db->quote($password).',
            login_key = '.$db->quote($login_key).'
            where user_id = '.$db->quote($user_id);
            $db->query($sql);
        } else {
            $data = array(
                'email' => $email,
                'password' => $password,
                'login_key' => $login_key,
                'sync_folder' => UUID::v4(),
            );
            $folder = '/home/iphonefl/sync/'.$data['sync_folder'];
            if (!file_exists($folder)) {
                mkdir($folder);
            }
            $db->insert('flashcards_users', $data);
            $user_id = $db->lastInsertId('user_id');
            $data = array(
                'user_id' => $user_id,
                'device_uuid' => $_POST['device_id'],
                'ip_address' => $_SERVER['REMOTE_ADDR'],
            );
            $db->insert('flashcards_devices', $data);
        }
        
        $subscription_ends = $this->calculateSubscriptionEndDate($user_id);
        $response = array(
            'is_error' => 0,
            'email' => $email,
            'login_key' => $login_key,
            'has_subscription' => 1,
            'subscription_ends' => $subscription_ends,
            'number_devices' => 1,
            'sync_created' => false,
        );
        echo Zend_JSON::encode($response);
        die;
    }
    
    public function compAction() {
        $db = Zend_Registry::get("db");
        $user_id = $this->userId($_POST['email'], $_POST['login_key'], $_POST['device_id'], TRUE);
        if ($user_id < 0) {
            $error = array(
                'is_logged_in' => 0,
            );
            echo Zend_JSON::encode($error);
            die;
        }
        
        $receipt_data = '{ "receipt":{"original_purchase_date_pst":"2012-11-20 14:44:54 America/Los_Angeles", "unique_identifier":"0000b00929f8", "original_transaction_id":"1000000058920535", "bvrs":"5.0b3", "transaction_id":"1000000058920535", "quantity":"1", "product_id":"com.iphoneflashcards.fcpp.subscription.complementary1month", "item_id":"578041115", "purchase_date_ms":"1353451494945", "purchase_date":"'. date(DATE_RFC822).'", "original_purchase_date":"2012-11-20 22:44:54 Etc/GMT", "purchase_date_pst":"2012-11-20 14:44:54 America/Los_Angeles", "bid":"com.iphoneFlashCards.FlashCards", "original_purchase_date_ms":"1353451494945"}, "status":0}';
        $apple_data = Zend_JSON::decode($receipt_data);

        $receipt = $apple_data['receipt'];
        
        # check if receipt exists:
            $data = array(
                'receipt' => $receipt_data,
                'apple_data' => $receipt_data,
                'unique_identifier' => $receipt['unique_identifier'],
                'product_id' => $receipt['product_id'],
                'transaction_id' => $receipt['transaction_id'],
                'user_id' => $user_id,
            );
            $db->insert('flashcards_receipts', $data);
        
        $data = array(
            'is_logged_in' => 1,
            'user_id' => $user_id,
        );
        echo Zend_JSON::encode($data);
        
        die;
    }
    
    public function receiptAction() {
        $db = Zend_Registry::get("db");
        $user_id = $this->userId($_POST['email'], $_POST['login_key'], $_POST['device_id'], TRUE);
        if ($user_id < 0) {
            $error = array(
                'is_logged_in' => 0,
            );
            echo Zend_JSON::encode($error);
            die;
        }
        
        $apple_data = $this->validateReceipt($_POST['transaction_receipt']);
        $json = Zend_JSON::decode($apple_data);
        $receipt = $json['receipt'];
        
        # check if receipt exists:
            $sql = 'select receipt_id from flashcards_receipts where unique_identifier = '.$db->quote($receipt['unique_identifier']);
            $check = $db->query($sql)->fetchAll();
            if (count($check) == 0) {
                $data = array(
                    'receipt' => $_POST['transaction_receipt'],
                    'apple_data' => $apple_data,
                    'unique_identifier' => $receipt['unique_identifier'],
                    'product_id' => $receipt['product_id'],
                    'transaction_id' => $receipt['transaction_id'],
                    'user_id' => $user_id,
                );
                $db->insert('flashcards_receipts', $data);
            }
        
        $data = array(
            'is_logged_in' => 1,
        );
        echo Zend_JSON::encode($data);
        
        die;
    }
    
    public function loginAction() {
        $db = Zend_Registry::get("db");
        $email = $this->decrypt($this->getRequest()->getParam('email', ''), SECONDARY_KEY_ENCRYPTION_KEY);
        $password = $this->decrypt($this->getRequest()->getParam('password', ''), CALL_KEY_ENCRYPTION_KEY);
        $userSql = "
        select
            flashcards_users.user_id,
            flashcards_users.email,
            subscription_ends,
            login_key,
            has_subscription,
            subscription_ends,
            sync_created,
            sync_last_sync,
            sync_last_upload_database,
            sync_last_upload_database_prompt,
            sync_last_upload_database_wait,
            quizlet_last_sync,
            flashcard_exchange_last_sync,
            sync_currently_uploading,
            count(flashcards_devices.device_uuid) as number_devices
        from
            flashcards_users left join flashcards_devices on flashcards_users.user_id = flashcards_devices.user_id 
        where
            email = ".$db->quote($email)." and
            password = ".$db->quote($password)."
        group by
            flashcards_users.user_id,
            flashcards_users.email,
            flashcards_users.subscription_ends,
            flashcards_users.login_key,
            flashcards_users.has_subscription,
            flashcards_users.sync_created,
            flashcards_users.sync_last_sync,
            flashcards_users.sync_last_upload_database,
            flashcards_users.sync_last_upload_database_prompt,
            flashcards_users.sync_last_upload_database_wait,
            flashcards_users.quizlet_last_sync,
            flashcards_users.flashcard_exchange_last_sync,
            flashcards_users.sync_currently_uploading";
        $user = $db->query($userSql)->fetchAll();
        if (count($user) == 0) {
            $error = array(
                'is_error' => 1,
                'error_message' => 'Username or password incorrect.',
            );
            echo Zend_JSON::encode($error);
            die;
        }
        
        $user = $user[0];
        $user_id = $user['user_id'];
        
        $sql = "select device_id from flashcards_devices where user_id = ".$db->quote($user_id)." and device_uuid = ".$db->quote($_POST['device_id']);
        $check = $db->query($sql)->fetchAll();
        $device_found = FALSE;
        if (count($check) > 0) {
            /* the user's device was previously associated with the account but wasn't logged out properly */
            $device_found = TRUE;
        }
        
        if ($user['number_devices'] >= 5 && !$device_found) {
            $error = array(
                'is_error' => 1,
                'error_message' => 'This account is already logged in on the maximum of five mobile devices.',
            );
            echo Zend_JSON::encode($error);
            die;
        }
        
        if (!$device_found) {
            $data = array(
                'user_id' => $user['user_id'],
                'device_uuid' => $_POST['device_id'],
                'ip_address' => $_SERVER['REMOTE_ADDR'],
            );
            $db->insert('flashcards_devices', $data);
        }
        
        $subscription_ends = $this->calculateSubscriptionEndDate($user['user_id']);

        $user = $db->query($userSql)->fetchAll();
        $user = $user[0];
        $response = array(
            'is_error' => 0,
            'email' => $user['email'],
            'has_subscription' => $user['has_subscription'],
            'subscription_ends' => $subscription_ends,
            'login_key' => $user['login_key'],
            'number_devices' => $user['number_devices'],
            'sync_created' => $user['sync_created'],
            'sync_last_sync' => $user['sync_last_sync'],
            'sync_last_upload_database' => $user['sync_last_upload_database'],
            'sync_last_upload_database_prompt' => $user['sync_last_upload_database_prompt'],
            'sync_last_upload_database_wait' => $user['sync_last_upload_database_wait'],
            'quizlet_last_sync' => $user['quizlet_last_sync'],
            'flashcard_exchange_last_sync' => $user['flashcard_exchange_last_sync'],
            'sync_currently_uploading' => $user['sync_currently_uploading'],
        );
        echo Zend_JSON::encode($response);
        die;
    }
    
    public function logoutAction() {
        $db = Zend_Registry::get("db");
        $sql = "
        delete from flashcards_devices
        where device_uuid = ".$db->quote($_POST['device_id']);
        $db->query($sql);
        die;
    }
    
    public function logoutallAction() {
        $db = Zend_Registry::get("db");
        $user_id = $this->userId($_POST['email'], $_POST['login_key'], $_POST['device_id'], FALSE);
        if ($user_id > 0) {
            $sql = "delete from flashcards_devices where user_id = ".$db->quote($user_id);
            $db->query($sql);
        }
        die;
    }
    
    public function checkAction() {
        $db = Zend_Registry::get("db");
        $response = '';
        $call = $this->decrypt($this->getRequest()->getParam('call', ''), CALL_KEY_ENCRYPTION_KEY);
        $response = md5($call.$call);
        $user_id = $this->userId($_POST['email'], $_POST['login_key'], @$_POST['device_id']);
        $sql = "
        select
            flashcards_users.user_id,
            flashcards_users.email,
            subscription_ends,
            login_key,
            has_subscription,
            subscription_ends,
            sync_created,
            sync_last_sync,
            sync_last_upload_database,
            sync_last_upload_database_prompt,
            sync_last_upload_database_wait,
            quizlet_last_sync,
            flashcard_exchange_last_sync,
            sync_currently_uploading,
            count(flashcards_devices.device_uuid) as number_devices
        from
            flashcards_users left join flashcards_devices on flashcards_users.user_id = flashcards_devices.user_id 
        where
            flashcards_users.user_id = ".$db->quote($user_id)."
        group by
            flashcards_users.user_id,
            flashcards_users.email,
            flashcards_users.subscription_ends,
            flashcards_users.login_key,
            flashcards_users.has_subscription,
            flashcards_users.sync_created,
            flashcards_users.sync_last_sync,
            flashcards_users.sync_last_upload_database,
            flashcards_users.sync_last_upload_database_prompt,
            flashcards_users.sync_last_upload_database_wait,
            flashcards_users.quizlet_last_sync,
            flashcards_users.flashcard_exchange_last_sync,
            flashcards_users.sync_currently_uploading";
        $user = $db->query($sql)->fetchAll();
        if (count($user) == 0) {
            $error = array(
                'is_logged_in' => 0,
                'response' => $response,
            );
            echo Zend_JSON::encode($error);
            die;
        }
        
        $user = $user[0];

        if (isset($_REQUEST['device_id'])) {
            $sql = "update flashcards_devices set ip_address = ".$db->quote($_SERVER['REMOTE_ADDR'])." where device_uuid = ".$db->quote($_REQUEST['device_id']);
            $db->query($sql);
        }

        $subscription_ends = $this->calculateSubscriptionEndDate($user['user_id']);
        
        $return = array(
            'is_logged_in' => 1,
            'email' => $user['email'],
            'has_subscription' => $user['has_subscription'],
            'subscription_ends' => $subscription_ends,
            'number_devices' => $user['number_devices'],
            'response' => $response,
            'sync_created' => $user['sync_created'],
            'sync_last_sync' => $user['sync_last_sync'],
            'sync_last_upload_database' => $user['sync_last_upload_database'],
            'sync_last_upload_database_prompt' => $user['sync_last_upload_database_prompt'],
            'sync_last_upload_database_wait' => $user['sync_last_upload_database_wait'],
                'quizlet_last_sync' => $user['quizlet_last_sync'],
            'flashcard_exchange_last_sync' => $user['flashcard_exchange_last_sync'],
            'sync_currently_uploading' => $user['sync_currently_uploading'],
        );
        echo Zend_JSON::encode($return);
        
        die;
    }
    
    public function subscriptionendsAction() {
        date_default_timezone_set('UTC');
        $endDate = $this->calculateSubscriptionEndDate($_GET['user_id']);
        echo $endDate;
        echo "<hr>";
        echo date(DATE_RFC822, $endDate);
        die;
    }
    
    public function setupAction() {
        $db = Zend_Registry::get("db");
        $sql = "select user_id, sync_folder from flashcards_users";
        $results = $db->query($sql)->fetchAll();
        foreach ($results as $u) {
            $folder = '/home/iphonefl/sync/'.$u['sync_folder'];
            if (!file_exists($folder)) {
                mkdir($folder);
                echo "($u[user_id]) - Creating $folder<br>";
            }
        }
        die;
    }
    
    public function listreceiptsAction() {
        $db = Zend_Registry::get("db");
        $sql = "select receipt_id, user_id, receipt, apple_data, date_purchased from flashcards_receipts order by user_id";
        $receipts = $db->query($sql)->fetchAll();
        ?><table border="2"><tr><th>Receipt ID</th><th>User ID</th><th>Date</th><th width="400">Apple</th></tr>
            <?php
            foreach ($receipts as $r) {
                ?>
                <tr>
                    <td><?php echo htmlspecialchars($r['receipt_id']); ?></td>
                    <td><?php echo htmlspecialchars($r['user_id']); ?></td>
                    <td><?php
                     echo htmlspecialchars($r['apple_data']); ?></td>
                    <td><?php echo htmlspecialchars($r['date_purchased']); ?></td>
                </tr>
                <?php
            }
            ?>
        </table>
        <?php
        die;
    }
    
    public function listusersAction() {
        $db = Zend_Registry::get("db");
        
        $sql = "select count(distinct device_uuid) from offline_tts_devices";
        // $count = $db->query($sql)->fetchAll();
        // echo "# Devices: ".$count[0]['count']."<br>";
        
        $sql = "select count(*) from flashcards_users";
        $count = $db->query($sql)->fetchAll();
        echo "# Users: ".$count[0]['count']."<br>";

        $sql = "select count(*) from flashcards_users where sync_created = '1'";
        $count = $db->query($sql)->fetchAll();
        echo "# Syncing: ".$count[0]['count']."<br>";
        echo "<hr>";
        $sql =
        "select flashcards_users.user_id, flashcards_users.email, flashcards_users.date_added, (select count(*) from flashcards_devices where flashcards_devices.user_id = flashcards_users.user_id) as num_devices, sync_created, sync_folder
        from flashcards_users
        order by user_id desc";
        $users = $db->query($sql)->fetchAll();
        ?>
        <table border="2">
            <tr><th>User ID</th><th>Email</th><th># Devices</th><th>Syncing</th><th>Date Added</th><th>Products</th><th>Sync Folder</th></tr>
            <?php
        $totalMonthlyRevenue = 0;
        $totalRevenue = 0;
        foreach ($users as $u) {
            ?>
            <tr>
                <td><?php echo htmlspecialchars($u['user_id']); ?></td>
                <td><?php echo htmlspecialchars($u['email']); ?></td>
                <td><?php echo htmlspecialchars($u['num_devices']); ?></td>
                <td><?php echo htmlspecialchars($u['sync_created']); ?></td>
                <td><?php echo htmlspecialchars($u['date_added']); ?></td>
                <td>
                    <?php
                    $sql = "select product_id from flashcards_receipts where user_id = ".$db->quote($u['user_id']);
                $products = $db->query($sql)->fetchAll();
                $found = 0;
                foreach ($products as $p) {
                    echo htmlspecialchars($p['product_id'].'; ');
                    if (!$found) {
                        if ($p['product_id'] == 'com.iphoneflashcards.fcpp.subscription.3months') {
                            $totalMonthlyRevenue += (3*0.7)/3;
                        } else if ($p['product_id'] == 'com.iphoneflashcards.fcpp.subscription.6months') {
                            $totalMonthlyRevenue += (6*0.7)/6;
                        } else if ($p['product_id'] == 'com.iphoneflashcards.fcpp.subscription.12months') {
                            $totalMonthlyRevenue += (10*0.7)/12;
                        }
                        $found = 1;
                    }
                    if ($p['product_id'] == 'com.iphoneflashcards.fcpp.subscription.3months') {
                        $totalRevenue += (3*0.7);
                    } else if ($p['product_id'] == 'com.iphoneflashcards.fcpp.subscription.6months') {
                        $totalRevenue += (6*0.7);
                    } else if ($p['product_id'] == 'com.iphoneflashcards.fcpp.subscription.12months') {
                        $totalRevenue += (10*0.7);
                    }
                }
                    ?>
                </td>
                <td><?php 
                if ($u['sync_created']) {
                    echo htmlspecialchars($u['sync_folder']);
                }
                ?></td>
            </tr>
            <?php
        }
        echo '</table>';
        echo "<hr>";
        echo '<big><b>Estimated Amortized Monthly Subscription Revenue: $'.round($totalMonthlyRevenue, 2).'</b></big><br />';
        echo '<big><b>Total Subscription Revenue: $'.round($totalRevenue, 2).'</b></big><br />';
        die;
    }
    
}



