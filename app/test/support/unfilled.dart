/// Une variable de phrase restée telle quelle (`{n}`, `{objets}`…). Une accolade seule n'en est pas une : les leçons de
/// code affichent des dictionnaires Python (`d = {'nom': 'Rado'}`).
final unfilled = RegExp(r'\{\w+\}');
