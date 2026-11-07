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

// Les chapitres du guide vidéo : un bouton par étape, qui lance la vidéo à cet endroit.
(function () {
  var video = document.querySelector('#guide video');
  if (!video) return;
  document.querySelectorAll('.chapitres button').forEach(function (b) {
    b.addEventListener('click', function () {
      video.currentTime = parseFloat(b.dataset.t);
      video.play();
      video.scrollIntoView({ behavior: 'smooth', block: 'center' });
    });
  });
})();
