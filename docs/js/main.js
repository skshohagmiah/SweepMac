// ============================================
// SweepMac Landing Page — Interactions
// ============================================

document.addEventListener('DOMContentLoaded', () => {
    initNavScroll();
    initScrollAnimations();
    initSmoothScroll();
});

// Sticky nav background on scroll
function initNavScroll() {
    const nav = document.getElementById('nav');
    if (!nav) return;

    const onScroll = () => {
        if (window.scrollY > 20) {
            nav.classList.add('scrolled');
        } else {
            nav.classList.remove('scrolled');
        }
    };

    window.addEventListener('scroll', onScroll, { passive: true });
    onScroll();
}

// Fade-up animations on scroll
function initScrollAnimations() {
    // Add fade-up class to animatable elements
    const selectors = [
        '.feature-card',
        '.cat-item',
        '.compare-table-wrap',
        '.download-content',
        '.section-header',
        '.hero-mockup',
        '.social-proof'
    ];

    const elements = document.querySelectorAll(selectors.join(','));
    elements.forEach(el => el.classList.add('fade-up'));

    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                // Stagger children in grids
                const parent = entry.target.parentElement;
                if (parent) {
                    const siblings = Array.from(parent.children).filter(c => c.classList.contains('fade-up'));
                    const index = siblings.indexOf(entry.target);
                    entry.target.style.transitionDelay = `${index * 60}ms`;
                }
                entry.target.classList.add('visible');
                observer.unobserve(entry.target);
            }
        });
    }, {
        threshold: 0.1,
        rootMargin: '0px 0px -40px 0px'
    });

    elements.forEach(el => observer.observe(el));
}

// Smooth scroll for anchor links
function initSmoothScroll() {
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', (e) => {
            const targetId = anchor.getAttribute('href');
            if (targetId === '#') return;

            const target = document.querySelector(targetId);
            if (target) {
                e.preventDefault();
                const offset = 80; // nav height
                const top = target.getBoundingClientRect().top + window.scrollY - offset;
                window.scrollTo({ top, behavior: 'smooth' });
            }
        });
    });
}
