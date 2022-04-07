<?php

include 'Zend/Http/Client.php';
include 'Zend/Dom/Query.php';
include 'Zend/Json.php';
require_once 'PHPExcel/PHPExcel.php';

function usortByArrayKey(&$array, $key, $asc=SORT_ASC) { 
    $sort_flags = array(SORT_ASC, SORT_DESC); 
    if(!in_array($asc, $sort_flags)) throw new InvalidArgumentException('sort flag only accepts SORT_ASC or SORT_DESC'); 
    $cmp = function(array $a, array $b) use ($key, $asc, $sort_flags) { 
        if(!is_array($key)) { //just one key and sort direction 
            if(!isset($a[$key]) || !isset($b[$key])) { 
                throw new Exception('attempting to sort on non-existent keys'); 
            } 
            if($a[$key] == $b[$key]) return 0; 
            return ($asc==SORT_ASC xor $a[$key] < $b[$key]) ? 1 : -1; 
        } else { //using multiple keys for sort and sub-sort 
            foreach($key as $sub_key => $sub_asc) { 
                //array can come as 'sort_key'=>SORT_ASC|SORT_DESC or just 'sort_key', so need to detect which 
                if(!in_array($sub_asc, $sort_flags)) { $sub_key = $sub_asc; $sub_asc = $asc; } 
                //just like above, except 'continue' in place of return 0 
                if(!isset($a[$sub_key]) || !isset($b[$sub_key])) { 
                    throw new Exception('attempting to sort on non-existent keys'); 
                } 
                if($a[$sub_key] == $b[$sub_key]) continue; 
                return ($sub_asc==SORT_ASC xor $a[$sub_key] < $b[$sub_key]) ? 1 : -1; 
            } 
            return 0; 
        } 
    }; 
    usort($array, $cmp); 
}; 

class TranslateController extends Zend_Controller_Action
{
    public $db;
    
    public function init()
    {
        /* Initialize action controller here */
        // echo "<base href='http://api.iphoneflashcards.com/bookfinder/'>";
    }

    public function indexAction() {
        
        $url = "http://dict.tu-chemnitz.de/dings.cgi?lang=en&service=deen&opterrors=0&optpro=0&query=".urlencode($_GET['word'])."&iservice=&comment=&email=";
        $client = new Zend_Http_Client($url);
        $client->setMethod(Zend_Http_Client::GET);
        $response = $client->request();

        $html = $response->getBody();
        $dom = new Zend_Dom_Query($html);

        // <dl><dt>Similar words:</dt><dd><a href="/deutsch-englisch/Klang.html">Klang</a>, <a href="/deutsch-englisch/klang.html">klang</a>, <a href="/deutsch-englisch/Klinge.html">Klinge</a>, <a href="/deutsch-englisch/klingt.html">klingt</a></dd></dl>
        preg_match_all("/<dl><dt>Similar words:<\/dt>(<dd>(<a href=\"\/deutsch-englisch\/.*?\">(.*?)<\/a>\,? ?)*?<\/dd>)<\/dl>/i", utf8_encode($html), $matches);
        if (count($matches[0]) > 0) {
            $dd = $matches[1][0];
            str_replace("<dd>", "", $dd);
            str_replace("</dd>", "", $dd);
            $matches = explode(",", $dd);
            foreach ($matches as $k => $v) {
                $matches[$k] = strip_tags($v);
            }
            $similar_words = $matches;
        } else {
            $similar_words = array();
        }
        
        $trs = $dom->query('//table[@id="result"]/tbody/tr');
        $translations = array();
        
        foreach ($trs as $tr) {
            $resultsDom = new Zend_Dom_Query($this->getHtml($tr));
            $xlation = array();
            #echo $this->getHtml($tr);
            $class = $tr->getAttribute("class");
            #echo $resultsDom->query('//td[2]')->current()->nodeValue."<br>";
            #echo $class."<br>";
            $class = explode(" ", $class);
            #var_dump($class);
            #echo "<hr>";
            $xlation['group'] = $class[0] == 's1' ? 0 : 1;
            $xlation['indented'] = in_array("c", $class) ? 1 : 0;
            $xlation['foreign'] = $resultsDom->query('//td[2]')->current()->nodeValue;
            $xlation['english'] = $resultsDom->query('//td[3]')->current()->nodeValue;
            $xlation['foreign'] = trim($xlation['foreign']);
            $xlation['foreign'] = str_replace("{", "(", $xlation['foreign']);
            $xlation['foreign'] = str_replace("}", ")", $xlation['foreign']);
            $xlation['english'] = trim($xlation['english']);
            $xlation['english'] = str_replace("{", "(", $xlation['english']);
            $xlation['english'] = str_replace("}", ")", $xlation['english']);
            $translations[] = $xlation;
        }
        
        header('Content-Type:text/html; charset=UTF-8');
        echo Zend_Json::encode(array('similar_words' => $similar_words, 'translations' => $translations));
        
        die;
    }
    
    public function excelAction() {
        
        if (!isset($_FILES['spreadsheet'])) {
            $e = new FlashcardsServer_Exception('No file uploaded');
            die($e->toJson(0));
        }
        $inputFileName = $_FILES['spreadsheet']['tmp_name'];

    #    echo file_get_contents($inputFileName); die;

        $objReader = PHPExcel_IOFactory::createReader('CSV');
        $objPHPExcel = $objReader->load($inputFileName);
        
        $maxALength = 0;
        $maxBLength = 0;
        foreach ($objPHPExcel->setActiveSheetIndex(0)->getRowIterator() as $row)
        {
            $cellIterator = $row->getCellIterator();
            $cellIterator->setIterateOnlyExistingCells(false);
            $i = 0;
            foreach ($cellIterator as $cell)
            {
                $i++;
                if (is_null($cell))
                {
                    continue;
                }
                $length = strlen($cell->getCalculatedValue());
                if ($i == 1) {
                    // column A;
                    if ($length > $maxALength) {
                        $maxALength = $length;
                    }
                } else {
                    // column B
                    if ($length > $maxBLength) {
                        $maxBLength = $length;
                    }
                }
            }
        }
        
        #echo "$maxALength - $maxBLength";
        #die;
        
        $objPHPExcel->getActiveSheet()->getColumnDimension('A')->setWidth($maxALength);
        $objPHPExcel->getActiveSheet()->getColumnDimension('B')->setWidth($maxBLength);

        
    #    var_dump($objPHPExcel); die;
        $objWriter = PHPExcel_IOFactory::createWriter($objPHPExcel, "Excel2007");        $outputFileName = tempnam('/tmp', 'csv');
        $objWriter->save($outputFileName);
        echo file_get_contents($outputFileName);
        die;
    }
    
    public function saveAction() {
        $db = Zend_Registry::get("db");
        $db->beginTransaction();
        $data = array(
            'book_name' => $_POST['book_name'],
            'book_url' => $_POST['url'],
            'book_url2' => $_POST['url2'],
            );
        $db->insert('books', $data);
        $this->saveBookData($db->lastInsertId('books', 'book_id'), $_POST['url']); 
        $this->saveBookData($db->lastInsertId('books', 'book_id'), $_POST['url2']); 
        $db->commit();
        echo '<b>This book has been saved.</b>';
        $this->indexAction();
        die;
    }
    
    public function deleteAction() {
        $db = Zend_Registry::get("db");
        $sql = 'delete from books where book_id = '.$db->quote($_GET['id']);
        $db->query($sql);
        echo '<b>Book deleted!</b><hr>';
        $this->listAction();
        die;
    }
    
    public function detailsAction() {
        $db = Zend_Registry::get("db");
        
        $sql = "select book_name from books where book_id = ".$db->quote($_GET['id']);
        $book = $db->query($sql)->fetchAll();
        $book = $book[0];
        
        ?><h1><?php echo $book['book_name']; ?></h1>
        <table border="0">
            <tr>
                <th>Hardcover</th><th>Softcover</th>
            </tr>
            <tr>
        <?php
        foreach (array('H', 'S') as $binding) {
            $group = "cast(time_found - interval '7 hours' as DATE)";
            $sql = "select min(price) as min_price, avg(price) as avg_price, ".$group." as date_found, count(*) as num_found from books_found where books_found.book_id = ".$db->quote($_GET['id'])." and books_found.binding = ".$db->quote($binding)." group by ".$group." order by ".$group." desc";
            $results = $db->query($sql)->fetchAll();
            ?>
            <td>
            <table border="2">
                <tr><th>Date</th><th>Min</th><th>Avg Price</th><th>#</th></tr>
            <?php
                foreach ($results as $result) {
                    ?>
                    <tr>
                        <td><?php echo $result['date_found']; ?></td>
                        <td><?php echo '$'.$result['min_price']; ?></td>
                        <td><?php echo '$'.round($result['avg_price'], 2); ?></td>
                        <td><?php echo $result['num_found']; ?></td>
                    </tr>
                    <?php
                }
            ?>
            </table>
            </td>
            <?php
        }
        ?>
            </tr>
        </table>
        <?php
        die;
    }
    
    /*
    1. New / like new
    great condition / unread / former library / ex-library / like new / brand new / new book -> new
    
    2. Near Fine / Very good
    near fine / NF -> fine
    Very good -> good
    
    3. Good
    Very good -> good
    
    4. Fair
    fair
    minor highlighting
    
    fair
    clean
    unmarked
    
    */
    
    public function refreshAction() {
        $db = Zend_Registry::get("db");
        $db->beginTransaction();
        $sql = "select book_id, book_url, book_url2 from books";
        $results = $db->query($sql)->fetchAll();
        foreach ($results as $result) {
            $this->saveBookData($result['book_id'], $result['book_url']);
            $this->saveBookData($result['book_id'], $result['book_url2']);
        }
        $db->commit();
        $this->listAction();
        die;
    }
    public function listAction() {
        $db = Zend_Registry::get("db");
        $group = "cast(time_found - interval '7 hours' as DATE)";
        $sql = "select books.book_url, books.book_url2, books.book_id, books.book_name, min(price) as min_price, avg(price) as avg_price, binding, ".$group." as date_found from books_found, books where books_found.book_id = books.book_id and ".$group." = (select max(".$group.") from books_found as bf2 where bf2.book_id = books_found.book_id) and (books_found.binding = 'H' or books_found.binding = 'S') group by books.book_id, books.book_name, ".$group.", binding, book_url, book_url2 order by books.book_name";
        $results = $db->query($sql)->fetchAll();
        ?>
        <table border="2">
            <tr>
                <th>Book Name</th>
                <th>&nbsp;</th>
                <th>Min Price</th>
                <th>Avg Price</th>
                <th>Last Checked</th>
                <th>&nbsp;</th>
            </tr>
            <?php
            $prev_id = 0;
            $i = 0;
            foreach ($results as $k => $result) {
                $rowspan = 1;
                if ($prev_id != $result['book_id']) {
                    ?>
                    <tr><td<?php
                     if (isset($results[$k+1]) && $results[$k+1]['book_id'] == $result['book_id']) { 
                         $rowspan = 2;
                         echo ' rowspan="2"';
                     }
                     ?>><?php echo htmlspecialchars($result['book_name']); ?><br /><a href="details/?id=<?php echo $result['book_id']; ?>">History</a>
                     - <a target="_blank" href="<?php echo $result['book_url']; ?>">Search</a>
                     <?php
                     if (strlen($result['book_url2']) > 0) {
                         ?>- <a target="_blank" href="<?php echo $result['book_url2']; ?>">Search 2</a><?php
                     }
                     ?>
                     </td>
                    <?php
                } else { echo "<tr>"; }
                ?>
                <td><?php echo $result['binding']; ?></td>
                <td><?php echo '$'.$result['min_price']; ?></td>
                <td><?php echo '$'.round($result['avg_price'], 2); ?></td>
                <td><?php echo $result['date_found']; ?></td>
                <?php if ($prev_id != $result['book_id']) {
                    ?><td rowspan="<?php echo $rowspan; ?>"><a href="delete/?id=<?php echo $result['book_id']; ?>">Delete</a></td><?php
                } ?>
                </tr><?php
                $prev_id = $result['book_id'];
                
            }
            ?>
        </table>
        <?php
        die;
    }

    public function bufferAction() {
        $url = $_GET['url'].'?';
        if (empty($_GET['referer'])) {
            $_GET['referer'] = 'http://www.bookfinder.com/';
        }
        foreach ($_GET as $key => $value) {
            if ($key == 'url') { continue; }
            if ($key == 'referer') { continue; }
            $url .= $key.'='.urlencode($value).'&';
        }
        # echo $url; die;
        $client = new Zend_Http_Client($url);
        $client->setMethod(Zend_Http_Client::GET);
        $client->setHeaders('Referer', $_GET['referer']);
        $client->setHeaders("User-Agent", "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.0.7) Gecko/2009021910 Firefox/3.0.7 (.NET CLR 3.5.30729)");
        $response = $client->request()->getBody();
        $response = str_replace('if (top != self)', 'if (0)', $response);
        
        //$response = preg_replace('/<a href="(.*?)"/i', '<a href="http://api.iphoneflashcards.com/bookfinder/buffer/?url=$1', $response);

        $host = 'api.iphoneflashcards.com/bookfinder/buffer/';
        $callback = function ($match) use ($host) {
            return '<a href="http://'.$host.'?url='.urlencode($match[1]).'&referer='.urlencode($_GET['referer']).'"';
        };
        $response = preg_replace_callback('/<a href="(.*?)"/i', $callback, $response);
        $response = str_replace('<form action="http://www.bookfinder.com/search/" ', '<form action="http://api.iphoneflashcards.com/bookfinder/buffer/" ', $response); 
        $response = str_replace('class="search-form" >', 'class="search-form" ><input type="hidden" name="url" value="http://www.bookfinder.com/search/" />', $response);
        $response = str_replace('class="search-form" >', 'class="search-form" ><input type="hidden" name="referer" value="'.$_GET['referer'].'" />', $response);
        echo $response;
        die;
    }

    public function findAction()
    {
        // action body
        $db = Zend_Registry::get("db");
        
        ?>
        <form action="search/" method="post">
        <table>
        <tr>
            <th>BF URL</th>
            <td><input name="url" type="text" width="100" /></td>
        </tr>
        <tr>
            <th>&nbsp;</th>
            <td><input type="submit" name="submit" value="Search!" /></td>
        </tr>
        </table>
        </form>
        <?php

        die;        
    }

    public function getBindingFromDescription($_description) {
        $_binding = '';
        if (strstr(strtolower($_description), 'hardcover') !== FALSE) {
            $_binding = 'H';
        } else if (strstr(strtolower($_description), 'paperback') !== FALSE) {
            $_binding = 'S';
        } else if (strstr(strtolower($_description), 'softcover') !== FALSE) {
            $_binding = 'S';
        } else if (strstr(strtolower($_description), 'soft cover') !== FALSE) {
            $_binding = 'S';
        } else if (strstr(strtolower($_description), 'hard cover') !== FALSE) {
            $_binding = 'H';
        }
        return $_binding;
    }

    public function searchBookfinder($url) {

        $client = new Zend_Http_Client($url);
        $client->setMethod(Zend_Http_Client::GET);
        $response = $client->request();

        $dom = new Zend_Dom_Query($response->getBody());
        $resultsHeading = $dom->query('//h3[@class="results-section-heading"]');
        
        $books = array();
        
        foreach ($resultsHeading as $heading) {
            $headingText = $heading->nodeValue;
            $used = '';
            if (strstr($headingText, 'Used books:') !== FALSE) {
                // it's used books.
                $used = 1;
            #    echo "USED!!!<br>";
            } else if (strstr($headingText, 'New books:') !== FALSE) {
                // it's new books.
                $used = 0;
            #    echo "NEW!!!<br>";
            } else {
                continue;
            }
            $table = $heading->nextSibling->nextSibling;
            #echo $this->getHtml($table);
            #echo "<hr>";
            $resultsDom = new Zend_Dom_Query($this->getHtml($table));
            $result = $resultsDom->query('//tr[@class="results-table-first-LogoRow"]')->current();
            do {
                $resultDom = new Zend_Dom_Query($this->getHtml($result));
                
                $_description = $resultDom->query('//td[3]')->current()->nodeValue;

                $_price = $resultDom->query('//span[@class="results-price"]');
                $_binding = $this->getBindingFromDescription($_description);

                if (count($_price) == 0) {
                    $result = $result->nextSibling;
                    continue;
                } else {
                    $_price = $_price->current()->nodeValue;
                    $_price = str_replace('$', '', $_price);
                    $_price = str_replace(',', '', $_price);
            #        echo "$_price - $_binding<br>";
                }                
        
                $book = array();
                $book['description'] = $_description;
    #            $book['condition'] = $_condition;
                $book['price_total'] = $_price;
                $book['binding'] = $_binding;
                $book['used'] = $used;
                
                $books[] = $book;            
                $result = $result->nextSibling;
            } while ($result->getAttribute("class") == "results-table-LogoRow");
        }

        return $books;
    }

    public function searchAbebooks($author, $title, $book_condition, $book_format) {
        if ($book_format == 'paperback') {
            $book_format = 0;
        } else if ($book_format == 'hardcover') {
            $book_format = 'h';
        } else {
            $book_format = 's';
        }
        
        // Abebooks:
        $url = 'http://www.abebooks.com/servlet/SearchResults?'.
                'an='.urlencode($author).'&'.
                'bi='.$book_format.'&'.
                'bx=off&ds=50&recentlyadded=all&sortby=17&sts=t&'.
                'tn='.urlencode($title).'&'.
                'x=69&y=0';
        $client = new Zend_Http_Client($url);
        $client->setMethod(Zend_Http_Client::GET);
        $response = $client->request();

        $html = $response->getBody();

        $dom = new Zend_Dom_Query($html);
        $results = $dom->query('//table[@class="result"]');
        
        $books = array();

        if (count($results) > 0) {
            foreach ($results as $result) {
                $html = $this->getHTML($result);
                $resultDom = new Zend_Dom_Query($html);
                $_titleNode = $resultDom->query('//td[@class="result-details"]//a')->current();
                $_title = $_titleNode->nodeValue;
                $_url = 'http://www.abebooks.com'.$_titleNode->getAttributeNode('href')->nodeValue;
    
                $_author = $resultDom->query('//div[@class="result-annotation"]')->current()->previousSibling->nodeValue;
    
                $_bookseller = $resultDom->query('//div[@class="result-bookseller"]//a[1]')->current()->nodeValue;
                $_bookseller_location = $resultDom->query('//span[@class="scndInfo"]')->current()->nodeValue;
                $_bookseller_location = substr($_bookseller_location, 1, strlen($_bookseller_location)-2);
                
                $_isbn_url = $resultDom->query('//td[@class="result-details"]/a');
                if (count($_isbn_url) > 0) {
                    $_isbn_url = $_isbn_url->current()->getAttributeNode('href')->nodeValue;
                    $parts = explode('/', $_isbn_url);
                    if (count($parts) < 4) {
                        echo $html."<hr>";
                        echo $_isbn_url;
                        var_dump($parts); die;
                    } else {
                        $_isbn = $parts[3];
                    }
                } else {
                    $_isbn = '';
                }
                        
                $_description = $resultDom->query('//div[@class="result-description"]/p')->current()->nodeValue;
                $_description = str_replace('Book Description: ', '', $_description);
                
                preg_match('/Book Condition: (.*?)\./i', $_description, $matches);
                if (isset($matches[1])) {
                    $_condition = $matches[1];
                } else {
                    $_condition = '';
                }
                        
                $_priceBook = $resultDom->query('//div[@class="result-price"]//span[@class="price"]')->current()->nodeValue;
                $_priceBook = str_replace('US$ ', '', $_priceBook);
                $_priceBook = str_replace('US $ ', '', $_priceBook);
                
                $_priceShip = $resultDom->query('//div[@class="result-shippingPrice"]//span[@class="price"]');
                if (count($_priceShip) > 0) {
                    $_priceShip = $_priceShip->current()->nodeValue;
                    $_priceShip = str_replace('US$ ', '', $_priceShip);
                    $_priceShip = str_replace('US $ ', '', $_priceShip);
                } else {
                    $_priceShip = 0;
                }
                
                $_binding = $this->getBindingFromDescription($_description);
    
                /*
                $clientBook = new Zend_Http_Client($_url);
                $clientBook->setMethod(Zend_Http_Client::GET);
                $responseBook = $clientBook->request();
                $html = $responseBook->getBody();
                $html = str_replace('src="/', 'src="http://www.abebooks.com/', $html);
                $html = str_replace('href="/', 'href="http://www.abebooks.com/', $html);
    
                $bookDom = new Zend_Dom_Query($responseBook->getBody());
    
                $_author = $bookDom->query('//h2[@id="book-author"]')->current()->nodeValue;
    
                $_bookseller = $bookDom->query('//a[@id="a-bookseller-storefront"]')->current()->nodeValue;
                $_booksellerHtml = $bookDom->query('//div[@id="aboutTheBookseller"]//div[@class="contentCol"]/h3')->current()->nodeValue;
                preg_match('/Address: (.*?)$/i', $_booksellerHtml, $matches);
                $_bookseller_location = $matches[1];
                
                $_isbn = $bookDom->query('//h2[@class="isbn"]/a[2]')->current()->nodeValue;
                
                $_description = $bookDom->query('//p[@id="Description-heading"]')->current()->nodeValue;
                
                $_condition = $bookDom->query('//span[@id="biblio-bookcondition"]')->current();
                if ($_condition) {
                    $_condition = $_condition->nodeValue;
                } else {
                    $_condition = '';
                }
                        
                $_priceBook = $bookDom->query('//span[@id="book-price"]')->current()->nodeValue;
                $_priceBook = str_replace('US$ ', '', $_priceBook);
                $_priceBook = str_replace('US $ ', '', $_priceBook);
                
                $_priceShip = $bookDom->query('//span[@class="shipping"]')->current()->nodeValue;
                $_priceShip = str_replace('US$ ', '', $_priceShip);
                $_priceShip = str_replace('US $ ', '', $_priceShip);
                
                $_binding = strtolower($bookDom->query('//span[@id="biblio-binding"]')->current()->nodeValue);
                switch ($_binding) {
                    case 'hardcover':     $_binding = 'H'; break;
                    case 'softcover':     $_binding = 'S'; break;
                    default:             $_binding = ''; break;
                }
                */
                
                $book = array();
                $book['title'] = $_title;
                $book['author'] = $_author;
                $book['description'] = $_description;
                $book['condition'] = $_condition;
                $book['bookseller'] = $_bookseller;
                $book['bookseller_location'] = $_bookseller_location;
                $book['price_book'] = $_priceBook;
                $book['price_shipping'] = $_priceShip;
                $book['price_total'] = $_priceBook + $_priceShip;
                $book['isbn'] = $_isbn;
                $book['binding'] = $_binding;
                $book['url'] = $_url;
                $book['source'] = 'AbeBooks';
                
                $books[] = $book;            
            }
        } else {
            $results = $dom->query('//div[@class="result"]');
            foreach ($results as $result) {
                $html = $this->getHTML($result);
                $resultDom = new Zend_Dom_Query($html);
                $_titleNode = $resultDom->query('//h2[@class="title"]')->current();
                $_title = $_titleNode->nodeValue;
                $_url = 'http://www.abebooks.com'.$_titleNode->getAttributeNode('href');
    
                $_author = $resultDom->query('//div[@class="author"]')->current()->nodeValue;
    
                $_bookseller = $resultDom->query('//div[@class="bookseller"]//a')->current()->nodeValue;
                $_bookseller_location = $resultDom->query('//div[@class="bookseller-location"]')->current()->nodeValue;
                $_bookseller_location = substr($_bookseller_location, 1, strlen($_bookseller_location)-2);
                
                $_isbn_url = $resultDom->query('//div[@class="isbn"]/a');
                if (count($_isbn_url) > 0) {
                    $_isbn_url = $_isbn_url->current()->getAttributeNode('href')->nodeValue;
                    $parts = explode('/', $_isbn_url);
                    if (count($parts) < 4) {
                        echo $html."<hr>";
                        echo $_isbn_url;
                        var_dump($parts); die;
                    } else {
                        $_isbn = $parts[3];
                    }
                } else {
                    $_isbn = '';
                }
                        
                $_description = $resultDom->query('//div[@class="result-description"]/p')->current()->nodeValue;
                $_description = str_replace('Book Description: ', '', $_description);
                
                preg_match('/Book Condition: (.*?)\./i', $_description, $matches);
                if (isset($matches[1])) {
                    $_condition = $matches[1];
                } else {
                    $_condition = '';
                }
                        
                $_priceBook = $resultDom->query('//div[@class="item-price"]//span[@class="price"]')->current()->nodeValue;
                $_priceBook = str_replace('US$ ', '', $_priceBook);
                $_priceBook = str_replace('US $ ', '', $_priceBook);
                
                $_priceShip = $resultDom->query('//div[@class="shipping"]//span[@class="price"]');
                if (count($_priceShip) > 0) {
                    $_priceShip = $_priceShip->current()->nodeValue;
                    $_priceShip = str_replace('US$ ', '', $_priceShip);
                    $_priceShip = str_replace('US $ ', '', $_priceShip);
                } else {
                    $_priceShip = 0;
                }
                
                $_binding = $this->getBindingFromDescription($_description);
    
                /*
                $clientBook = new Zend_Http_Client($_url);
                $clientBook->setMethod(Zend_Http_Client::GET);
                $responseBook = $clientBook->request();
                $html = $responseBook->getBody();
                $html = str_replace('src="/', 'src="http://www.abebooks.com/', $html);
                $html = str_replace('href="/', 'href="http://www.abebooks.com/', $html);
    
                $bookDom = new Zend_Dom_Query($responseBook->getBody());
    
                $_author = $bookDom->query('//h2[@id="book-author"]')->current()->nodeValue;
    
                $_bookseller = $bookDom->query('//a[@id="a-bookseller-storefront"]')->current()->nodeValue;
                $_booksellerHtml = $bookDom->query('//div[@id="aboutTheBookseller"]//div[@class="contentCol"]/h3')->current()->nodeValue;
                preg_match('/Address: (.*?)$/i', $_booksellerHtml, $matches);
                $_bookseller_location = $matches[1];
                
                $_isbn = $bookDom->query('//h2[@class="isbn"]/a[2]')->current()->nodeValue;
                
                $_description = $bookDom->query('//p[@id="Description-heading"]')->current()->nodeValue;
                
                $_condition = $bookDom->query('//span[@id="biblio-bookcondition"]')->current();
                if ($_condition) {
                    $_condition = $_condition->nodeValue;
                } else {
                    $_condition = '';
                }
                        
                $_priceBook = $bookDom->query('//span[@id="book-price"]')->current()->nodeValue;
                $_priceBook = str_replace('US$ ', '', $_priceBook);
                $_priceBook = str_replace('US $ ', '', $_priceBook);
                
                $_priceShip = $bookDom->query('//span[@class="shipping"]')->current()->nodeValue;
                $_priceShip = str_replace('US$ ', '', $_priceShip);
                $_priceShip = str_replace('US $ ', '', $_priceShip);
                
                $_binding = strtolower($bookDom->query('//span[@id="biblio-binding"]')->current()->nodeValue);
                switch ($_binding) {
                    case 'hardcover':     $_binding = 'H'; break;
                    case 'softcover':     $_binding = 'S'; break;
                    default:             $_binding = ''; break;
                }
                */
                
                $book = array();
                $book['title'] = $_title;
                $book['author'] = $_author;
                $book['description'] = $_description;
                $book['condition'] = $_condition;
                $book['bookseller'] = $_bookseller;
                $book['bookseller_location'] = $_bookseller_location;
                $book['price_book'] = $_priceBook;
                $book['price_shipping'] = $_priceShip;
                $book['price_total'] = $_priceBook + $_priceShip;
                $book['isbn'] = $_isbn;
                $book['binding'] = $_binding;
                $book['url'] = $_url;
                $book['source'] = 'AbeBooks';
                
                $books[] = $book;            
            }

        }
        return $books;
    }

    public function searchAlibris($author, $title, $book_condition, $book_format) {
        if ($book_format == 'paperback') {
            $book_format = 'S';
        } else if ($book_format == 'hardcover') {
            $book_format = 'H';
        } else {
            $book_format = '';
        }
        
        // Alibris:
        $url = 'http://www.alibris.com/booksearch?'.
                'author='.urlencode($author).'&'.
                'title='.urlencode($title).'&'.
                'binding='.urlencode($book_format);
        $client = new Zend_Http_Client($url);
        $client->setMethod(Zend_Http_Client::GET);
        $response = $client->request();

        $dom = new Zend_Dom_Query($response->getBody());
        $results = $dom->query('//ul[@id="works"]//li//div[@class="left"]//h2//a');
        
        $books = array();
        foreach ($results as $result) {
            $workUrl = 'http://www.alibris.com'.$result->getAttributeNode('href')->nodeValue;
            echo $workUrl; die;
            
            $_url = 'http://www.abebooks.com'.$_titleNode->getAttributeNode('href')->nodeValue;

            $clientBook = new Zend_Http_Client($_url);
            $clientBook->setMethod(Zend_Http_Client::GET);
            $responseBook = $clientBook->request();
            $html = $responseBook->getBody();
            $html = str_replace('src="/', 'src="http://www.abebooks.com/', $html);
            $html = str_replace('href="/', 'href="http://www.abebooks.com/', $html);

            $bookDom = new Zend_Dom_Query($responseBook->getBody());

            $_author = $bookDom->query('//h2[@id="book-author"]')->current()->nodeValue;

            $_bookseller = $bookDom->query('//a[@id="a-bookseller-storefront"]')->current()->nodeValue;
            $_booksellerHtml = $bookDom->query('//div[@id="aboutTheBookseller"]//div[@class="contentCol"]/h3')->current()->nodeValue;
            preg_match('/Address: (.*?)$/i', $_booksellerHtml, $matches);
            $_bookseller_location = $matches[1];
            
            $_description = $bookDom->query('//p[@id="Description-heading"]')->current()->nodeValue;
            
            $_condition = $bookDom->query('//span[@id="biblio-bookcondition"]')->current();
            if ($_condition) {
                $_condition = $_condition->nodeValue;
            } else {
                $_condition = '';
            }
                    
            $_priceBook = $bookDom->query('//span[@id="book-price"]')->current()->nodeValue;
            $_priceBook = str_replace('US$ ', '', $_priceBook);
            $_priceBook = str_replace('US $ ', '', $_priceBook);
            
            $_priceShip = $bookDom->query('//span[@class="shipping"]')->current()->nodeValue;
            $_priceShip = str_replace('US$ ', '', $_priceShip);
            $_priceShip = str_replace('US $ ', '', $_priceShip);
            
            $book = array();
            $book['title'] = $_title;
            $book['author'] = $_author;
            $book['description'] = $_description;
            $book['condition'] = $_condition;
            $book['bookseller'] = $_bookseller;
            $book['bookseller_location'] = $_bookseller_location;
            $book['price_book'] = $_priceBook;
            $book['price_shipping'] = $_priceShip;
            $book['price_total'] = $_priceBook + $_priceShip;
            $book['url'] = $_url;
            $book['source'] = 'AbeBooks';
            
            $books[] = $book;            
        }
        return $books;
    }


    public function searchAction() {
        
        $url = $_POST['url'];
                
        $books = array();
        $books = array_merge($books, $this->searchBookfinder($url));
                
        usortByArrayKey($books, 'price_total');
        
        foreach ($books as $book) {
            ?>
            <table border="2">
            <tr>
                <th>Price</th>
                <td>
                <?php echo htmlspecialchars($book['price_total']); ?></td>
            </tr>
            <tr>
                <th>New or Used?</th>
                <td><?php echo htmlspecialchars($book['used']); ?></td>
            </tr>
            <tr>
                <th>Binding</th>
                <td><?php echo htmlspecialchars($book['binding']); ?></td>
            </tr>
            <tr>
                <th>Description</th>
                <td><?php echo htmlspecialchars($book['description']); ?></td>
            </tr>
            </table>
            <hr>
            <?php
        }
        die;
        
    }
    
    function saveBookData($id, $url) {
        if (strlen($url) == 0) {
            return;
        }
        $books = $this->searchBookfinder($url);
        $db = Zend_Registry::get("db");
        foreach ($books as $book) {
            $data = array (
                'price' => $book['price_total'],
                'used' => $book['used'],
                'binding' => $book['binding'],
                'book_description' => $book['description'],
                'book_id' => $id);
            $db->insert('books_found', $data);
        }
    }
    
    function getHTML($DOMElement) {
        $tmp_doc = new DOMDocument();
        $tmp_doc->appendChild($tmp_doc->importNode($DOMElement,true));
        return $tmp_doc->saveHTML();
    }

}

