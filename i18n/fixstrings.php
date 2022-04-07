<?php

/******
 * USAGE
 *
 * ~/i18n/fixstrings.php --------> runs against default language, en.lproj
 * ~/i18n/fixstrings.php de -----> runs against de.lproj, comparing it to en.lproj
 * ~/i18n/fixstrings.php fr -----> runs against fr.lproj
   ~/i18n/fixstrings.php en Settings -----> runs against en.lproj, and fixes **ONLY** the "settings" module by putting all the strings at the very bottom.
 * ... and so on
 *
 ******/

// 1. Get all of the strings from the app.

$app_strings = array();
$string_files = array();

function readdirectory($h, $path) {
    
    global $app_strings, $string_files;
    
    $letters = '[A-Za-z\+\,\.\:\;\&\%\@\#\/\<\>\\\?\-\"\(\)\?\!\[\]\\\' 0-9^}]';
    
    while (false !== ($file = readdir($h))) {
        if ($file != '.' && $file != ".." && $file != ".DS_Store" && $file != '.svn') {
            $file = $path.'/'.$file;
            if (is_dir($file)) {
                readdirectory(opendir($file), $file);
            } else {
                $file_extension = explode(".", $file);
                $file_extension = $file_extension[count($file_extension)-1];
                if (in_array($file_extension, array("m", "mm"))) {
                    // pull all of the strings from the file:
                    $string = file_get_contents($file);
                    preg_match_all('/NSLocalizedStringFromTable\(\@"('.$letters.'*?)"\,\W*\@"('.$letters.'*?)"\,\W*\@"'.$letters.'*?"/', $string, $matches1);
                    preg_match_all('/NSLocalizedStringWithDefaultValue\(\@"('.$letters.'*?)"\,\W*\@"('.$letters.'*?)"\,/', $string, $matches2);
                    foreach (array($matches1, $matches2/*, $matches3*/) as $matches) {
                        for ($i = 0; $i < count($matches[1]); $i++) {
                            $localized_string = $matches[1][$i];
                            $localized_table  = $matches[2][$i];
                            if (@is_null($app_strings[$localized_table])) {
                                $app_strings[$localized_table] = array();
                            }
                            if (!in_array($localized_string, $app_strings[$localized_table])) {
                                $app_strings[$localized_table][] = $localized_string;
                            }
                            // keep track of where the string was found:
                            $desc = "$localized_table - $localized_string";
                            if (@is_null($string_files[$desc])) {
                                $string_files[$desc] = array();
                            }
                            $string_files[$desc][] = $file;
                        }
                    }
                }
            }
        }
    }
    closedir($h);
    
}

if ($handle = opendir('.')) {
    readdirectory($handle, getcwd());
}

// 2. Get all of the strings from the translations.

$total_word_count = 0;
$tr_strings = array();

$language = "en.lproj";
if (isset($argv[1])) {
    $language = $argv[1].".lproj";
}

$fix = "";
if (isset($argv[2])) {
    $fix = $argv[2];
}

if ($handle = opendir($language)) {
    while (false !== ($file = readdir($handle))) {
        if ($file != "." && $file != ".." && $file != '.DS_Store' && $file != '.svn' && $file != 'RootViewController.xib') {
            $string = file_get_contents($language.'/'.$file);

            // there is a strange encoding problem with the files; need to exterpolate the spaces:
            if ($file != 'Plural.strings') {
                $newstring = "";
                for ($i = 0; $i < strlen($string); $i+=2) {
                    $newstring .= $string[$i];
                }
                $string = $newstring;
            }
            // remove C comments:
            $string = preg_replace('/\/\/.*?\n|\/\*[\w\W]*?\*\//', '', $string);
            
            $count = preg_match_all('/"([\w\W]*?)"\s*=\s*"[\w\W]*?";/', $string, $matches);
            $tr_strings[substr($file, 0, strlen($file)-8)] = $matches[1];
        }
    }
    closedir($handle);
}

// var_dump($tr_strings); die;

// 3. See which of the app strings are NOT in the translations:

$missing_groups = array();
$missing_app_strings = array();
$missing_app_strings_groups = array();
foreach ($app_strings as $group_name => $str_group) {
    foreach ($str_group as $str_str) {
        if (@is_null($tr_strings[$group_name])) {
            if (!in_array($group_name, $missing_groups)) {
                $missing_groups[] = $group_name;
            }
            continue;
        }
        if (!in_array($str_str, $tr_strings[$group_name])) {
            $missing_str = "$group_name - $str_str";
            if (!in_array($missing_str, $missing_app_strings)) {
                $missing_app_strings[] = $missing_str;
            }
            if (!isset($missing_app_strings_groups[$group_name])) {
                $missing_app_strings_groups[$group_name] = array();
            }
            if (!in_array($str_str, $missing_app_strings_groups[$group_name])) {
                $missing_app_strings_groups[$group_name][] = $str_str;
            }
        }
    }
}

echo "MISSING STRINGS IN TRANSLATIONS ($language):\n";
if (count($missing_app_strings) > 0) {
    foreach ($missing_app_strings as $g) {
        echo "$g\n";
        foreach ($string_files[$g] as $i) {
            echo "\t$i\n";
        }
    }
} else {
    echo "OK: No missing strings!!\n";
}

echo "-------------------\n";
echo "\n\n";
echo "FIXING STRINGS............\n";
echo "\n\n";

// if the user specified which string group to fix, only fix that one.
// Otherwise, fix everything
if (strlen($fix) > 0) {
    $groups = array(
        $fix => $missing_app_strings_groups[$fix],
    );
} else {
    $groups = $missing_app_strings_groups;
}

$group = $missing_app_strings_groups[$fix];
foreach ($groups as $name => $group) {
    $fix_file = $language."/".$name.".strings";
    echo "-------------------\n";
    
    $append = '';
    
    echo "FIXING STRINGS in $name.strings:\n";
    foreach ($group as $str_str) {
        $str = "\n\n\"$str_str\" = \n\"$str_str\";";
        $append .= $str;
        
        echo "Adding \"$str_str\"\n";
    }
    
    $append = mb_convert_encoding($append, 'UTF-16LE');
    echo "Writing...\n";
    file_put_contents($fix_file, $append, FILE_APPEND);
}

?>