/**
 * Sobani Docs — Common JavaScript
 * Shared across all pages: theme toggle, i18n, mobile menu, copy, scroll animations.
 *
 * Usage:
 *   <script src="js/common.js"></script>
 *   <script>
 *     var translations = { ja: {...}, en: {...} };
 *   </script>
 *   <script>SobaniDocs.init(translations);</script>
 */
var SobaniDocs = (function() {
  'use strict';

  // ---- Mobile Menu ----
  function initMobileMenu() {
    var menuBtn = document.getElementById('mobile-menu-btn');
    var mobileMenu = document.getElementById('mobile-menu');
    var iconOpen = document.getElementById('menu-icon-open');
    var iconClose = document.getElementById('menu-icon-close');

    if (!menuBtn || !mobileMenu) return;

    menuBtn.addEventListener('click', function() {
      var isOpen = !mobileMenu.classList.contains('hidden');
      mobileMenu.classList.toggle('hidden');
      iconOpen.classList.toggle('hidden');
      iconClose.classList.toggle('hidden');
      menuBtn.setAttribute('aria-expanded', String(!isOpen));
    });

    var mobileLinks = mobileMenu.querySelectorAll('a');
    for (var i = 0; i < mobileLinks.length; i++) {
      mobileLinks[i].addEventListener('click', function() {
        mobileMenu.classList.add('hidden');
        iconOpen.classList.remove('hidden');
        iconClose.classList.add('hidden');
        menuBtn.setAttribute('aria-expanded', 'false');
      });
    }
  }

  // ---- Theme Toggle ----
  function getEffectiveTheme() {
    var theme = localStorage.getItem('theme');
    if (!theme || theme === 'system') return 'system';
    return theme;
  }

  function applyTheme(theme) {
    if (theme === 'dark') {
      document.documentElement.classList.add('dark');
    } else if (theme === 'light') {
      document.documentElement.classList.remove('dark');
    } else {
      if (window.matchMedia('(prefers-color-scheme: dark)').matches) {
        document.documentElement.classList.add('dark');
      } else {
        document.documentElement.classList.remove('dark');
      }
    }
    updateThemeIcons(theme);
  }

  function updateThemeIcons(theme) {
    var icons = document.querySelectorAll('.theme-icon-light, .theme-icon-dark, .theme-icon-system');
    for (var i = 0; i < icons.length; i++) {
      icons[i].classList.add('hidden');
    }
    var showClass = 'theme-icon-' + theme;
    var targets = document.querySelectorAll('.' + showClass);
    for (var i = 0; i < targets.length; i++) {
      targets[i].classList.remove('hidden');
    }
  }

  function cycleTheme() {
    var current = getEffectiveTheme();
    var next;
    if (current === 'light') next = 'dark';
    else if (current === 'dark') next = 'system';
    else next = 'light';
    localStorage.setItem('theme', next);
    applyTheme(next);
  }

  function initThemeToggle() {
    applyTheme(getEffectiveTheme());

    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', function() {
      if (getEffectiveTheme() === 'system') {
        applyTheme('system');
      }
    });

    var btn = document.getElementById('theme-toggle');
    var btnMobile = document.getElementById('theme-toggle-mobile');
    if (btn) btn.addEventListener('click', cycleTheme);
    if (btnMobile) btnMobile.addEventListener('click', cycleTheme);
  }

  // ---- Copy Command ----
  function copyCommand(text, button) {
    navigator.clipboard.writeText(text).then(function() {
      var copyIcon = button.querySelector('.copy-icon');
      var checkIcon = button.querySelector('.check-icon');
      if (copyIcon) copyIcon.classList.add('hidden');
      if (checkIcon) checkIcon.classList.remove('hidden');
      setTimeout(function() {
        if (copyIcon) copyIcon.classList.remove('hidden');
        if (checkIcon) checkIcon.classList.add('hidden');
      }, 2000);
    });
  }

  // ---- i18n Engine ----
  var _translations = null;

  function getLanguage() {
    var params = new URLSearchParams(window.location.search);
    var urlLang = params.get('lang');
    if (urlLang === 'ja' || urlLang === 'en') {
      localStorage.setItem('lang', urlLang);
      return urlLang;
    }
    var saved = localStorage.getItem('lang');
    if (saved) return saved;
    var browserLang = (navigator.language || 'ja').toLowerCase();
    return browserLang.startsWith('ja') ? 'ja' : 'en';
  }

  function getNestedValue(obj, path) {
    var parts = path.split('.');
    var current = obj;
    for (var i = 0; i < parts.length; i++) {
      if (current === undefined || current === null) return undefined;
      current = current[parts[i]];
    }
    return current;
  }

  function applyLanguage(lang) {
    document.documentElement.lang = lang;
    if (!_translations) return;
    var t = _translations[lang];
    if (!t) return;

    // Update data-i18n elements (textContent)
    var elems = document.querySelectorAll('[data-i18n]');
    for (var i = 0; i < elems.length; i++) {
      var key = elems[i].getAttribute('data-i18n');
      var val = getNestedValue(t, key);
      if (val !== undefined) {
        elems[i].textContent = val;
        if (val === '') {
          elems[i].setAttribute('hidden', '');
        } else {
          elems[i].removeAttribute('hidden');
        }
      }
    }

    // Update data-i18n-html elements
    // Security: all content comes from hardcoded translation objects, not user input
    var htmlElems = document.querySelectorAll('[data-i18n-html]');
    for (var i = 0; i < htmlElems.length; i++) {
      var key = htmlElems[i].getAttribute('data-i18n-html');
      var val = getNestedValue(t, key);
      if (val !== undefined) {
        // Using DOM manipulation for safety: parse and replace content
        var template = document.createElement('template');
        template.innerHTML = val;  // eslint-disable-line -- trusted hardcoded translations only
        htmlElems[i].replaceChildren(template.content);
      }
    }

    // Update data-i18n-attr elements (attributes)
    var attrElems = document.querySelectorAll('[data-i18n-attr]');
    for (var i = 0; i < attrElems.length; i++) {
      var pairs = attrElems[i].getAttribute('data-i18n-attr').split(',');
      for (var j = 0; j < pairs.length; j++) {
        var parts = pairs[j].split(':');
        var attrName = parts[0].trim();
        var key = parts[1].trim();
        var val = getNestedValue(t, key);
        if (val !== undefined) attrElems[i].setAttribute(attrName, val);
      }
    }
  }

  function toggleLanguage() {
    var next = getLanguage() === 'ja' ? 'en' : 'ja';
    localStorage.setItem('lang', next);
    applyLanguage(next);
  }

  function initLanguage() {
    applyLanguage(getLanguage());

    var btn = document.getElementById('lang-toggle');
    var btnMobile = document.getElementById('lang-toggle-mobile');
    if (btn) btn.addEventListener('click', toggleLanguage);
    if (btnMobile) btnMobile.addEventListener('click', toggleLanguage);
  }

  // ---- Scroll Animations ----
  function initScrollAnimations() {
    var animElements = document.querySelectorAll('[data-animate]');
    if (!animElements.length) return;

    // Skip if user prefers reduced motion
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

    var observer = new IntersectionObserver(function(entries) {
      for (var i = 0; i < entries.length; i++) {
        if (entries[i].isIntersecting) {
          var el = entries[i].target;
          var delay = parseInt(el.getAttribute('data-animate-delay') || '0', 10);
          setTimeout(function(element) {
            element.classList.add('animate-fade-in-up');
          }, delay, el);
          observer.unobserve(el);
        }
      }
    }, {
      threshold: 0.1,
      rootMargin: '-50px'
    });

    for (var i = 0; i < animElements.length; i++) {
      observer.observe(animElements[i]);
    }
  }

  // ---- Public API ----
  function init(translations) {
    _translations = translations;
    initMobileMenu();
    initThemeToggle();
    initLanguage();
    initScrollAnimations();
  }

  return {
    init: init,
    copyCommand: copyCommand
  };
})();
