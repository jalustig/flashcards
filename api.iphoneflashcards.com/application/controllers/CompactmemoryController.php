<?php

include 'Zend/Http/Client.php';
include 'Zend/Dom/Query.php';
include 'Zend/Json.php';

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

class CompactmemoryController extends Zend_Controller_Action
{
    public $db;
    
    public function init()
    {
        /* Initialize action controller here */
        // echo "<base href='http://api.iphoneflashcards.com/bookfinder/'>";
    }

    public function indexAction() {
        
        $url = 'http://compactmemory.de/library/seiten.aspx?context=tree&ID_0='.urlencode($_GET['id']).'#x';
        $client = new Zend_Http_Client($url);
        $client->setMethod(Zend_Http_Client::GET);
        $response = $client->request();

        $html = $response->getBody();
        
        preg_match_all("/<a href=\"javascript:LoadFrames\('ID_0=[0-9]*?&amp;ID_1=([0-9]*?)'\)\">\W*?<span class=\"R_Jahrgang\">([^<]*?)<\/span>\W*?<\/a>/i", utf8_encode($html), $matches);
        
        $years = array();
        foreach ($matches[1] as $k => $id) {
            $year = $matches[2][$k];
            $years[] = array('id' => $id, 'year' => $year);
        }
        
        echo Zend_Json::encode($years); die;
    }
    
    public function yearAction() {
        $url = 'http://compactmemory.de/library/seiten.aspx?context=tree&ID_0='.urlencode($_GET['id']).'&ID_1='.urlencode($_GET['year']).'#x';
        $client = new Zend_Http_Client($url);
        $client->setMethod(Zend_Http_Client::GET);
        $response = $client->request();

        $html = $response->getBody();
        
        preg_match_all("/<a target=\"main\" href=\"seiten\.aspx\?context=pages&amp;ID_0=[0-9]*?&amp;ID_1=[0-9]*?&amp;ID_2=([0-9]*?)\">\W*?<span class=\"R_Band\">([^<]*?)<\/span>\W*?<\/a>/i", utf8_encode($html), $matches);
        
        $issues = array();
        foreach ($matches[1] as $k => $id) {
            $name = $matches[2][$k];
            $issues[] = array('id' => $id, 'name' => $name);
        }
        
        echo Zend_Json::encode($issues); die;
    }
    
    
    public function pageAction() {

        if (!isset($_GET['page'])) {
            $url = 'http://compactmemory.de/library/seiten.aspx?context=pages&ID_0='.urlencode($_GET['id']).'&ID_1='.urlencode($_GET['year']).'&ID_2='.urlencode($_GET['issue']).'&ID_3=1000000000&skalierung=50';
        } else {
            $url = 'http://compactmemory.de/library/seiten.aspx?context=pages&ID_0='.urlencode($_GET['id']).'&ID_1='.urlencode($_GET['year']).'&ID_2='.urlencode($_GET['issue']).'&ID_3=1000000000&ID_4='.urlencode($_GET['page']).'&skalierung=50';
        }
        $client = new Zend_Http_Client($url);
        $client->setMethod(Zend_Http_Client::GET);
        $response = $client->request();

        $html = $response->getBody();

        preg_match_all('/<img alt="Seite" class="page" border="0" src="([^"]*?)">/', utf8_encode($html), $matches_image);
        preg_match_all("/<a.*?href=\"([^\"]*?)\"[^>]*?>\W*?<img.*?src=\"\.\.\/graphics\/navigation\/search\/fw\.gif\"[^>]*?>\W*?<\/a>/", utf8_encode($html), $matches_nextpage);
        if (count($matches_nextpage[0]) > 0) {
            preg_match("/ID_4=([^&]*?)&/", $matches_nextpage[1][0], $matches);
            $nextpage = $matches[1];
        } else {
            $nextpage = null;
        }
        $data = array(
            'imageUrl' => $matches_image[1][0],
            'nextPage' => $nextpage,
            'totalPages' => $totalPages,
            );
        echo Zend_Json::encode($data);
        die;
        
//              <img alt="Seite" class="page" border="0" src="http://www.compactmemory.de/scripts/ImgServa.dll/convert?ilFN=e:\cm_images\2/11/613/z_welt_10001r.tif&amp;ilIF=G&amp;ilDT=1&amp;ilSC=15&amp;ilAA=6">
/*              <a href="seiten.aspx?context=pages&ID_0=2&ID_1=11&ID_2=613&ID_3=1000000000&ID_4=z_welt_10002l.tif&skalierung=50" target="main">
<img width="12" height="10" border="0" title="1 Seite vor" alt="1 Seite vor" src="../graphics/navigation/search/fw.gif">
</a> -- image for the next page.
        compactmemory.de/library/seiten.aspx?context=pages&ID_0=2&ID_1=11&ID_2=613&ID_3=1000000000&skalierung=50
        http://compactmemory.de/library/seiten.aspx?context=pages&ID_0=2&ID_1=11&ID_2=613&ID_3=1000000000&ID_4=z_welt_10002l.tif&skalierung=50
*/        
die;
        
    }

    public function pagesAction() {

        $url = 'http://compactmemory.de/library/seiten.aspx?context=pages&ID_0='.urlencode($_GET['id']).'&ID_1='.urlencode($_GET['year']).'&ID_2='.urlencode($_GET['issue']).'&ID_3=1000000000&skalierung=15';
        $images = array();
        $client = new Zend_Http_Client($url);
        $client->setMethod(Zend_Http_Client::GET);
        $i = 0;
        do {
            $client->setUri($url);
            $hasNextPage = 1;
            // echo $url."<br>\n";
            $response = $client->request();
            $html = $response->getBody();
            preg_match_all('/<img[^>]*?src="(http:\/\/www\.compactmemory\.de\/scripts\/ImgServa\.dll[^"]*?)"[^>]*?>/', utf8_encode($html), $matches_image);
            preg_match_all("/<a[^>]*?href=\"([^\"]*?)\"[^>]*?><img[^>]*?src=\"\.\.\/graphics\/navigation\/search\/fw\.gif\"[^>]*?><\/a>/", utf8_encode($html), $matches_nextpage);
            if (count($matches_image) < 2) {
            //    echo $html;
            }
            $images[] = $matches_image[1][0];
            if (count($matches_nextpage[0]) > 0) {
                $url = 'http://compactmemory.de/library/'.$matches_nextpage[1][0];
                $url = str_replace('&amp;', '&', $url);
                $hasNextPage = 1;
            } else {
                $hasNextPage = 0;
            }
            // echo "<hr>";
            $i++;
            if ($i >= 100) {
                break;
            }
        } while ($hasNextPage);
        
        $newImages = array();
        foreach ($images as $k => $url) {
            $url = explode('?', $url);
            $querystring = $url[1];
            $querystring = explode('&amp;', $querystring);
            foreach ($querystring as $k => $v) {
                $v = explode('=', $v);
                $v = $v[0].'='.urlencode($v[1]);
                $querystring[$k] = $v;
            }
            $querystring = join('&amp;', $querystring);
            $url = $url[0].'?'.$querystring;
            $newImages[] = $url;
        }
        
        echo Zend_Json::encode($newImages);
        die;
        
//              <img alt="Seite" class="page" border="0" src="http://www.compactmemory.de/scripts/ImgServa.dll/convert?ilFN=e:\cm_images\2/11/613/z_welt_10001r.tif&amp;ilIF=G&amp;ilDT=1&amp;ilSC=15&amp;ilAA=6">
/*              <a href="seiten.aspx?context=pages&ID_0=2&ID_1=11&ID_2=613&ID_3=1000000000&ID_4=z_welt_10002l.tif&skalierung=50" target="main">
<img width="12" height="10" border="0" title="1 Seite vor" alt="1 Seite vor" src="../graphics/navigation/search/fw.gif">
</a> -- image for the next page.
        compactmemory.de/library/seiten.aspx?context=pages&ID_0=2&ID_1=11&ID_2=613&ID_3=1000000000&skalierung=50
        http://compactmemory.de/library/seiten.aspx?context=pages&ID_0=2&ID_1=11&ID_2=613&ID_3=1000000000&ID_4=z_welt_10002l.tif&skalierung=50
*/        
die;
        
    }
    
}

