/* Kompete.ai — v2 JavaScript
   Sticky nav, mobile menu, scroll reveal, form handling */

(function () {
    'use strict';

    // --- Sticky navbar ---
    var navbar = document.getElementById('navbar');
    var scrollThreshold = 40;

    function onScroll() {
        if (window.scrollY > scrollThreshold) {
            navbar.classList.add('scrolled');
        } else {
            navbar.classList.remove('scrolled');
        }
    }

    window.addEventListener('scroll', onScroll, { passive: true });
    onScroll();

    // --- Mobile menu toggle ---
    var menuBtn = document.getElementById('mobile-menu-btn');
    var navLinks = document.getElementById('nav-links');

    if (menuBtn && navLinks) {
        menuBtn.addEventListener('click', function () {
            menuBtn.classList.toggle('active');
            navLinks.classList.toggle('open');
        });

        navLinks.querySelectorAll('a').forEach(function (link) {
            link.addEventListener('click', function () {
                menuBtn.classList.remove('active');
                navLinks.classList.remove('open');
            });
        });
    }

    // --- Scroll reveal ---
    var revealElements = document.querySelectorAll('[data-reveal]');

    if ('IntersectionObserver' in window) {
        var revealObserver = new IntersectionObserver(function (entries) {
            entries.forEach(function (entry) {
                if (entry.isIntersecting) {
                    entry.target.classList.add('revealed');
                    revealObserver.unobserve(entry.target);
                }
            });
        }, {
            threshold: 0.15,
            rootMargin: '0px 0px -40px 0px'
        });

        revealElements.forEach(function (el) {
            revealObserver.observe(el);
        });
    } else {
        revealElements.forEach(function (el) {
            el.classList.add('revealed');
        });
    }

    // --- Waitlist form ---
    var form = document.getElementById('waitlist-form');

    if (form) {
        form.addEventListener('submit', function (e) {
            e.preventDefault();

            var emailInput = form.querySelector('input[type="email"]');
            var email = emailInput ? emailInput.value.trim() : '';

            if (!email) return;

            var container = form.parentElement;
            form.remove();

            var successDiv = document.createElement('div');
            successDiv.className = 'waitlist-success';
            successDiv.textContent = "You're on the list. We'll be in touch soon at " + email + ".";

            var micro = container.querySelector('.waitlist-micro');
            if (micro) {
                container.insertBefore(successDiv, micro);
                micro.remove();
            } else {
                container.appendChild(successDiv);
            }
        });
    }

    // --- Smooth scroll for anchor links ---
    document.querySelectorAll('a[href^="#"]').forEach(function (anchor) {
        anchor.addEventListener('click', function (e) {
            var targetId = this.getAttribute('href');
            if (targetId === '#') return;

            var target = document.querySelector(targetId);
            if (target) {
                e.preventDefault();
                var navHeight = navbar ? navbar.offsetHeight : 0;
                var targetPos = target.getBoundingClientRect().top + window.scrollY - navHeight;

                window.scrollTo({
                    top: targetPos,
                    behavior: 'smooth'
                });
            }
        });
    });

})();
