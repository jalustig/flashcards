<?php

/******
 * WHAT IT IS
 *
 * Moves strings from en.lproj to another language project
 *
 * USAGE
 *
 * ~/i18n/transpose.php --------> won't do anything: needs a language to transpose to
 * ~/i18n/transpose.php de -----> runs against de.lproj, comparing it to en.lproj
 * ~/i18n/transpose.php fr -----> runs against fr.lproj, comparing it to en.lproj
   ~/i18n/transpose.php de Settings -----> runs against de.lproj, and fixes **ONLY** the "Settings" module by putting all the strings in the proper context.
 * ... and so on
 *
 ******/
 
 
 // as per: http://stackoverflow.com/a/2236698/353137
 function file_get_contents_utf8($fn) {
      $content = file_get_contents($fn);
       return mb_convert_encoding($content, 'UTF-8',
           mb_detect_encoding($content, 'UTF-8, ISO-8859-1', true));
 }
 
 
 if (isset($argv[1])) {
     $target_language = $argv[1].".lproj";
 } else {
     echo "\n\nERROR: Please enter target language, eg. i18n/transpose.php de\n\n";
     die;
 }
 
 $fix = "";
 if (isset($argv[2])) {
     $fix = $argv[2];
 }
 
 // 1. Get all the strings from the en.lproj translation,
 // and keep them in their priority groups.
 $source_language = "en.lproj";
 
 $source_groups = array();
 if ($handle = opendir($source_language)) {
     while (false !== ($file = readdir($handle))) {
         if ($file != "." && $file != ".." && $file != '.DS_Store' && $file != '.svn' && $file != 'RootViewController.xib') {
             if ($file == 'MPOAuth.strings' || $file == 'FC4.strings' || $file == 'MBProgressHUD.strings' || strtoupper($file) == 'APP STORE DESCRIPTION.RTF') {
                 continue;
             }

             $file_contents = file_get_contents_utf8($source_language.'/'.$file);
            $group = substr($file, 0, strpos($file, '.'));
            if (!isset($source_groups[$group])) {
                $source_groups[$group] = array(
                    'Priority 1' => array(),
                    'Priority 2' => array(),
                    'Priority 3' => array(),
                    'Priority End' => array(),
                );
                
            }
             echo strtoupper($file)."\n";
             // there is a strange encoding problem with the files; need to exterpolate the spaces:
             if ($file != 'Plural.strings') {
                 $newstring = "";
                 for ($i = 0; $i < strlen($file_contents); $i+=2) {
                     $newstring .= $file_contents[$i];
                 }
                 $file_contents = $newstring;
             }

//             $file_contents = preg_replace('/\/\/.*?\n|\/\*[\w\W]*?\*\//', '', $file_contents);
            
             // find the positions of priority sections
            $strpos1 = strpos($file_contents, '/* PRIORITY 1 */');
        //    echo "Priority 1: $strpos1 " . substr($file_contents, $strpos1, 10) . "\n";
             $strpos2 = strpos($file_contents, '/* PRIORITY 2 */');
        //    echo "Priority 2: $strpos2 " . substr($file_contents, $strpos2, 10) . "\n";
             $strpos3 = strpos($file_contents, '/* PRIORITY 3 */');
        //    echo "Priority 3: $strpos3 " . substr($file_contents, $strpos3, 10) . "\n";
             $strposEnd = strpos($file_contents, '/* PRIORITY END */');
        //    echo "Priority 4: $strposEnd " . substr($file_contents, $strposEnd, 10) . "\n";
            
             $count = preg_match_all('/"([\w\W]*?)"\s*=\s*"([\w\W]*?)";/', $file_contents, $matches);

            // matches[1] == english
            // matches[2] == target

            $all_strings = $matches[1];
             foreach ($all_strings as $n => $str) {
                 $strposCurrent = strpos($file_contents, '"'.$str);
            //    echo $strposCurrent.": ".$str."\n";
                // echo "Test: ". substr($file_contents, $strposCurrent, 20)."\n";
                if ($strposCurrent < $strpos2) {
                     // priority 1:
                //    echo "1 -- $strpos1\n----\n";

                    $source_groups[$group]['Priority 1'][] = array(
                        'source' => $str,
                        'target' => $matches[2][$n],
                    );
                } else if ($strposCurrent < $strpos3) {
                     // priority 2:
                //    echo "2 -- $strpos2\n----\n";

                    $source_groups[$group]['Priority 2'][] = array(
                        'source' => $str,
                        'target' => $matches[2][$n],
                    );
                } else if ($strposCurrent < $strposEnd) {
                     // priority 3:
                //    echo "3 -- $strpos3\n----\n";

                    $source_groups[$group]['Priority 3'][] = array(
                        'source' => $str,
                        'target' => $matches[2][$n],
                    );
                } else {
                    // priority 4:
                //    echo "4 -- $strposEnd\n----\n";
                    $source_groups[$group]['Priority End'][] = array(
                        'source' => $str,
                        'target' => $matches[2][$n],
                    );
                 }
             }
            
         }
     }
     closedir($handle);
 }
 
 // 2. Get all the strings from the target translation.
 // it doesn't matter what priority group they are in.
 echo "-------------\n";
 echo "Parsing target language: $target_language\n";
 
 $target_groups = array();
 
 // puts them into array $tr_strings
 if ($handle = opendir($target_language)) {
     while (false !== ($file = readdir($handle))) {
         if ($file != "." && $file != ".." && $file != '.DS_Store' && $file != '.svn' && $file != 'RootViewController.xib' && strtoupper($file) != 'APP STORE DESCRIPTION.RTF') {
             
             if (strlen($fix) > 0) {
                 $file = $fix.".strings";
             }
             $file_contents = file_get_contents_utf8($target_language.'/'.$file);
            // $file_contents = mb_convert_encoding($file_contents, 'UTF-16LE');
             echo strtoupper($file)."\n";
            
            $group = substr($file, 0, strpos($file, '.'));
            if (!isset($target_groups[$group])) {
                $target_groups[$group] = array();
            }
            
             // there is a strange encoding problem with the files; need to exterpolate the spaces:
             /*
            if ($file != 'Plural.strings') {
                 $newstring = "";
                 for ($i = 0; $i < strlen($file_contents); $i+=2) {
                     $newstring .= $file_contents[$i];
                 }
                $file_contents = $newstring;
             }
            */
            
            // remove C comments:
            $string = preg_replace('/\/\/.*?\n|\/\*[\w\W]*?\*\//', '', $string);

            $count = preg_match_all('/"([\w\W]*?)"\s*=\s*"([\w\W]*?)";/', $file_contents, $matches);

            foreach ($matches[1] as $key => $source) {
                $target_groups[$group][$source] = $matches[2][$key];
            }
            
            if (strlen($fix) > 0) {
                break;
            }
         }
     }
     closedir($handle);
 }
  
 // 3. Recreate the target translation from the original
 // If there is a target translation for a particular item, then use it;
 // otherwise, throw it out.

 if (strlen($fix) > 0) {
     $source_groups = array(
         $fix => $source_groups[$fix],
     );
 } else {
     $source_groups = $source_groups;
 }

 foreach ($source_groups as $name => $group) {
     $target_file = $target_language."/".$name.".strings";
     echo "-------------------\n";
     
    echo "FIXING STRINGS in $name.strings:\n";
    if (!isset($target_groups[$name])) {
        echo "WARNING: $group does not exist in target...\n";
        continue;
    }
    
    $new_file_contents = '';
    
     foreach ($group as $priority => $strings) {

        $new_file_contents .= '/**********************************************/'."\n";
        $new_file_contents .= '/* '.strtoupper($priority).' */'."\n";
        $new_file_contents .= '/**********************************************/'."\n\n";

        foreach ($strings as $string) {
            $source_left = $string['source'];
            $source_right = $string['target'];
            if (isset($target_groups[$name][$source_left])) {
                $target_right = $target_groups[$name][$source_left];
                
                $new_left = $source_left;
                $new_right = $target_right;

                 // clear out this item from the $target_groups[$name] list,
                 // so that when we get to the end of the file we know which items
                 // weren't saved from the transition.
                unset($target_groups[$name][$source_left]);
            } else {
                
                $new_left = $source_left;
                $new_right = $source_right;

            }
            if ($new_left == 'Automatically Sync With %@') {
                $new_file_contents .= '/* eg. \'Automatically Sync with iPhone\' or \'Automatically Sync with iPad\' */'."\n";
            }
            $new_file_contents .= "\"$new_left\" = \n\"$new_right\";\n\n";
        }
        
        // if we are at the end of the priority list, then we add all other items
        // that weren't yet saved in the transition, at the end of the file:
        if ($priority == 'Priority End') {
            foreach ($target_groups[$name] as $target_left => $target_right) {
                $new_file_contents .= "\"$target_left\" = \n\"$target_right\";\n\n";
            }
        
        }
    }

    // echo $new_file_contents;
    
     echo "Writing...\n\n";
     file_put_contents($target_file, $new_file_contents);
 }
 
 // 4. anything extra, put at the bottom of the files.
?>