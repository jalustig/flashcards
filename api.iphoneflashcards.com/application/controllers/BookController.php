<?php

include 'Zend/Http/Client.php';
include 'Zend/Dom/Query.php';


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

class BookController extends Zend_Controller_Action
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
        
        ?>
        <form action="search/" method="post">
        <table>
        <tr>
            <th>Author</th>
            <td><input name="author" type="text" width="100" /></td>
        </tr>
        <tr>
            <th>Title</th>
            <td><input name="title" type="text" width="100" /></td>
        </tr>
        <tr>
            <th>Condition:</th>
            <td><select name="book_condition"><option value="">Any condition</option><option value="vgb" >Very good or better</option><option value="fb" >Fine</option><option value="nb" >New</option></select></td>
        </tr>
        <tr>
            <th>Binding:</th>
            <td><select name="book_format" tabindex="22" id="format"><option value="" selected="selected">Any</option><option value="hardcover" >Hardcover</option><option value="paperback" >Paperback</option></select></td>
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

    public function searchBiblio($author, $title, $book_condition, $book_format) {
        // Biblio:
        $url = 'http://www.biblio.com/search.php?'.
            'author='.urlencode($author).'&'.
            'title='.urlencode($title).'&'.
            'isbn=&keywords=&publisher=&illustrator=&'.
            'minprice='.'&'.
            'maxprice='.'&'.
            'mindate=&maxdate=&quantity=&stage=1&'.
            'cond='.urlencode($book_condition).'&'.
            'format='.urlencode($book_format).'&'.
            'country='.'&'.
            'dist=5&zip=&days_back=0&order=priceasc&pageper=200';
    //    echo $url;
        $client = new Zend_Http_Client($url);
        $client->setMethod(Zend_Http_Client::GET);
        $response = $client->request();

        $dom = new Zend_Dom_Query($response->getBody());
        $results = $dom->query('//div[@class="search-result"]');
        
        $books = array();
        foreach ($results as $result) {
            $html = $this->getHTML($result);
            $resultDom = new Zend_Dom_Query($html);
            $_titleNode = $resultDom->query('//a[class="sr-title-text"]')->current();
            $_title = $_titleNode->nodeValue;
            $_url = $_titleNode->getAttributeNode('href')->nodeValue;
            $_author = $resultDom->query('//h3[@class="sr-author"]')->current()->nodeValue;
            if (substr($_author, 0, 3) == 'By ') {
                $_author = substr($_author, 3, strlen($_author)-3);
            }
            
            $_descriptionHtml = $this->getHtml($resultDom->query('//div[@class="sr-description"]')->current());
            $_descriptionHtml = strip_tags($_descriptionHtml, '<br>');
            $_descriptionHtml = str_replace(array('<br>', '<br />', '<br/>'), "\n", $_descriptionHtml);
            preg_match('/Bookseller: (.*?)\((.*?)\)$/i', $_descriptionHtml, $matches);
            $_bookseller = $matches[1];
            $_bookseller_location = $matches[2];
            $_description = explode("\n", $_descriptionHtml);
            $_description = $_description[0];
            
            $_conditionHtml = $this->getHtml($resultDom->query('//div[@class="sr-condition"]')->current());
            $_conditionHtml = strip_tags($_conditionHtml, '<br>');
            $_conditionHtml = str_replace(array('<br>', '<br />', '<br/>'), "\n", $_conditionHtml);
            $_conditionHtml .= "\n";
            $_condition = '';
            $condition = 'Book condition:';
            if (substr($_conditionHtml, 0, strlen($condition)) == $condition) {
                preg_match('/Book condition: (.*?)\n/i', $_conditionHtml, $matches);
                $_condition = $matches[1];
            }
            preg_match('/ISBN 13: ([0-9]*?)\n/i', $_conditionHtml, $matches);
            $_isbn = $matches[1];
            
            $_priceHtml = $this->getHtml($resultDom->query('//p[@class="ob-price"]')->current());
            $_priceHtml = strip_tags($_priceHtml, "<br>");
            $_priceHtml = str_replace(array('<br>', '<br />', '<br/>'), "\n", $_priceHtml);
            $_priceHtml = str_replace('&#036;', '$', $_priceHtml);
            $_priceHtml .="\n";
            preg_match_all('/\$([0-9\.]*?)\n/i', $_priceHtml, $matches);
            $_priceBook = (float)$matches[1][0];
            $_priceShip = (float)$matches[1][1];
            
            
            $_binding = $this->getBindingFromDescription($_description);
            
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
            $book['url'] = $_url;
            $book['binding'] = $_binding;
            $book['source'] = 'Biblio.com';
            
            $books[] = $book;            
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
        
        $author = $_POST['author'];
        $title = $_POST['title'];
        $book_condition = $_POST['book_condition'];
        $book_format = $_POST['book_format'];
        
        $books = array();
        $books = array_merge($books, $this->searchAbebooks($author, $title, $book_condition, $book_format));
        $books = array_merge($books, $this->searchBiblio($author, $title, $book_condition, $book_format));
    //    $books = array_merge($books, $this->searchAlibris($author, $title, $book_condition, $book_format));
    
        $uniqueBooks = array();
        foreach ($books as $book) {
            if (empty($book['isbn'])) {
                continue;
            }
            if (strlen($book['isbn']) == 0) {
                continue;
            }
            if (isset($uniqueBooks[$book['isbn']])) {
                continue;
            }
            $uniqueBooks[$book['isbn']] = $book['title'];
        }
        ?><ul><?php
        foreach ($uniqueBooks as $isbn => $title) {
            ?><li><?php echo htmlspecialchars($isbn); ?> - <?php echo htmlspecialchars($title); ?></li> <?php
        }
        ?></ul><?php
                
        usortByArrayKey($books, 'price_total');
        
        foreach ($books as $book) {
            ?>
            <table border="2">
            <tr>
                <th>ISBN</th>
                <td><?php echo htmlspecialchars($book['isbn']); ?></td>
            </tr>
            <tr>
                <th>Title</th>
                <td><?php echo htmlspecialchars($book['title']); ?></td>
            </tr>
            <tr>
                <th>Author</th>
                <td><?php echo htmlspecialchars($book['author']); ?></td>
            </tr>
            <tr>
                <th>Price</th>
                <td><?php echo htmlspecialchars($book['price_book']); ?> +
                <?php echo htmlspecialchars($book['price_shipping']); ?> = 
                <?php echo htmlspecialchars($book['price_total']); ?></td>
            </tr>
            <tr>
                <th>Bookseller</th>
                <td><?php echo htmlspecialchars($book['bookseller']); ?></td>
            </tr>
            <tr>
                <th>Condition</th>
                <td><?php echo htmlspecialchars($book['condition']); ?></td>
            </tr>
            <tr>
                <th>Description</th>
                <td><?php echo htmlspecialchars($book['description']); ?></td>
            </tr>
            <tr>
                <th>Site</th>
                <td><a target="_blank" href="<?php echo $book['url'];?>"><?php echo htmlspecialchars($book['source']); ?></a></td>
            </tr>
            </table>
            <hr>
            <?php
        }
        die;
        
    }
    
    function getHTML($DOMElement) {
        $tmp_doc = new DOMDocument();
        $tmp_doc->appendChild($tmp_doc->importNode($DOMElement,true));
        return $tmp_doc->saveHTML();
    }

}

