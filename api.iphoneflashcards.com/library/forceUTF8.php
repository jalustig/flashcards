<?php 
/**
 * @author   "Sebastián Grignoli" <grignoli@framework2.com.ar>
 * @package  forceUTF8
 * @version  1.1
 * @link     http://www.framework2.com.ar/dzone/forceUTF8-es/
 * @example  http://www.framework2.com.ar/dzone/forceUTF8-es/
  */

function forceUTF8($text){
/**
 * Function forceUTF8
 *    
 * This function leaves UTF8 characters alone, while converting almost all non-UTF8 to UTF8.
 *    
 * It may fail to convert characters to unicode if they fall into one of these scenarios:
 *
 * 1) when any of these characters:   ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖ×ØÙÚÛÜÝÞß
 *    are followed by any of these:  ("group B")
 *                                    ¡¢£¤¥¦§¨©ª«¬­®¯°±²³´µ¶•¸¹º»¼½¾¿
 * For example:   %ABREPRESENT%C9%BB. «REPRESENTÉ»
 * The "«" (%AB) character will be converted, but the "É" followed by "»" (%C9%BB) 
 * is also a valid unicode character, and will be left unchanged.
 *
 * 2) when any of these: àáâãäåæçèéêëìíîï  are followed by TWO chars from group B,
 * 3) when any of these: ðñòó  are followed by THREE chars from group B.
 *
 * @name forceUTF8
 * @param string $text  Any string.
 * @return string  The same string, UTF8 encoded
 *    
 */

  if(is_array($text))
    {
      foreach($text as $k => $v)
    {
      $text[$k] = forceUTF8($v);
    }
      return $text;
    }

    $max = strlen($text);
    $buf = "";
    for($i = 0; $i < $max; $i++){
        $c1 = $text{$i};
        if($c1>="\xc0"){ //Should be converted to UTF8, if it's not UTF8 already
          $c2 = $i+1 >= $max? "\x00" : $text{$i+1};
          $c3 = $i+2 >= $max? "\x00" : $text{$i+2};
          $c4 = $i+3 >= $max? "\x00" : $text{$i+3};
            if($c1 >= "\xc0" & $c1 <= "\xdf"){ //looks like 2 bytes UTF8
                if($c2 >= "\x80" && $c2 <= "\xbf"){ //yeah, almost sure it's UTF8 already
                    $buf .= $c1 . $c2;
                    $i++;
                } else { //not valid UTF8.  Convert it.
                    $cc1 = (chr(ord($c1) / 64) | "\xc0");
                    $cc2 = ($c1 & "\x3f") | "\x80";
                    $buf .= $cc1 . $cc2;
                }
            } elseif($c1 >= "\xe0" & $c1 <= "\xef"){ //looks like 3 bytes UTF8
                if($c2 >= "\x80" && $c2 <= "\xbf" && $c3 >= "\x80" && $c3 <= "\xbf"){ //yeah, almost sure it's UTF8 already
                    $buf .= $c1 . $c2 . $c3;
                    $i = $i + 2;
                } else { //not valid UTF8.  Convert it.
                    $cc1 = (chr(ord($c1) / 64) | "\xc0");
                    $cc2 = ($c1 & "\x3f") | "\x80";
                    $buf .= $cc1 . $cc2;
                }
            } elseif($c1 >= "\xf0" & $c1 <= "\xf7"){ //looks like 4 bytes UTF8
                if($c2 >= "\x80" && $c2 <= "\xbf" && $c3 >= "\x80" && $c3 <= "\xbf" && $c4 >= "\x80" && $c4 <= "\xbf"){ //yeah, almost sure it's UTF8 already
                    $buf .= $c1 . $c2 . $c3;
                    $i = $i + 2;
                } else { //not valid UTF8.  Convert it.
                    $cc1 = (chr(ord($c1) / 64) | "\xc0");
                    $cc2 = ($c1 & "\x3f") | "\x80";
                    $buf .= $cc1 . $cc2;
                }
            } else { //doesn't look like UTF8, but should be converted
                    $cc1 = (chr(ord($c1) / 64) | "\xc0");
                    $cc2 = (($c1 & "\x3f") | "\x80");
                    $buf .= $cc1 . $cc2;                
            }
        } elseif(($c1 & "\xc0") == "\x80"){ // needs conversion
                $cc1 = (chr(ord($c1) / 64) | "\xc0");
                $cc2 = (($c1 & "\x3f") | "\x80");
                $buf .= $cc1 . $cc2;                
        } else { // it doesn't need convesion
            $buf .= $c1;
        }
    }
    return $buf;
}

function forceLatin1($text) {
  if(is_array($text)) {
    foreach($text as $k => $v) {
      $text[$k] = forceLatin1($v);
    }
    return $text;
  }
  return utf8_decode(forceUTF8($text));
}

function fixUTF8($text){
  if(is_array($text)) {
    foreach($text as $k => $v) {
      $text[$k] = fixUTF8($v);
    }
    return $text;
  }
  
  $last = "";
  while($last <> $text){
    $last = $text;
    $text = forceUTF8(utf8_decode(forceUTF8($text)));
  }
  return $text;    
}

function utf16_to_utf8($str) {
    $c0 = ord($str[0]);
    $c1 = ord($str[1]);

    if ($c0 == 0xFE && $c1 == 0xFF) {
        $be = true;
    } else if ($c0 == 0xFF && $c1 == 0xFE) {
        $be = false;
    } else {
        return $str;
    }

    $str = substr($str, 2);
    $len = strlen($str);
    $dec = '';
    for ($i = 0; $i < $len; $i += 2) {
        $c = ($be) ? ord($str[$i]) << 8 | ord($str[$i + 1]) : 
                ord($str[$i + 1]) << 8 | ord($str[$i]);
        if ($c >= 0x0001 && $c <= 0x007F) {
            $dec .= chr($c);
        } else if ($c > 0x07FF) {
            $dec .= chr(0xE0 | (($c >> 12) & 0x0F));
            $dec .= chr(0x80 | (($c >>  6) & 0x3F));
            $dec .= chr(0x80 | (($c >>  0) & 0x3F));
        } else {
            $dec .= chr(0xC0 | (($c >>  6) & 0x1F));
            $dec .= chr(0x80 | (($c >>  0) & 0x3F));
        }
    }
    return $dec;
}


function isUTF8($string) {
    return (utf8_encode(utf8_decode($string)) == $string);
}
