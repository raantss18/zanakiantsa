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

// Le guide vidéo en tête de page : il tourne sans le son ; le bouton violet l'active ou le coupe. Les chapitres le placent
// sur une étape. Si l'appareil demande moins d'animations, il ne démarre pas seul.
(function () {
  var video = document.querySelector('#guide video');
  if (!video) return;
  var son = document.querySelector('#guide .son');
  var texte = son.querySelector('span');
  function montre() {
    son.setAttribute('aria-pressed', String(!video.muted));
    texte.textContent = video.muted ? 'Activer le son' : 'Couper le son';
  }
  if (window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    video.removeAttribute('autoplay');
    video.pause();
  }
  son.addEventListener('click', function () {
    video.muted = !video.muted;
    if (!video.muted) video.play();
    montre();
  });
  video.addEventListener('volumechange', montre);
  document.querySelectorAll('.chapitres button').forEach(function (b) {
    b.addEventListener('click', function () {
      video.currentTime = parseFloat(b.dataset.t);
      video.play();
    });
  });
  montre();
})();
