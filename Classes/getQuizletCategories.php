<?php

set_time_limit(30000);

include 'Zend/Version.php';
include 'Zend/Http/Client.php';
include 'Zend/Dom/Query.php';
include 'Zend/Cache.php';
include 'Zend/Db.php';

function getUrl($url) {
    $client = new Zend_Http_Client($url);
    $client->setMethod(Zend_Http_Client::GET);
    $response = $client->request();
    $html = $response->getBody();
    return $html;
}

function getUrlCache($url, $tag = null) {
    global $cache, $client;
    $client->setUri($url);
    if (empty($tag)) {
        return $client->request()->getBody();
    }
    if (!($response = $cache->load($tag))) {
        $response = $client->request()->getBody();
        $cache->save($response, $tag);
        #echo 'NOT CACHED';
        return $html;
    }
    #echo 'CACHED';
    return $response;
}

$lifetime = 3600 * 10;

$url = 'http://quizlet.com/find-flashcards/';
$client = new Zend_Http_Client($url);
$client->setCookieJar();
$client->setMethod(Zend_Http_Client::GET);
$response = $client->request('GET');
$html = $response->getBody();

$dom = new Zend_Dom_Query($html);
$topSections = $dom->query('//ul[@class="medium_text"]/li/a');
foreach ($topSections as $section) {
    $url = "http://quizlet.com".$section->getAttribute('href');
    $sectionTitle = $section->nodeValue;
    ?>
    <dict>
        <key>name</key>
        <string><?php echo htmlspecialchars($sectionTitle); ?></string>
        <key>children</key>
        <array>
        <?php
        $html = getUrl($url);
        $sectionDom = new Zend_Dom_Query($html);
        $sectionTitles = $sectionDom->query('//div[@class="category"]/h3');
        $children = $sectionDom->query('//div[@class="category"]/ul');
        foreach ($sectionTitles as $k => $subSection) {
            $sectionTitle = $subSection->nodeValue;
            $sectionChildren = $children->current();
            ?>
            <dict>
                <key>name</key>
                <string><?php echo htmlspecialchars($sectionTitle); ?></string>
                <key>children</key>
                <array>
                <?php
                foreach ($sectionChildren->childNodes as $li) {
                    if (strlen(trim($li->nodeValue)) == 0) {
                        continue;
                    }
                    ?>
                    <dict>
                        <key>name</key>
                        <string><?php echo htmlspecialchars($li->nodeValue); ?></string>
                        <key>children</key>
                        <array></array>
                    </dict>
                    <?php
                }
                ?>
                </array>
            </dict>
            <?php
            $children->next();
        }
        ?>
        </array>
    </dict>
    <?php
}

?>