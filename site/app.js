// Seul script du site : le bouton « Copier » de l'empreinte du fichier. Sans lui, l'empreinte reste lisible et sélectionnable.
(function () {
  var bouton = document.getElementById('copier');
  var texte = document.getElementById('empreinte');
  if (!bouton || !texte || !navigator.clipboard) return;
  bouton.hidden = false;
  bouton.addEventListener('click', function () {
    navigator.clipboard.writeText(texte.textContent.trim()).then(function () {
      bouton.textContent = 'Copié';
      setTimeout(function () { bouton.textContent = 'Copier'; }, 2000);
    });
  });
})();
