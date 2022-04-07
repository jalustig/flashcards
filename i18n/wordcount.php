<?php

$total_word_count = 0;
$total_word_count1 = 0;
$total_word_count2 = 0;
$total_word_count3 = 0;
$total_word_count4 = 0;
$output = "
<table border='2'>
    <tr>
        <th>Filename</th>
        <th>Priority 1</th>
        <th>Priority 2</th>
        <th>Priority 3</th>
        <th>Unprioritized</th>
    </tr>
";
if ($handle = opendir('en.lproj')) {
    while (false !== ($file = readdir($handle))) {
        if ($file != "." && $file != ".." && $file != '.DS_Store' && $file != '.svn' && $file != 'RootViewController.xib') {
            if ($file == 'MPOAuth.strings' || $file == 'FC4.strings' || $file == 'MBProgressHUD.strings') {
                continue;
            }
            
            $string = file_get_contents('en.lproj/'.$file);
            #echo strtoupper($file)."\n";
            // there is a strange encoding problem with the files; need to exterpolate the spaces:
            if ($file != 'Plural.strings') {
                $newstring = "";
                for ($i = 0; $i < strlen($string); $i+=2) {
                    $newstring .= $string[$i];
                }
                $string = $newstring;
            }
            // remove C comments:
            $strpos1 = strpos($string, "PRIORITY 1");
            $strpos2 = strpos($string, "PRIORITY 2");
            $strpos3 = strpos($string, "PRIORITY 3");
            $strposEnd = strpos($string, "PRIORITY END");
            
            $string = preg_replace('/\/\/.*?\n|\/\*[\w\W]*?\*\//', '', $string);
            
            $count = preg_match_all('/"[\w\W]*?"\W*=\W*"([\w\W]*?)";/', $string, $matches);
            #var_dump($matches);
            $all_strings = $matches[1];
            $word_count = 0;
            $word_count1 = 0;
            $word_count2 = 0;
            $word_count3 = 0;
            $word_count4 = 0;
            foreach ($all_strings as $str) {
                $strposCurrent = strpos($string, '"'.$str);
                // get rid of things which will not actually be translated
                $str = str_replace('%d', '', $str);
                $str = str_replace('%1.2f', '', $str);
                $str = str_replace('%1.1f', '', $str);
                $str = str_replace('%@', '', $str);
                $str = str_replace('\n', '', $str);
                $str = str_replace('%1$d', '', $str);
                $str = str_replace('%2$d', '', $str);
                $str = str_replace('%1$@', '', $str);
                $str = str_replace('%2$@', '', $str);
                // get rid of all html tags:
                $str = strip_tags($str);
                
                # echo $str." - ".str_word_count($str, 0)."\n";
                $word_count += str_word_count($str, 0);
                if ($strposCurrent > $strposEnd) {
                    $word_count4 += str_word_count($str, 0);
                } else if ($strposCurrent > $strpos3) {
                    $word_count3 += str_word_count($str, 0);
                } else if ($strposCurrent > $strpos2) {
                    $word_count2 += str_word_count($str, 0);
                } else {
                    $word_count1 += str_word_count($str, 0);
                }
            }
            $output .= "
            <tr>
                <th>$file</th>
                <td>$word_count1</td>
                <td>$word_count2</td>
                <td>$word_count3</td>
                <td>$word_count4</td>
            </tr>
            ";
            // echo $file." - $word_count (Priority 1: $word_count1; Priority 2: $word_count2; Priority 3: $word_count3)\n";
            #echo "\n\n---------\n\n";
            $total_word_count += $word_count;
            $total_word_count1 += $word_count1;
            $total_word_count2 += $word_count2;
            $total_word_count3 += $word_count3;
            $total_word_count4 += $word_count4;
            
        }
    }
    closedir($handle);
}

/*
echo "-------------------------\n";
echo strtoupper('Total Word Count: '.$total_word_count."\n");
echo strtoupper('Total Priority 1: '.$total_word_count1."\n");
echo strtoupper('Total Priority 2: '.$total_word_count2."\n");
echo strtoupper('Total Priority 3: '.$total_word_count3."\n");
echo strtoupper('Unprioritized: '.$total_word_count4."\n");
*/
$output .= "
<tr>
    <th>TOTAL</th>
    <th>$total_word_count1</th>
    <th>$total_word_count2</th>
    <th>$total_word_count3</th>
    <th>$total_word_count4</th>
</tr>
</table>
";

file_put_contents('wordcount.html', $output);
?>