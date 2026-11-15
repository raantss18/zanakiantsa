# Capture d'une ère : installe la version $1, prépare un garçon de $2 ans, photographie l'accueil et « Tout explorer ».
D=/tmp/claude-1000/-home-raantss/ca9dcbd7-f23e-49e4-abdf-75ded5a0d4ba/scratchpad/demo; source $D/lib.sh
E=/tmp/claude-1000/-home-raantss/ca9dcbd7-f23e-49e4-abdf-75ded5a0d4ba/scratchpad/evo
v=$1; age=${2:-8}
$A uninstall mg.zanakiantsa.app >/dev/null 2>&1
$A install $E/apk/zanakiantsa-$v-arm64-v8a.apk | tail -1
$A shell monkey -p mg.zanakiantsa.app 1 >/dev/null 2>&1; sleep 9
gate; labels | grep -q "Combien font" && gate
tapl "Plus tard"; sleep 1; for i in $(seq 1 14); do c=$(center "un garçon"); [ -n "$c" ] && break; $A shell input swipe 400 1100 400 500 400; sleep 1; done
$A shell input tap $c; sleep 1.5
for i in $(seq 6 $age); do tapl "Un an de plus"; sleep 0.8; done
labels | grep -o "Âge [0-9]* ans" | head -1
$A shell input keyevent 4; sleep 6
shot $E/$v-accueil.png
tapl "Tout explorer"; sleep 4; shot $E/$v-explorer.png
$A shell input keyevent 4; sleep 2
